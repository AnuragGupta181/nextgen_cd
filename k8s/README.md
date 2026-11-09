# K8s Deployment — Coding Platform Backend

## Prerequisites

- Minikube running: `minikube start`
- Docker image built inside Minikube's Docker daemon:
  ```bash
  eval $(minikube docker-env)
  docker build -t nextgen-backend:latest ./../../Backend/
  ```

## Apply Order

```bash
# From the repo root:
kubectl apply -f deployment/k8s/namespace.yml
kubectl apply -f deployment/k8s/configmap.yml
kubectl apply -f deployment/k8s/secrets.yml
kubectl apply -f deployment/k8s/deploy.yml
kubectl apply -f deployment/k8s/service.yml
```

## Verify

```bash
# Check all resources in the namespace
kubectl get all -n nextgen

# Check pod logs
kubectl logs -n nextgen -l app=coding-platform-backend

# Check if the pod is healthy
kubectl describe pod -n nextgen -l app=coding-platform-backend

# Get the URL to access the backend
minikube service backend-service -n nextgen --url
```

## Teardown

```bash
# Delete everything in the namespace (clean slate)
kubectl delete namespace nextgen
```

## Secrets

Before applying `secrets.yml`, replace the placeholder values with your
base64-encoded secrets. Use the helper script:

```bash
bash deployment/k8s/encode-secrets.sh
```

Or encode manually:

```bash
echo -n 'your-value-here' | base64
```

> **Never commit real secrets to git.** Add `secrets.yml` to `.gitignore`
> or use `kubectl create secret` from your `.env` file directly:
> ```bash
> kubectl create secret generic backend-secrets \
>   --namespace=nextgen \
>   --from-env-file=Backend/.env
> ```

