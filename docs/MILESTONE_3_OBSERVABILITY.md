# Milestone 3: Observability with Prometheus and Grafana

Milestone 3 adds a monitoring layer to GreenScale. The orchestrator and workers already expose Prometheus-compatible metrics at `/metrics`; this milestone wires those metrics into Prometheus and auto-loads a Grafana dashboard.

## What this adds

```text
observability/
  prometheus/
    prometheus.yml
  grafana/
    provisioning/
      datasources/prometheus.yml
      dashboards/dashboards.yml
    dashboards/greenscale-dashboard.json

scripts/
  windows_run_milestone3.ps1
  windows_observability_smoke_test.ps1
  run_milestone3.sh
```

The Docker Compose stack now includes:

- `prometheus` on `http://localhost:9090`
- `grafana` on `http://localhost:3000`
- pre-provisioned Grafana datasource
- pre-provisioned GreenScale dashboard

## Windows run command

From PowerShell:

```powershell
cd C:\Users\kulka\downloads\greenscale
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\windows_run_milestone3.ps1
```

The script starts the full stack, waits for the orchestrator, sends sample traffic, checks Prometheus, and prints the dashboard URLs.

## WSL/macOS/Linux run command

```bash
cd greenscale
bash scripts/run_milestone3.sh
```

## URLs

| Component | URL | Notes |
|---|---|---|
| Orchestrator | `http://localhost:8080/health` | Cloud scheduler health |
| Orchestrator metrics | `http://localhost:8080/metrics` | Raw Prometheus metrics |
| Prometheus | `http://localhost:9090` | Query and target status |
| Prometheus targets | `http://localhost:9090/targets` | Check scrape health |
| Grafana | `http://localhost:3000` | Login: `admin` / `greenscale` |

In Grafana, open:

```text
Dashboards -> GreenScale -> GreenScale Cloud Observability
```

## Dashboard panels

The dashboard includes:

1. Request rate by workload
2. Scheduler decisions by region
3. Prometheus scrape health
4. p95 orchestrator latency
5. p95 worker latency
6. Worker cold starts by region
7. Cumulative estimated carbon by region
8. Cumulative estimated cost by region
9. p95 SLO budget utilization
10. Scheduler score distribution

## Smoke test

After the stack is running:

```powershell
.\scripts\windows_observability_smoke_test.ps1
```

Expected result:

```text
Orchestrator metrics: OK
Prometheus query: OK
Grafana: OK
Observability smoke test passed.
```

## Useful Prometheus queries

Request rate:

```promql
sum(rate(greenscale_requests_total[1m])) by (workload)
```

Scheduler decisions:

```promql
sum(greenscale_scheduler_decisions_total) by (region)
```

p95 orchestrator latency:

```promql
histogram_quantile(0.95, sum(rate(greenscale_orchestrator_latency_seconds_bucket[5m])) by (le, workload, region))
```

p95 worker latency:

```promql
histogram_quantile(0.95, sum(rate(greenscale_worker_run_latency_seconds_bucket[5m])) by (le, workload, region))
```

Total estimated carbon by region:

```promql
sum(greenscale_estimated_carbon_gco2_sum) by (region)
```

Total estimated cost by region:

```promql
sum(greenscale_estimated_cost_usd_sum) by (region)
```

SLO budget utilization:

```promql
histogram_quantile(0.95, sum(rate(greenscale_slo_budget_utilization_ratio_bucket[5m])) by (le, workload, region))
```

## Reset the stack

To stop containers but keep images:

```powershell
docker compose down
```

To stop and remove anonymous volumes:

```powershell
docker compose down -v
```

## How this supports the research report

Milestone 2 gave repeatable offline experiment artifacts: CSV, JSONL, summaries, and graphs.

Milestone 3 gives live operational evidence:

- latency traces over time
- region-selection behavior
- cold-start behavior
- Prometheus scrape health
- estimated carbon and cost accumulation
- SLO risk indicators

Together, Milestone 2 and Milestone 3 let you support both a systems implementation section and an experimental evaluation section.
