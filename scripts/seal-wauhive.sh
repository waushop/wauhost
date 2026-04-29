#!/usr/bin/env bash
# seal-wauhive.sh
#
# Seals every secret the wauhive HelmRelease expects into
# secrets/wauhive.yaml. Designed to be re-run for rotation; the master
# encryption key is preserved across runs (regenerating it would brick
# every encrypted API-key column in the live DB) unless --rotate-master
# is passed.
#
# Inputs come in via environment variables so plaintext never appears on
# the process command line:
#
#   WAUHIVE_PASSWORD             required
#   ANTHROPIC_API_KEY            optional (can be set via Settings UI later)
#   LITESTREAM_ACCESS_KEY_ID     required (Hetzner Object Storage)
#   LITESTREAM_SECRET_ACCESS_KEY required
#
# Optional flags:
#   --rotate-master       force regenerate the master encryption key
#                         (BRICKS every encrypted API key in the live DB —
#                          use only on a fresh install or after a planned
#                          re-encrypt sweep)
#   --skip-ghcr           don't seal a ghcr-pull-secret (use when the ghcr
#                         packages are public)
#   --commit              git add + commit secrets/wauhive.yaml after sealing
#   --push                also git push (implies --commit)
#
# Examples:
#   WAUHIVE_PASSWORD='hunter2-strong' \
#   LITESTREAM_ACCESS_KEY_ID='HZ-...' \
#   LITESTREAM_SECRET_ACCESS_KEY='hz-...' \
#   ./scripts/seal-wauhive.sh --commit --push
#
#   ./scripts/seal-wauhive.sh --rotate-master   # WIPES encrypted DB columns

set -euo pipefail

# ─── Locate ourselves ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SECRETS_FILE="$REPO_ROOT/secrets/wauhive.yaml"
NAMESPACE="wauhive"

# ─── Flags ────────────────────────────────────────────────────────────────
ROTATE_MASTER=0
SKIP_GHCR=0
DO_COMMIT=0
DO_PUSH=0

for arg in "$@"; do
  case "$arg" in
    --rotate-master) ROTATE_MASTER=1 ;;
    --skip-ghcr)     SKIP_GHCR=1 ;;
    --commit)        DO_COMMIT=1 ;;
    --push)          DO_COMMIT=1; DO_PUSH=1 ;;
    -h|--help)
      sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "✗ unknown flag: $arg" >&2; exit 2 ;;
  esac
done

# ─── Preflight ────────────────────────────────────────────────────────────
need() { command -v "$1" >/dev/null 2>&1 || { echo "✗ missing dependency: $1" >&2; exit 2; }; }
need kubeseal
need kubectl
need git

require_env() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "✗ env $name is required" >&2
    exit 2
  fi
}

require_env WAUHIVE_PASSWORD
require_env LITESTREAM_ACCESS_KEY_ID
require_env LITESTREAM_SECRET_ACCESS_KEY

ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"  # optional

# All temp work happens in this dir; wiped on exit even if we crash so
# plaintext never lingers.
WORK="$(mktemp -d -t seal-wauhive.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# Where the *new* sealed file gets built; rename over the old one at the end.
NEW="$WORK/wauhive.yaml"
: > "$NEW"

KS_FLAGS=(--controller-name sealed-secrets --controller-namespace sealed-secrets --format yaml)

# ─── Step 1: master encryption key ────────────────────────────────────────
# The chart mounts this as a file at /run/secrets/wauhive/master.secret.
# Wauhive uses it to encrypt API keys at rest. Rotating bricks the DB —
# only do it on --rotate-master.
existing_master() {
  [ -f "$SECRETS_FILE" ] && grep -q "name: wauhive-master-secret" "$SECRETS_FILE"
}

if [ "$ROTATE_MASTER" = "1" ]; then
  echo "▸ Generating NEW master encryption key (will brick existing encrypted DB columns)…"
  GENERATE_MASTER=1
elif existing_master; then
  echo "▸ Reusing existing wauhive-master-secret (pass --rotate-master to regenerate)"
  GENERATE_MASTER=0
else
  echo "▸ No existing master key — generating fresh"
  GENERATE_MASTER=1
fi

if [ "$GENERATE_MASTER" = "1" ]; then
  head -c 32 /dev/urandom > "$WORK/master.secret"

  kubectl create secret generic wauhive-master-secret \
    --namespace "$NAMESPACE" \
    --from-file=master.secret="$WORK/master.secret" \
    --dry-run=client -o yaml \
    | kubeseal "${KS_FLAGS[@]}" \
    >> "$NEW"

  shred -u "$WORK/master.secret" 2>/dev/null || rm -f "$WORK/master.secret"
  echo "  ✓ wauhive-master-secret sealed"
