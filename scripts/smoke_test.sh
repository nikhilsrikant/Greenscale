#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"

curl -fsS "$BASE_URL/health" >/dev/null
curl -fsS -X POST "$BASE_URL/invoke/text-classify" \
  -H 'Content-Type: application/json' \
  -d '{"payload":{"text":"cloud kubernetes carbon"},"slo_ms":500}' >/dev/null

echo "GreenScale smoke test passed against $BASE_URL"
