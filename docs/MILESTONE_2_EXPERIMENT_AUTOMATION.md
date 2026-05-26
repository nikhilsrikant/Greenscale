# Milestone 2: Experiment automation

## Objective

This milestone converts the GreenScale MVP from a manual demo into a repeatable research experiment harness. It repeatedly invokes the orchestrator with different workload classes, records scheduler decisions, computes SLO and carbon/cost metrics, and generates report-ready charts.

## What it measures

For each request, the automation records:

- Scenario name
- Workload type
- Priority class
- SLO target
- Selected region and provider
- Scheduler score
- Estimated latency
- Estimated carbon impact
- Estimated cost
- Client-observed end-to-end latency
- Worker execution latency
- Cold-start status
- Observed SLO violation flag
- Full alternatives list returned by the scheduler

## Default scenarios

The default scenario definitions are stored in `experiments/scenarios.json`:

1. `latency_critical_text`
2. `delay_tolerant_batch_text`
3. `strict_ml_inference`
4. `balanced_image_processing`
5. `stream_aggregate_delay_tolerant`

## Windows command

Start GreenScale first:

```powershell
docker compose up --build
```

Then, in another PowerShell window:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\windows_run_milestone2.ps1
```

## Output files

A new folder is created under `results/`, for example:

```text
results/run_20260526T031000Z/
  experiment_results.csv
  raw_responses.jsonl
  summary.json
  summary.md
  charts/
    selected_region_counts.png
    observed_latency_by_scenario.png
    slo_violation_rate_by_scenario.png
    mean_estimated_carbon_by_scenario.png
    selected_regions_by_scenario.png
```

## How to use this in a report

Use `summary.md` as a first draft for your methodology and results section. Use the charts as experimental figures. The CSV can be imported into Excel, R, Jupyter, or Python for more detailed statistical analysis.

## Suggested PhD-level interpretation

The key research question is whether workload class changes scheduling behavior:

- Latency-critical workloads should select lower-latency regions more often.
- Delay-tolerant workloads should shift toward lower-carbon or lower-cost regions when SLO constraints allow.
- Strict SLO workloads should show lower SLO violation risk than carbon-only placement would.

The next milestone can add explicit baseline policies, such as latency-only, carbon-only, cost-only, and random placement.
