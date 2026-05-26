#!/usr/bin/env bash
set -euo pipefail

echo "Starting port-forwards. Press Ctrl+C to stop all."
kubectl -n greenscale port-forward svc/greenscale-orchestrator 8080:8080 &
P1=$!
kubectl -n greenscale port-forward svc/prometheus 9090:9090 &
P2=$!
kubectl -n greenscale port-forward svc/grafana 3000:3000 &
P3=$!
trap 'kill $P1 $P2 $P3 2>/dev/null || true' EXIT
wait
