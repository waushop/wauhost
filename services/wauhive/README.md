# Wauhive

Personal AI agent platform — Go backend, Next.js frontend, SQLite, Caddy → Traefik.
Deployed at `hive.waushop.ee` (or whatever you set `ingress.host` to in values).

The SQLite DB lives on a PVC inside the backend pod and is **continuously
replicated to Hetzner Object Storage** by a Litestream sidecar. If the PVC
comes up empty (new node, lost volume), the init container restores from
the bucket before the backend starts.

## One-time setup

### 1. Build + push images

`wauhive/.github/workflows/release.yml` (in the app repo) builds and pushes:

- `ghcr.io/waushop/wauhive-backend:latest`
- `ghcr.io/waushop/wauhive-frontend:latest`

Frontend gets `NEXT_PUBLIC_API_BASE=""` so it talks same-origin via the
ingress.

### 2. Object-storage bucket

Create a bucket on Hetzner Object Storage (or Cloudflare R2 — adjust
`endpoint` in values.yaml). Grab the access key + secret. Bucket name goes
in `litestream.bucket`; default is `wauhive-litestream`.

### 3. Generate the master encryption key — locally — and seal it

Wauhive encrypts API keys at rest with a 32-byte master key
(`wauhive.secret`). Normally auto-generated, but in K8s we pin it via a
sealed secret so an empty-PVC restore doesn't mint a new key and brick the
encrypted-API-key columns.

```bash
head -c 32 /dev/urandom > /tmp/master.secret

kubectl create secret generic wauhive-master-secret \
  --namespace wauhive \
  --from-file=master.secret=/tmp/master.secret \
  --dry-run=client -o yaml \
  | kubeseal --controller-name sealed-secrets --controller-namespace sealed-secrets \
      --format yaml \
  > ../../secrets/wauhive.yaml

rm /tmp/master.secret
```

If you ever lose `secrets/wauhive.yaml` AND the live cluster's secret,
every encrypted API key in the DB is unrecoverable. Treat it like an SSH
key.

### 4. App secrets (password + Anthropic + Litestream credentials)

The backend reads these via `envFrom`. Litestream uses the AWS-style env
names so the S3-compatible Hetzner endpoint just works.

```bash
kubectl create secret generic wauhive-secrets \
  --namespace wauhive \
  --from-literal=WAUHIVE_PASSWORD='your-strong-password' \
  --from-literal=ANTHROPIC_API_KEY='sk-ant-...' \
  --from-literal=LITESTREAM_ACCESS_KEY_ID='HETZNER_ACCESS_KEY' \
  --from-literal=LITESTREAM_SECRET_ACCESS_KEY='HETZNER_SECRET_KEY' \
  --dry-run=client -o yaml \
  | kubeseal --controller-name sealed-secrets --controller-namespace sealed-secrets \
      --format yaml \
  >> ../../secrets/wauhive.yaml
```

### 5. ghcr-pull-secret (only if your packages are private)

```bash
kubectl -n agrofort get secret ghcr-pull-secret -o yaml \
  | sed 's/namespace: agrofort/namespace: wauhive/' \
  | kubectl create -f - --dry-run=client -o yaml \
  | kubeseal --controller-name sealed-secrets --controller-namespace sealed-secrets \
      --format yaml \
  >> ../../secrets/wauhive.yaml
```

### 6. DNS

A record for `hive.waushop.ee` → cluster external IP. cert-manager + Traefik
handle TLS automatically once the ingress reconciles.

## How replication actually works

```
┌─────────────────── backend pod ────────────────────┐
│                                                    │
│  init: litestream restore                          │
│   └─► /data/wauhive.db ◀── from Hetzner bucket    │
│       (only if PVC is empty AND a replica exists)  │
│                                                    │
│  main: backend (sqlite)                            │
│   └─► /data/wauhive.db   (read+write)             │
│                                                    │
│  sidecar: litestream replicate                     │
│   └─► watches /data/wauhive.db                     │
│       ──► Hetzner bucket every 10s                 │
│                                                    │
└────────────────────────────────────────────────────┘
```

The PVC is the canonical store. Litestream is a continuous off-site replica.
SQLite never sees the bucket — only the PVC.

Failure cases handled:

- Pod restart on the same node → PVC keeps the file, no restore.
- Pod scheduled to a new node, PVC follows → no restore.
- PVC lost or volume corrupted → init container restores from the bucket.
- Whole cluster gone → run `litestream restore` against the bucket from
  anywhere with the access key.

What is **not** replicated:

- `wauhive.config.json` (default model, telegram bot config, allow-chats)
  — small, recreate via Settings UI after a disaster.
- The per-drone workspace at `/data/workspace/<droneId>/` — drones can
  rebuild their state. Use `scripts/backup.sh` on a CronJob if you actively
  need workspace durability.

## Chart layout

- **Single backend pod, Recreate strategy, RWO PVC.** SQLite + WAL doesn't
  tolerate two writers.
- **5Gi PVC at `/data`** for the live SQLite file + workspace.
- **Litestream sidecar + init container** drive replication and restore.
- **K8s-mounted master secret at `/run/secrets/wauhive/master.secret`**
  — pinned via env `WAUHIVE_SECRET_PATH` so it doesn't drift across
  pod incarnations.
- **Path-routed ingress.** API prefixes (`/auth`, `/tasks`, `/drones`,
  `/workspace`, `/evals`, `/runs`, `/schedules`, `/hive`, `/info`,
  `/health`, `/readyz`, `/metrics`) → backend. Everything else → frontend.
- **Probes.** Liveness `/health`, readiness `/readyz` (DB ping). New pod
  waits for restore + AutoMigrate + the startup sweep before taking traffic.

## Updating

Push a new image to ghcr; `imagePullPolicy: Always` + the `rollme`
annotation make Flux reconciliation pick it up. For a forced rollout: bump
`image.tag` in values and commit.
