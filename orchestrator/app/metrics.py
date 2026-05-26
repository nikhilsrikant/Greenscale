from __future__ import annotations

from prometheus_client import Counter, Histogram

REQUESTS_TOTAL = Counter(
    "greenscale_requests_total",
    "Total workload invocation requests received by the orchestrator.",
    ["workload", "priority"],
)

DECISIONS_TOTAL = Counter(
    "greenscale_scheduler_decisions_total",
    "Scheduler decisions by selected region and provider.",
    ["region", "provider", "workload"],
)

SLO_RISK_TOTAL = Counter(
    "greenscale_slo_risk_total",
    "Requests where the selected region is predicted to violate the SLO.",
    ["region", "workload"],
)

ORCHESTRATOR_LATENCY = Histogram(
    "greenscale_orchestrator_latency_seconds",
    "End-to-end orchestrator request latency.",
    ["workload", "region"],
)

WORKER_LATENCY = Histogram(
    "greenscale_worker_latency_seconds",
    "Observed worker call latency from the orchestrator.",
    ["workload", "region"],
)

SCHEDULER_SCORE = Histogram(
    "greenscale_scheduler_score",
    "Scheduler score of selected region.",
    ["region", "provider"],
)


ESTIMATED_CARBON = Histogram(
    "greenscale_estimated_carbon_gco2",
    "Estimated carbon emitted for selected placements, in grams CO2 equivalent.",
    ["region", "provider", "workload"],
    buckets=(0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5),
)

ESTIMATED_COST = Histogram(
    "greenscale_estimated_cost_usd",
    "Estimated request cost for selected placements, in US dollars.",
    ["region", "provider", "workload"],
    buckets=(0.00000005, 0.0000001, 0.0000002, 0.0000005, 0.000001, 0.0000025, 0.000005),
)

SLO_BUDGET_UTILIZATION = Histogram(
    "greenscale_slo_budget_utilization_ratio",
    "Estimated latency divided by the requested SLO. Values above 1.0 indicate predicted violation.",
    ["region", "workload"],
    buckets=(0.1, 0.25, 0.5, 0.75, 0.9, 1.0, 1.25, 1.5, 2.0, 3.0),
)
