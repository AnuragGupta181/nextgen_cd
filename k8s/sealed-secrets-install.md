# Bitnami Sealed Secrets Controller
# Install this on the K8s cluster ONCE — it decrypts SealedSecret resources into regular Secrets
#
# Option 1: Apply this manifest directly
# Option 2: helm install sealed-secrets -n kube-system --set-string fullnameOverride=sealed-secrets-controller sealed-secrets/sealed-secrets
#
# After installing, use `kubeseal` CLI to encrypt secrets:
#   kubeseal --controller-name=sealed-secrets-controller \
#            --controller-namespace=kube-system \
#            --format yaml < k8s/secrets.yml > k8s/sealed-secrets.yml
#
# Prerequisites:
#   brew install kubeseal   (macOS)
#   or download from https://github.com/bitnami-labs/sealed-secrets/releases

apiVersion: v1
kind: Namespace
metadata:
  name: kube-system
  labels:
    name: kube-system
---
# The Sealed Secrets controller is deployed via Helm for easier upgrades.
# Run these commands on your CD EC2 (K8s cluster node):
#
#   helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
#   helm repo update
#   helm install sealed-secrets sealed-secrets/sealed-secrets \
#     --namespace kube-system \
#     --set fullnameOverride=sealed-secrets-controller
#
# Verify:
#   kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets
