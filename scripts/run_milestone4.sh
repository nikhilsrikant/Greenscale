#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-greenscale}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command '$1' was not found." >&2
    exit 1
  fi
}

apply_configmap_from_file() {
  local name="$1"
  local key="$2"
  local path="$3"
  kubectl -n greenscale create configmap "$name" --from-file="$key=$path" --dry-run=client -o yaml | kubectl apply -f -
}

echo "Checking required tools..."
require_cmd docker
require_cmd kubectl
require_cmd kind

echo "Checking Docker engine..."
docker info >/dev/null

echo "Stopping Docker Compose stack if it is running..."
if [ -f docker-compose.yml ]; then
  docker compose down >/dev/null 2>&1 || true
fi

echo "Creating kind cluster '$CLUSTER_NAME' if needed..."
if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  kind create cluster --name "$CLUSTER_NAME" --config ./k8s/kind-config.yaml
fi

echo "Building local Docker images..."
docker build -t greenscale-orchestrator:dev ./orchestrator
docker build -t greenscale-worker:dev ./worker

echo "Loading images into kind..."
kind load docker-image greenscale-orchestrator:dev --name "$CLUSTER_NAME"
kind load docker-image greenscale-worker:dev --name "$CLUSTER_NAME"

echo "Applying namespace..."
kubectl apply -f ./k8s/namespace.yaml

echo "Creating observability ConfigMaps..."
apply_configmap_from_file prometheus-config prometheus.yml ./observability/prometheus/prometheus-k8s.yml
apply_configmap_from_file grafana-datasources prometheus.yml ./observability/grafana/provisioning/datasources/prometheus.yml
apply_configmap_from_file grafana-dashboard-providers dashboards.yml ./observability/grafana/provisioning/dashboards/dashboards.yml
apply_configmap_from_file grafana-dashboard greenscale-dashboard.json ./observability/grafana/dashboards/greenscale-dashboard.json

echo "Applying GreenScale Kubernetes manifests..."
kubectl apply -f ./k8s/configmap.yaml
kubectl apply -f ./k8s/workers.yaml
kubectl apply -f ./k8s/orchestrator.yaml
kubectl apply -f ./k8s/hpa.yaml
kubectl apply -f ./k8s/observability.yaml

echo "Waiting for rollouts..."
kubectl -n greenscale rollout status deploy/aws-worker --timeout=180s
kubectl -n greenscale rollout status deploy/azure-worker --timeout=180s
kubectl -n greenscale rollout status deploy/gcp-worker --timeout=180s
kubectl -n greenscale rollout status deploy/greenscale-orchestrator --timeout=180s
kubectl -n greenscale rollout status deploy/prometheus --timeout=180s
kubectl -n greenscale rollout status deploy/grafana --timeout=180s

kubectl -n greenscale get pods,svc,hpa

echo "Milestone 4 deployment is ready."
echo "Run: ./scripts/k8s_port_forward.sh"
echo "Then run: ./scripts/k8s_smoke_test.sh"
