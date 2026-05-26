#!/usr/bin/env bash
set -euo pipefail

echo "Testing orchestrator health endpoint..."
curl -fsS http://localhost:8080/health >/dev/null

echo "Invoking workload..."
curl -fsS -X POST http://localhost:8080/invoke/text-classify \
  -H 'Content-Type: application/json' \
  -d '{"payload":{"text":"kubernetes milestone four cloud scheduling workload"},"slo_ms":450,"priority":"latency-critical"}' >/dev/null

echo "Testing metrics endpoint..."
curl -fsS http://localhost:8080/metrics | grep -q greenscale_requests_total

echo "Testing Prometheus..."
curl -fsS 'http://localhost:9090/api/v1/query?query=greenscale_requests_total' | grep -q '"status":"success"'

echo "Testing Grafana..."
curl -fsS http://localhost:3000/login >/dev/null

echo "Milestone 4 Kubernetes smoke test passed."
