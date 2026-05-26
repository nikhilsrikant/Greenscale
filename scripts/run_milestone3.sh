#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  cp .env.example .env
fi

echo "Starting GreenScale with Prometheus and Grafana..."
docker compose up -d --build

echo "Waiting for orchestrator health endpoint..."
for _ in $(seq 1 40); do
  if curl -fsS http://localhost:8080/health >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

curl -fsS http://localhost:8080/health >/dev/null

echo "Generating sample traffic for dashboards..."
for _ in $(seq 1 8); do
  curl -fsS -X POST http://localhost:8080/invoke/text-classify \
    -H 'Content-Type: application/json' \
    -d '{"payload":{"text":"cloud computing carbon-aware scheduling"},"slo_ms":450,"priority":"latency-critical"}' >/dev/null || true
  curl -fsS -X POST http://localhost:8080/invoke/text-classify \
    -H 'Content-Type: application/json' \
    -d '{"payload":{"text":"batch analytics green workload"},"slo_ms":1200,"priority":"delay-tolerant"}' >/dev/null || true
  curl -fsS -X POST http://localhost:8080/invoke/ml-inference \
    -H 'Content-Type: application/json' \
    -d '{"payload":{"samples":512},"slo_ms":300,"priority":"latency-critical"}' >/dev/null || true
  curl -fsS -X POST http://localhost:8080/invoke/image-compress \
    -H 'Content-Type: application/json' \
    -d '{"payload":{"image_id":"synthetic-cloud-image"},"slo_ms":800,"priority":"balanced"}' >/dev/null || true
  curl -fsS -X POST http://localhost:8080/invoke/stream-aggregate \
    -H 'Content-Type: application/json' \
    -d '{"payload":{"values":[1,4,9,16,25,36]},"slo_ms":600,"priority":"balanced"}' >/dev/null || true
done

echo "Milestone 3 is running."
echo "Orchestrator: http://localhost:8080/health"
echo "Prometheus:   http://localhost:9090/targets"
echo "Grafana:      http://localhost:3000"
echo "Grafana login: admin / greenscale"
echo "Dashboard: GreenScale / GreenScale Cloud Observability"
