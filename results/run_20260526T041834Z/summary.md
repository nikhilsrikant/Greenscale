# GreenScale Milestone 2 experiment summary

Generated at: `2026-05-26T04:18:37.878Z`

## Methodology

The experiment suite sends repeated requests to the GreenScale orchestrator and records the selected cloud region, scheduler score, estimated carbon impact, estimated cost, worker latency, client-observed latency, cold-start status, and SLO outcomes.

## Scenario configuration

| Scenario | Workload | Priority | SLO ms | Description |
|---|---:|---:|---:|---|
| latency_critical_text | text-classify | latency-critical | 450 | Short text-classification requests with a user-facing latency SLO. |
| delay_tolerant_batch_text | text-classify | delay-tolerant | 1200 | Delay-tolerant batch text workload where greener routing should be preferred when SLO permits. |
| strict_ml_inference | ml-inference | latency-critical | 180 | Latency-sensitive ML inference with a strict SLO. |
| balanced_image_processing | image-compress | balanced | 650 | Balanced image-processing jobs with moderate latency and carbon constraints. |
| stream_aggregate_delay_tolerant | stream-aggregate | delay-tolerant | 1000 | Delay-tolerant stream aggregation workload with numeric event batches. |

## Results

| Scenario | Requests | Successes | Dominant region | Mean latency ms | p95 latency ms | SLO violation rate | Mean carbon gCO2 | Total carbon gCO2 | Total cost USD | Cold-start rate |
|---|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|
| latency_critical_text | 10 | 10 | gcp-us-central1 | 143.92 | 227.68 | 0.0% | 0.041600 | 0.416000 | 0.0000020000 | 10.0% |
| delay_tolerant_batch_text | 10 | 10 | gcp-us-central1 | 127.24 | 159.02 | 0.0% | 0.041600 | 0.416000 | 0.0000020000 | 0.0% |
| strict_ml_inference | 10 | 10 | gcp-us-central1 | 160.67 | 272.78 | 20.0% | 0.062400 | 0.624000 | 0.0000020000 | 10.0% |
| balanced_image_processing | 10 | 10 | gcp-us-central1 | 140.40 | 214.17 | 0.0% | 0.078000 | 0.780000 | 0.0000020000 | 10.0% |
| stream_aggregate_delay_tolerant | 10 | 10 | gcp-us-central1 | 165.42 | 285.36 | 0.0% | 0.031200 | 0.312000 | 0.0000020000 | 10.0% |

## Interpretation guide

- For latency-critical scenarios, the scheduler should favor lower estimated latency and avoid SLO-risk regions.
- For delay-tolerant scenarios, the scheduler should be more willing to select lower-carbon or lower-cost regions when the SLO allows it.
- Compare observed p95 latency against each scenario's SLO to evaluate whether scheduling choices preserve quality of service.
- Compare selected-region distributions to evaluate whether the scheduler behaves differently across workload classes.
