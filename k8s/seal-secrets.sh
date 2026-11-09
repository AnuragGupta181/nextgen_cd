#!/usr/bin/env bash
# Helper script to generate sealed secrets from a .env file
# Reference: https://github.com/bitnami/sealed-secrets
#
# Usage: bash seal-secrets.sh [path-to-.env]
#
# Prerequisites:
#   - kubeseal CLI installed (https://github.com/bitnami/sealed-secrets/releases)
#   - Sealed Secrets controller running in the K8s cluster
#   - kubectl configured to talk to the cluster

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${1:-}"

# Auto-detect .env file location
if [ -z "$ENV_FILE" ]; then
  for candidate in \
    "$SCRIPT_DIR/../../Coding-Plateform/Backend/.env" \
    "$SCRIPT_DIR/../../Backend/.env" \
    "./Backend/.env" \
    "./.env"; do
    if [ -f "$candidate" ]; then
      ENV_FILE="$candidate"
      break
    fi
  done
fi

if [ -z "$ENV_FILE" ] || [ ! -f "$ENV_FILE" ]; then
  echo "❌ .env file not found"
  echo "Usage: bash seal-secrets.sh [path-to-.env]"
  exit 1
fi

echo "📂 Using .env file: $ENV_FILE"

# Check prerequisites
if ! command -v kubeseal &> /dev/null; then
  echo "❌ kubeseal is not installed."
  echo ""
  echo "Install it:"
  echo '  KUBESEAL_VERSION="0.41.2"'
  echo '  curl -OL "https://github.com/bitnami/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"'
  echo '  tar -xvzf kubeseal-*.tar.gz kubeseal'
  echo '  sudo install -m 755 kubeseal /usr/local/bin/kubeseal'
  exit 1
fi

if ! command -v kubectl &> /dev/null; then
  echo "❌ kubectl is not installed."
  exit 1
fi

TMP_SECRET=$(mktemp /tmp/raw-secret-XXXXXX.yml)
trap "rm -f $TMP_SECRET" EXIT

echo "🔐 Creating raw K8s Secret from .env (dry-run) …"
kubectl create secret generic backend-secrets \
  --namespace=nextgen \
  --from-env-file="$ENV_FILE" \
  --dry-run=client -o yaml > "$TMP_SECRET"

echo "🔒 Sealing with kubeseal (using cluster's public key) …"
kubeseal \
  -f "$TMP_SECRET" \
  -o yaml \
  > "$SCRIPT_DIR/sealed-secrets.yml"

echo ""
echo "✅ Sealed secret written to: $SCRIPT_DIR/sealed-secrets.yml"
echo "   You can safely commit and push this file."
echo ""
echo "🧹 Raw secret auto-deleted from temp."
