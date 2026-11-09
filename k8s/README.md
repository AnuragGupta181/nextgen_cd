# Kubernetes Manifests & GitOps Deployment — NextGen Platform

This directory contains the production-ready Kubernetes manifests for the **NextGen Coding Platform**, managed declaratively via **Argo CD** at [`https://3.110.207.83:8080/applications`](https://3.110.207.83:8080/applications) with **Blue-Green Deployments** powered by **Argo Rollouts** and encrypted secrets via **Bitnami Sealed Secrets**.

---

## Manifests Reference

| Manifest | Kind | Description |
|---|---|---|
| [`namespace.yml`](./namespace.yml) | `Namespace` | Creates the isolated `nextgen` namespace |
| [`configmap.yml`](./configmap.yml) | `ConfigMap` | Non-sensitive runtime variables (`PORT`, `NODE_ENV`, `CORS_ORIGIN`, `MONGO_POOL_SIZE`) |
| [`sealed-secrets.yml`](./sealed-secrets.yml) | `SealedSecret` | Encrypted backend credentials (decrypted by controller inside cluster) |
| [`deploy.yml`](./deploy.yml) | `Rollout` | Backend Blue-Green deployment with `backend-active` and `backend-preview` |
| [`frontend-deploy.yml`](./frontend-deploy.yml) | `Rollout` | Frontend Blue-Green deployment with Nginx static file serving |
| [`service.yml`](./service.yml) | `Service` | Dual services: `backend-active` (live prod) and `backend-preview` (preview) |
| [`frontend-service.yml`](./frontend-service.yml) | `Service` | Dual services: `frontend-active` (live prod) and `frontend-preview` (preview) |
| [`ingress.yml`](./ingress.yml) | `Ingress` | NGINX routing: `/api` → Backend, `/socket.io` → WebSockets/WebRTC, `/` → Frontend |
| [`argocd-application.yml`](./argocd-application.yml) | `Application` | Argo CD Application definition for GitOps auto-sync |
| [`seal-secrets.sh`](./seal-secrets.sh) | Script | Helper to encrypt `.env` into `sealed-secrets.yml` using `kubeseal` |

---

## Connecting to Argo CD (`https://3.110.207.83:8080/applications`)

You can create the Argo CD application using either the Web UI or `kubectl`.

### Option A: Using the Argo CD Web UI (Recommended)

1. Open [`https://3.110.207.83:8080/applications`](https://3.110.207.83:8080/applications) in your browser.
2. Click **`+ NEW APP`** in the top-left corner.
3. Fill in the form values:

#### General
* **Application Name**: `nextgen-platform`
* **Project Name**: `default`
* **Sync Policy**: `Automatic`
  * Check: **Prune Resources** (deletes removed resources)
  * Check: **Self Heal** (auto-corrects drift from Git)
* **Sync Options**:
  * Check: **Create Namespace**

#### Source
* **Repository URL**: `https://github.com/AnuragGupta181/nextgen_cd.git`
* **Revision**: `HEAD` (or `main`)
* **Path**: `k8s`

#### Destination
* **Cluster URL**: `https://kubernetes.default.svc`
* **Namespace**: `nextgen`

4. Click **CREATE** at the top.
5. Argo CD will automatically pull this repository, create the `nextgen` namespace, and deploy the entire blue-green stack!

---

### Option B: Using `kubectl` via CLI (on EC2 `3.110.207.83`)

```bash
kubectl apply -f https://raw.githubusercontent.com/AnuragGupta181/nextgen_cd/main/k8s/argocd-application.yml
```

---

## 🔵🟢 Blue-Green Deployment Strategy (Argo Rollouts)

Reference: [argoproj/argocd-example-apps/blue-green](https://github.com/argoproj/argocd-example-apps/tree/master/blue-green)

### Architecture Routing

```
Production Ingress (k8s.nextgen):
  ├── /api       ──►  backend-active:5000   (Current stable release)
  ├── /socket.io ──►  backend-active:5000   (Live WebRTC & Proctoring)
  └── /          ──►  frontend-active:80    (Production UI)

Preview Ingress (preview.k8s.nextgen):
  ├── /api       ──►  backend-preview:5000  (New version pre-promotion)
  ├── /socket.io ──►  backend-preview:5000  (Preview testing)
  └── /          ──►  frontend-preview:80   (Preview UI)
```

### Blue-Green Workflow Operations

When Jenkins pushes a new image tag to `nextgen_cd`:
1. Argo CD syncs `deploy.yml`.
2. Argo Rollouts creates a new replica set behind `backend-preview:5000`.
3. The new version is available for verification at `preview.k8s.nextgen`.
4. Production traffic on `backend-active:5000` remains untouched until you promote.

```bash
# Watch rollout progression in real-time
kubectl argo rollouts get rollout backend -n nextgen --watch

# Promote the preview version to become the active production release
kubectl argo rollouts promote backend -n nextgen

# If issues are detected during preview, instantly abort (rollback)
kubectl argo rollouts abort backend -n nextgen

# Undo a deployment to the previous revision
kubectl argo rollouts undo backend -n nextgen
```

---

## Bitnami Sealed Secrets Management

Raw unencrypted secrets are **never** committed to Git (`k8s/secrets.yml` is gitignored). Only encrypted `SealedSecret` resources are tracked.

### Sealing Secrets (Run from repo root of `nextgen_cd`)

```bash
cd ~/Anurag/Coding/Projects/ccc/nextgen_cd

# Run encryption script (fetches public key from cluster controller in kube-system)
bash k8s/seal-secrets.sh ../Coding-Plateform/Backend/.env

# Commit the encrypted secret
git add k8s/sealed-secrets.yml
git commit -m "chore(secrets): update cluster sealed secrets"
git push origin main
```

The Sealed Secrets controller inside the cluster decrypts `sealed-secrets.yml` on the fly and materializes a native `Secret` named `backend-secrets` in the `nextgen` namespace.

---

## Verification & Troubleshooting

```bash
# Check all resources in the nextgen namespace
kubectl get all -n nextgen

# Verify both active and preview services
kubectl get svc -n nextgen

# Check SealedSecret decryption status
kubectl get sealedsecret -n nextgen backend-secrets
kubectl get secret -n nextgen backend-secrets

# Check logs of backend active pods
kubectl logs -n nextgen -l app=coding-platform-backend,role=active --tail=50 -f

# Check Ingress endpoints
kubectl get ingress -n nextgen
```
