#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-greenscale}"

if ! kind get clusters | grep -qx "$CLUSTER_NAME"; then
  kind create cluster --name "$CLUSTER_NAME"
fi

docker build -t greenscale-orchestrator:dev ./orchestrator
docker build -t greenscale-worker:dev ./worker
kind load docker-image greenscale-orchestrator:dev --name "$CLUSTER_NAME"
kind load docker-image greenscale-worker:dev --name "$CLUSTER_NAME"
kubectl apply -f k8s/
kubectl -n greenscale rollout status deployment/greenscale-orchestrator

echo "Run: kubectl -n greenscale port-forward svc/greenscale-orchestrator 8080:8080"
