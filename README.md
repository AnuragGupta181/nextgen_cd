# NextGen CD — GitOps Continuous Delivery

This repository contains the Kubernetes manifests and GitOps deployment configurations for the **NextGen Coding Platform**. Argo CD watches this repository to automatically synchronize and deploy desired state to the Kubernetes cluster.

---

## CI/CD Architecture Flow

![CI/CD Architecture](./architecture.png)

### End-to-End Workflow

1. **Source Code & Webhook**:
   - Developers push changes to the source repository ([`Coding-Plateform`](https://github.com/AnuragGupta181/Coding-Plateform)).
   - GitHub webhook triggers the Jenkins CI pipeline on push.

2. **Continuous Integration (Jenkins)**:
   - **Checkout**: Jenkins pulls the latest source code.
   - **Build & Test**: Installs dependencies and runs unit / integration tests.
   - **SonarQube Quality Gate**: Static code analysis ensures code quality, security vulnerabilities, and coverage metrics pass.
   - **Notification**: Automated status reports are sent via Email / Slack.

3. **Container Registry (Docker Hub)**:
   - Jenkins builds container images on the EC2 runner.
   - Tags images with build numbers (`anurag181/nextgen-backend:${BUILD_NUMBER}`) and `latest`.
   - Pushes images to Docker Hub.

4. **Manifest Updater (GitOps Sync)**:
   - Jenkins updates the deployment image tag in [`k8s/deploy.yml`](./k8s/deploy.yml) in this repository and commits the change.

5. **Continuous Deployment (Argo CD & Kubernetes)**:
   - Argo CD detects commits in this repository.
   - Automatically synchronizes the target state with the live Kubernetes cluster (`nextgen` namespace).
   - Zero-downtime rolling updates apply the new release.

---

## Repository Structure

```
.
├── architecture.png        # CI/CD architecture diagram
├── .gitignore              # Ignores sensitive secrets and environment files
├── README.md               # Repository documentation
└── k8s/
    ├── namespace.yml       # Creates the 'nextgen' namespace
    ├── configmap.yml       # App configuration (NODE_ENV, PORT, CORS)
    ├── secrets.example.yml # Template for base64-encoded secrets
    ├── deploy.yml          # Backend deployment (replicas, probes, resources)
    ├── service.yml         # NodePort service exposing port 30500
    ├── ingress.yml         # NGINX Ingress rules
    ├── pod.yml             # Standalone test pod
    └── encode-secrets.sh   # Utility script to encode .env into K8s secrets
```

---

## Deployment Instructions

### 1. Configure Secrets

> **⚠️ Security Warning:** Never commit real secrets to Git. `k8s/secrets.yml` is ignored by `.gitignore`.

Generate `k8s/secrets.yml` from your `.env` file using the helper script:

```bash
cd k8s
bash encode-secrets.sh ../../Coding-Plateform/Backend/.env
```

Or apply secrets directly via `kubectl`:

```bash
kubectl create secret generic backend-secrets \
  --namespace=nextgen \
  --from-env-file=../../Coding-Plateform/Backend/.env
```

### 2. Manual Deployment Order

```bash
kubectl apply -f k8s/namespace.yml
kubectl apply -f k8s/configmap.yml
kubectl apply -f k8s/secrets.yml
kubectl apply -f k8s/deploy.yml
kubectl apply -f k8s/service.yml
kubectl apply -f k8s/ingress.yml
```

### 3. Verify Deployment

```bash
# Check all resources in the nextgen namespace
kubectl get all -n nextgen

# Check backend pod logs
kubectl logs -n nextgen -l app=coding-platform-backend

# Check deployment status
kubectl rollout status deployment/backend -n nextgen
```

---

## Argo CD Application Setup

To deploy via Argo CD, create an Argo CD Application referencing this repository:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nextgen-backend
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
