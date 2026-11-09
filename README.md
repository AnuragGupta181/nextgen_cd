# NextGen CD — GitOps Continuous Delivery

This repository contains the Kubernetes manifests and GitOps deployment configurations for the **NextGen Coding Platform**. Argo CD watches this repository to automatically synchronize and deploy desired state to the Kubernetes cluster using **blue-green deployments** powered by [Argo Rollouts](https://argoproj.github.io/rollouts/).

---

## CI/CD Architecture

![CI/CD Architecture](./architecture.png)

### End-to-End Workflow

1. **Source Code & Webhook**:
   - Developers push to [`Coding-Plateform`](https://github.com/AnuragGupta181/Coding-Plateform).
   - GitHub webhook triggers Jenkins.

2. **Continuous Integration (Jenkins — EC2 #1)**:
   - **Checkout** → **Build & Test** (backend + frontend)
   - **SonarQube Quality Gate** — blocks pipeline if code quality fails
   - **Docker Build & Push** — images tagged with `${BUILD_NUMBER}` + `latest`
   - **Trivy Vulnerability Scan** — blocks on HIGH/CRITICAL CVEs
   - **Email Notification** — success/failure reports

3. **Manifest Update (GitOps Sync)**:
   - Jenkins updates image tags in `k8s/deploy.yml` and `k8s/frontend-deploy.yml` → commits → pushes to this repo.

4. **Continuous Deployment (Argo CD + Argo Rollouts — EC2 #2)**:
   - Argo CD detects the commit and syncs the Rollout resources.
   - **Blue-Green Strategy**: New version deploys behind a **preview service** → you test it → **manually promote** the backend → old version stays alive for 60s (instant rollback window).
   - Frontend auto-promotes since it serves static assets.

5. **Secrets Management (Bitnami Sealed Secrets)**:
   - Secrets encrypted with `kubeseal` → stored as `SealedSecret` in Git.
   - Controller decrypts them inside the cluster. Raw secrets never touch Git.

---

## 🔵🟢 Blue-Green Deployment

Reference: [argoproj/argocd-example-apps/blue-green](https://github.com/argoproj/argocd-example-apps/tree/master/blue-green)

### How It Works

```
                    ┌──────────────────┐
   k8s.nextgen      │  nextgen-ingress │
   ─────────────────┤  (production)    │
                    └──────┬───────────┘
                           │
              ┌────────────┴────────────┐
              │                         │
       /api/* │                    /* │
              ▼                         ▼
     ┌─────────────┐          ┌──────────────┐
     │backend-active│          │frontend-active│
     │  (stable)    │          │   (stable)    │
     └─────────────┘          └──────────────┘

                    ┌──────────────────────┐
preview.k8s.nextgen │  nextgen-preview     │
   ─────────────────┤  ingress (testing)   │
                    └──────┬───────────────┘
                           │
              ┌────────────┴─────────────┐
              │                          │
       /api/* │                     /* │
              ▼                          ▼
     ┌──────────────┐         ┌───────────────┐
     │backend-preview│         │frontend-preview│
     │  (new version)│         │  (new version) │
     └──────────────┘         └───────────────┘
```

### Rollout Operations

```bash
# Check rollout status
kubectl argo rollouts get rollout backend -n nextgen
kubectl argo rollouts get rollout frontend -n nextgen

# Manually promote backend (after testing via preview.k8s.nextgen)
kubectl argo rollouts promote backend -n nextgen

# Abort a rollout (rollback to blue)
kubectl argo rollouts abort backend -n nextgen

# Watch rollout in real-time
kubectl argo rollouts get rollout backend -n nextgen --watch
```

### Strategy Details

| Setting | Backend | Frontend |
|---------|---------|----------|
| `autoPromotionEnabled` | `false` (manual) | `true` (auto) |
| `previewReplicaCount` | `1` | full replica count |
| `scaleDownDelaySeconds` | `60s` | `30s` |
| Active Service | `backend-active` | `frontend-active` |
| Preview Service | `backend-preview` | `frontend-preview` |

---

## 📁 Repository Structure

```
.
├── architecture.png              # CI/CD architecture diagram
├── .gitignore                    # Ignores raw secrets, terraform state, IDE files
├── README.md                     # This file
├── terraform/                    # Infrastructure as Code (future)
└── k8s/
    ├── namespace.yml             # Creates the 'nextgen' namespace
    ├── configmap.yml             # App configuration (NODE_ENV, PORT, CORS)
    │
    │── deploy.yml                # Backend Argo Rollout (blue-green)
    │── frontend-deploy.yml       # Frontend Argo Rollout (blue-green)
    │── service.yml               # Backend active + preview services
    │── frontend-service.yml      # Frontend active + preview services
    │── ingress.yml               # Production + preview ingress routing
    │
    │── sealed-secrets.yml        # 🔒 Encrypted secrets (safe to commit)
    │── sealed-secrets-install.md # Sealed Secrets controller setup guide
    │── seal-secrets.sh           # One-command: .env → sealed secret
    │── secrets.example.yml       # Template showing expected secret keys
    └── encode-secrets.sh         # Legacy: .env → base64 (manual approach)
```

---

## 🚀 Deployment Instructions

### Prerequisites (EC2 #2 — K8s Cluster)

```bash
# 1. Install Argo Rollouts CRD + controller
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# 2. Install kubectl argo rollouts plugin
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts

# 3. Install Sealed Secrets controller
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update
helm install sealed-secrets-controller sealed-secrets/sealed-secrets --namespace kube-system

# 4. Install kubeseal CLI
KUBESEAL_VERSION="0.41.2"
curl -OL "https://github.com/bitnami/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
tar -xvzf kubeseal-*.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

### Step 1: Seal Your Secrets

```bash
cd k8s
bash seal-secrets.sh ../../Coding-Plateform/Backend/.env
git add sealed-secrets.yml && git commit -m "chore: seal secrets" && git push
```

### Step 2: Manual Apply (or let ArgoCD handle it)

```bash
kubectl apply -f k8s/namespace.yml
kubectl apply -f k8s/configmap.yml
kubectl apply -f k8s/sealed-secrets.yml
kubectl apply -f k8s/deploy.yml
kubectl apply -f k8s/frontend-deploy.yml
kubectl apply -f k8s/service.yml
kubectl apply -f k8s/frontend-service.yml
kubectl apply -f k8s/ingress.yml
```

### Step 3: Verify

```bash
kubectl get all -n nextgen
kubectl argo rollouts get rollout backend -n nextgen
kubectl argo rollouts get rollout frontend -n nextgen
```

---

## 🤖 Argo CD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nextgen-platform
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/AnuragGupta181/nextgen_cd.git'
    targetRevision: HEAD
    path: k8s
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: nextgen
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

## Infrastructure Layout

| **Component** | **Location / Host** | **Purpose** |
|---|---|---|
| **Jenkins CI** | EC2 #1 (`15.207.14.85:8080`) | Pulls code, runs tests, SonarQube, Trivy, Docker build & push |
| **SonarQube** | EC2 #1 (`15.207.14.85:9000`) | Static analysis and Quality Gate enforcement |
| **Argo CD** | EC2 #2 (`https://3.110.207.83:8080/applications`) | GitOps Continuous Delivery & Kubernetes cluster management |
| **Argo Rollouts** | In-cluster (EC2 #2) | Manages Blue-Green zero-downtime rollouts & traffic shifting |
| **Sealed Secrets** | In-cluster (EC2 #2, `kube-system`) | Decrypts `SealedSecret` resources into native K8s Secrets |
| **Docker Hub** | `anurag181/*` | Container registry for backend & frontend images |
| **GitHub** | `AnuragGupta181/Coding-Plateform` | Application source code & Jenkins Shared Library |
| **GitHub** | `AnuragGupta181/nextgen_cd` | GitOps deployment manifests repository |
