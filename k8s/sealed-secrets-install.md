# Bitnami Sealed Secrets — Setup Guide
# Reference: https://github.com/bitnami/sealed-secrets

## 1. Install the Sealed Secrets Controller (on CD EC2 — K8s cluster)

### Option A: kubectl Direct Apply (Fastest & Recommended — No Helm Needed)

```bash
kubectl apply -f https://github.com/bitnami/sealed-secrets/releases/download/v0.41.2/controller.yaml
```

### Option B: Helm

> **Note:** Bitnami recently migrated the repository. Use `bitnami.github.io` (not the deprecated `bitnami-labs`).

```bash
# If you previously added the old repo, remove it first:
helm repo remove sealed-secrets 2>/dev/null || true

# Add the new repository URL:
helm repo add sealed-secrets https://bitnami.github.io/sealed-secrets
helm repo update

# Install the controller into kube-system:
helm install sealed-secrets-controller sealed-secrets/sealed-secrets \
  --namespace kube-system
```

### Verify Controller is Running

```bash
kubectl get pods -n kube-system -l name=sealed-secrets-controller
# or
kubectl get pods -n kube-system | grep sealed-secrets
```

---

## 2. Install kubeseal CLI (on your local machine / CI EC2)

### Linux (x86_64)

```bash
KUBESEAL_VERSION="0.41.2"
curl -OL "https://github.com/bitnami/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
tar -xvzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
kubeseal --version
```

### macOS

```bash
brew install kubeseal
```

---

## 3. Seal Your Secrets

### One-command method (use the helper script)

```bash
cd k8s
bash seal-secrets.sh ../../Coding-Plateform/Backend/.env
```

### Manual method

```bash
# Step 1: Create a raw K8s Secret (dry-run, never apply this)
kubectl create secret generic backend-secrets \
  --namespace=nextgen \
  --from-env-file=../../Coding-Plateform/Backend/.env \
  --dry-run=client -o yaml > /tmp/raw-secret.yml

# Step 2: Encrypt with kubeseal
kubeseal -f /tmp/raw-secret.yml -o yaml > k8s/sealed-secrets.yml

# Step 3: Delete the raw file
rm /tmp/raw-secret.yml

# Step 4: Commit and push sealed-secrets.yml
git add k8s/sealed-secrets.yml
git commit -m "chore: update sealed secrets"
git push
```

The controller will automatically decrypt the SealedSecret into a native K8s Secret.

---

## 4. Key Rotation

Sealed Secrets controller rotates its encryption key every 30 days by default.
Old sealed secrets remain valid. To re-encrypt with the latest key:

```bash
kubeseal --re-encrypt -f k8s/sealed-secrets.yml -o yaml > /tmp/resealed.yml
mv /tmp/resealed.yml k8s/sealed-secrets.yml
```

---

## 5. Scopes

| Scope | Description |
|-------|-------------|
| `strict` (default) | Sealed secret is bound to its exact name + namespace |
| `namespace-wide` | Can be renamed within the same namespace |
| `cluster-wide` | Can be used in any namespace with any name |

To use a different scope:

```bash
kubeseal --scope namespace-wide -f secret.yaml -o yaml > sealed-secret.yaml
```
