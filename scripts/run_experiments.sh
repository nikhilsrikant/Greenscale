#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f docker-compose.yml ]]; then
  echo "Run this script from the GreenScale project root." >&2
  exit 1
fi

python3 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r experiments/requirements.txt
python experiments/run_experiments.py --base-url http://localhost:8080 --out-dir results --iterations 10 --concurrency 2 --analyze
