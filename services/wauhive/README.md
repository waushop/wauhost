# Wauhive

Personal AI agent platform — Go backend, Next.js frontend, SQLite, Caddy → Traefik.
Deployed at `hive.waushop.ee` (or whatever you set `ingress.host` to in values).

## One-time setup

### 1. Build + push images

`wauhive/.github/workflows/release.yml` (in the app repo) builds and pushes:

- `ghcr.io/waushop/wauhive-backend:latest`
- `ghcr.io/waushop/wauhive-frontend:latest`

The frontend image must be built with `--build-arg NEXT_PUBLIC_API_BASE=`
(empty) so the FE talks same-origin via the ingress.

### 2. ghcr-pull-secret in the wauhive namespace

Same trick as agrofort — copy the docker-config from any existing service:

```bash
kubectl -n agrofort get secret ghcr-pull-secret -o yaml \
  | sed 's/namespace: agrofort/namespace: wauhive/' \
  | kubectl create -f - --dry-run=client -o yaml \
  | kubeseal --controller-name sealed-secrets --controller-namespace sealed-secrets \
      --format yaml \
  >> ../../secrets/wauhive.yaml   # appended; see step 3 for the rest
```

### 3. App secrets (password + Anthropic key)

Wauhive's secret bundle is mounted as `wauhive-secrets` (the chart's
`{{ fullname }}-secrets`) and surfaced to the backend via `envFrom`.

```bash
# Adjust values on the right of the = signs.
kubectl create secret generic wauhive-secrets \
  --namespace wauhive \
  --from-literal=WAUHIVE_PASSWORD="hunter2-strong-pwd" \
  --from-literal=ANTHROPIC_API_KEY="sk-ant-..." \
  --dry-run=client -o yaml \
  | kubeseal --controller-name sealed-secrets --controller-namespace sealed-secrets \
      --format yaml \
  >> ../../secrets/wauhive.yaml
```

Both secrets share `secrets/wauhive.yaml` — append the second SealedSecret
after the first (separator `---`). Commit when both blocks are present.

### 4. DNS

Point `hive.waushop.ee` (A record) at the cluster's external IP. Cert-manager
+ Traefik handle TLS automatically once the ingress reconciles.

## What the chart does

- **One backend pod, one frontend pod.** SQLite + WAL doesn't tolerate two
  writers, so the backend is hard-coded to `replicas: 1` with `Recreate`
  strategy. `nodeSelector`/`affinity` aren't set — the PVC is RWO and pins
  it to one node.
- **5Gi PVC** at `/data` on the backend pod holds the SQLite DB, the
  encryption secret, the persisted config, and the per-drone workspaces.
  Use `scripts/backup.sh` (in the app repo) for snapshots.
- **Ingress splits paths**: API surface (`/auth`, `/tasks`, `/drones`,
  `/workspace`, `/evals`, `/runs`, `/schedules`, `/hive/stream`, `/info`,
  `/health`, `/readyz`, `/metrics`) → backend. Everything else → frontend.
  Add new prefixes to `ingress.apiPaths` in values when you add new API
  surface.
- **Probes**: liveness `/health` (cheap process-alive), readiness `/readyz`
  (DB ping). New pod waits for AutoMigrate + the startup sweep before
  taking traffic.
- **Cookie Secure**: `WAUHIVE_HTTPS=true` is set in env so the session
  cookie carries the Secure flag (Traefik terminates TLS upstream).

## Updating

Push a new image to ghcr; with `imagePullPolicy: Always` and the
deployment's `rollme` annotation, Flux reconciliation will pick it up.
For a forced rollout: bump the image tag in `values.yaml` and commit.