else
  # Carry the existing master sealed-secret block over verbatim. Find the
  # YAML document containing the master secret and copy it.
  awk '
    /^---/                        { if (inblk == "master") print blk; blk=""; inblk="" }
    /^---/                        { print; next }
    /name: wauhive-master-secret/ { inblk="master" }
    { blk = blk $0 ORS }
    END { if (inblk == "master") print blk }
  ' "$SECRETS_FILE" \
    | grep -v '^$' \
    >> "$NEW" || true

  # The awk is best-effort; fall back to a Python-style line range if missing.
  if ! grep -q "wauhive-master-secret" "$NEW"; then
    # Extract from "apiVersion" line preceding "name: wauhive-master-secret"
    # to the next "---" or EOF.
    sed -n '/apiVersion: bitnami.com\/v1alpha1/,/^---$/{p}' "$SECRETS_FILE" \
      | awk -v RS='---\n' '/wauhive-master-secret/' \
      >> "$NEW"
  fi

  if ! grep -q "wauhive-master-secret" "$NEW"; then
    echo "✗ couldn't carry master-secret across; rerun with --rotate-master if you want a fresh one" >&2
    exit 1
  fi
  echo "  ✓ wauhive-master-secret reused"
fi

# ─── Step 2: app secrets ──────────────────────────────────────────────────
echo "▸ Sealing wauhive-secrets (password, Anthropic key, Litestream creds)…"

echo "---" >> "$NEW"
{
  args=(
    --from-literal=WAUHIVE_PASSWORD="$WAUHIVE_PASSWORD"
    --from-literal=LITESTREAM_ACCESS_KEY_ID="$LITESTREAM_ACCESS_KEY_ID"
    --from-literal=LITESTREAM_SECRET_ACCESS_KEY="$LITESTREAM_SECRET_ACCESS_KEY"
  )
  if [ -n "$ANTHROPIC_API_KEY" ]; then
    args+=(--from-literal=ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY")
  fi

  kubectl create secret generic wauhive-secrets \
    --namespace "$NAMESPACE" \
    "${args[@]}" \
    --dry-run=client -o yaml \
    | kubeseal "${KS_FLAGS[@]}"
} >> "$NEW"
echo "  ✓ wauhive-secrets sealed"

# ─── Step 3: ghcr-pull-secret ─────────────────────────────────────────────
if [ "$SKIP_GHCR" = "1" ]; then
  echo "▸ Skipping ghcr-pull-secret (--skip-ghcr); ghcr packages must be public"
else
  echo "▸ Copying ghcr-pull-secret from agrofort namespace and re-sealing for wauhive…"

  echo "---" >> "$NEW"
  if ! kubectl -n agrofort get secret ghcr-pull-secret -o yaml >/dev/null 2>&1; then
    echo "✗ no ghcr-pull-secret in agrofort namespace; create one there first or pass --skip-ghcr" >&2
    exit 1
  fi

  kubectl -n agrofort get secret ghcr-pull-secret -o yaml \
    | sed "s/namespace: agrofort/namespace: $NAMESPACE/" \
    | kubectl create -f - --dry-run=client -o yaml \
    | kubeseal "${KS_FLAGS[@]}" \
    >> "$NEW"
  echo "  ✓ ghcr-pull-secret sealed"
fi

# ─── Step 4: install + summary ────────────────────────────────────────────
mkdir -p "$(dirname "$SECRETS_FILE")"
mv "$NEW" "$SECRETS_FILE"

echo
echo "Sealed secrets written to: $SECRETS_FILE"
echo "  blocks:           $(grep -c "kind: SealedSecret" "$SECRETS_FILE")"
echo "  bytes:            $(wc -c < "$SECRETS_FILE" | tr -d ' ')"
echo "  encrypted blobs:  $(grep -c "encryptedData:" "$SECRETS_FILE")"

# ─── Step 5: commit / push ────────────────────────────────────────────────
if [ "$DO_COMMIT" = "1" ]; then
  cd "$REPO_ROOT"
  git add secrets/wauhive.yaml
  if git diff --cached --quiet; then
    echo "▸ No changes to commit (sealed output identical to current)"
  else
    git commit -m "chore(secrets): seal wauhive secrets

Sealed via scripts/seal-wauhive.sh. master encryption key was $(
      [ "$GENERATE_MASTER" = "1" ] && echo regenerated || echo preserved
    ); app secrets re-sealed; ghcr pull secret $(
      [ "$SKIP_GHCR" = "1" ] && echo skipped || echo copied from agrofort
    )."
    echo "▸ Committed."
    if [ "$DO_PUSH" = "1" ]; then
      git push origin main
      echo "▸ Pushed."
    else
      echo "Run 'git push' to publish, then Flux reconciles within 5m."
    fi
  fi
fi

echo
echo "Done."
