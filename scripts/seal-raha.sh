#!/usr/bin/env bash
# seal-raha.sh
#
# Seals raha's app secret (Secret "web-secrets" in namespace raha, read by the
# web container and the Litestream init/sidecar containers) into
# secrets/raha-web.yaml.
#
# Keys you don't pass are kept: when the file already exists, new values are
# merged into it with `kubeseal --merge-into`, so adding e.g. the Anthropic
# key later doesn't require re-entering the Litestream keys.
#
# Values are read from the environment if set, otherwise prompted for with
# hidden input (never on the command line, never echoed). Leave a prompt
# empty to skip that key.
#
#   LITESTREAM_ACCESS_KEY_ID / LITESTREAM_SECRET_ACCESS_KEY   (Hetzner Object Storage)
#   ANTHROPIC_API_KEY                                          (receipt scan, /assistant)
#   ENABLE_BANKING_APP_ID / ENABLE_BANKING_PRIVATE_KEY         (bank sync; PEM, \n-escaped ok)
#   VAPID_PUBLIC_KEY / VAPID_PRIVATE_KEY / VAPID_SUBJECT       (web push)
#   CRON_SECRET                                                (/api/cron)
#   SMTP_HOST SMTP_PORT SMTP_SECURE SMTP_USER SMTP_PASS SMTP_FROM
#
# Usage:
#   ./scripts/seal-raha.sh                 # prompt for the Litestream keys only
#   ./scripts/seal-raha.sh --all           # prompt for every key above
#   ./scripts/seal-raha.sh --commit        # also git add + commit
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT="$REPO_ROOT/secrets/raha-web.yaml"
NAMESPACE="raha"
NAME="web-secrets"
KS_FLAGS=(--controller-name sealed-secrets --controller-namespace sealed-secrets --format yaml)

ALL=0; COMMIT=0
for a in "$@"; do
  case "$a" in
    --all) ALL=1 ;;
    --commit) COMMIT=1 ;;
    -h|--help) sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
    *) echo "✗ unknown flag: $a" >&2; exit 2 ;;
  esac
done

for dep in kubeseal kubectl; do
  command -v "$dep" >/dev/null 2>&1 || { echo "✗ missing $dep (brew install kubeseal / kubectl)" >&2; exit 2; }
done
kubectl -n sealed-secrets get deploy sealed-secrets >/dev/null 2>&1 || { echo "✗ can't reach the sealed-secrets controller (check ~/.kube/config)" >&2; exit 2; }

KEYS=(LITESTREAM_ACCESS_KEY_ID LITESTREAM_SECRET_ACCESS_KEY)
if [ "$ALL" = "1" ]; then
  KEYS+=(ANTHROPIC_API_KEY ENABLE_BANKING_APP_ID ENABLE_BANKING_PRIVATE_KEY VAPID_PUBLIC_KEY VAPID_PRIVATE_KEY VAPID_SUBJECT CRON_SECRET SMTP_HOST SMTP_PORT SMTP_SECURE SMTP_USER SMTP_PASS SMTP_FROM)
fi

WORK="$(mktemp -d -t seal-raha.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
ARGS=()
for k in "${KEYS[@]}"; do
  v="${!k:-}"
  if [ -z "$v" ]; then
    printf '%s (empty = skip): ' "$k" >&2
    IFS= read -rs v; echo >&2
  fi
  [ -n "$v" ] || continue
  printf '%s' "$v" > "$WORK/$k"
  ARGS+=(--from-file="$k=$WORK/$k")
done
[ "${#ARGS[@]}" -gt 0 ] || { echo "Nothing to seal."; exit 0; }

kubectl create secret generic "$NAME" --namespace "$NAMESPACE" "${ARGS[@]}" --dry-run=client -o yaml > "$WORK/secret.yaml"

if [ -f "$OUT" ]; then
  kubeseal "${KS_FLAGS[@]}" --merge-into "$OUT" < "$WORK/secret.yaml"
  echo "✓ merged ${#ARGS[@]} key(s) into $OUT"
else
  kubeseal "${KS_FLAGS[@]}" < "$WORK/secret.yaml" > "$OUT"
  echo "✓ sealed ${#ARGS[@]} key(s) into $OUT"
fi
echo "  keys now in the file: $(grep -A40 'encryptedData:' "$OUT" | grep -oE '^    [A-Z_]+' | tr -d ' ' | paste -sd, -)"

if [ "$COMMIT" = "1" ]; then
  cd "$REPO_ROOT"
  git add secrets/raha-web.yaml
  git diff --cached --quiet || git commit -m "chore(secrets): seal raha web-secrets"
  echo "▸ Committed. Push, then Flux applies it within ~5 min."
fi
