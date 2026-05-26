from __future__ import annotations

import argparse
import csv
import json
import os
import statistics
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DEFAULT_SCENARIOS_FILE = Path(__file__).with_name("scenarios.json")
CSV_FIELDS = [
    "timestamp_utc",
    "run_id",
    "scenario",
    "iteration",
    "workload",
    "priority",
    "slo_ms",
    "success",
    "error",
    "selected_region",
    "provider",
    "scheduler_score",
    "estimated_latency_ms",
    "estimated_carbon_gco2",
    "estimated_cost_usd",
    "observed_end_to_end_ms",
    "observed_slo_violation",
    "worker_elapsed_ms",
    "worker_cold_start",
    "worker_simulated_delay_ms",
    "alternatives_json",
]


@dataclass(frozen=True)
class Scenario:
    name: str
    description: str
    workload: str
    priority: str
    slo_ms: int
    estimated_energy_kwh: float
    payload_template: dict[str, Any]
    deadline_seconds: int | None = None

    @staticmethod
    def from_dict(raw: dict[str, Any]) -> "Scenario":
        return Scenario(
            name=str(raw["name"]),
            description=str(raw.get("description", "")),
            workload=str(raw["workload"]),
            priority=str(raw.get("priority", "balanced")),
            slo_ms=int(raw.get("slo_ms", 500)),
            estimated_energy_kwh=float(raw.get("estimated_energy_kwh", 0.00008)),
            deadline_seconds=(None if raw.get("deadline_seconds") is None else int(raw["deadline_seconds"])),
            payload_template=dict(raw.get("payload_template", {})),
        )


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def load_scenarios(path: Path) -> list[Scenario]:
    with path.open("r", encoding="utf-8") as handle:
        raw = json.load(handle)
    if not isinstance(raw, list):
        raise ValueError("scenarios.json must contain a list of scenarios")
    return [Scenario.from_dict(item) for item in raw]


def render_template(value: Any, iteration: int) -> Any:
    if isinstance(value, str):
        if value.startswith("expr:"):
            expression = value.removeprefix("expr:")
            return eval(  # noqa: S307 - scenario file is local project configuration.
                expression,
                {"__builtins__": {}},
                {"i": iteration, "range": range, "min": min, "max": max, "sum": sum, "len": len},
            )
        return value.format(i=iteration)
    if isinstance(value, list):
        return [render_template(item, iteration) for item in value]
    if isinstance(value, dict):
        return {key: render_template(item, iteration) for key, item in value.items()}
    return value


def build_request_payload(scenario: Scenario, iteration: int) -> dict[str, Any]:
    body: dict[str, Any] = {
        "payload": render_template(scenario.payload_template, iteration),
        "slo_ms": scenario.slo_ms,
        "priority": scenario.priority,
        "estimated_energy_kwh": scenario.estimated_energy_kwh,
    }
    if scenario.deadline_seconds is not None:
        body["deadline_seconds"] = scenario.deadline_seconds
    return body


def post_json(url: str, body: dict[str, Any], timeout: float) -> dict[str, Any]:
    data = json.dumps(body).encode("utf-8")
    request = urllib.request.Request(
        url=url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:  # noqa: S310 - user-provided localhost/cloud endpoint.
        return json.loads(response.read().decode("utf-8"))


def get_json(url: str, timeout: float) -> dict[str, Any]:
    with urllib.request.urlopen(url, timeout=timeout) as response:  # noqa: S310 - user-provided localhost/cloud endpoint.
        return json.loads(response.read().decode("utf-8"))


def run_single(base_url: str, scenario: Scenario, iteration: int, run_id: str, timeout: float) -> tuple[dict[str, Any], dict[str, Any]]:
    body = build_request_payload(scenario, iteration)
    url = f"{base_url.rstrip('/')}/invoke/{scenario.workload}"
    started = time.perf_counter()
    timestamp = utc_now()
    raw_record: dict[str, Any] = {
        "timestamp_utc": timestamp,
        "run_id": run_id,
        "scenario": scenario.name,
        "iteration": iteration,
        "request": body,
        "response": None,
        "error": None,
    }

    row: dict[str, Any] = {
        "timestamp_utc": timestamp,
        "run_id": run_id,
        "scenario": scenario.name,
        "iteration": iteration,
        "workload": scenario.workload,
        "priority": scenario.priority,
        "slo_ms": scenario.slo_ms,
        "success": False,
        "error": "",
        "selected_region": "",
        "provider": "",
        "scheduler_score": "",
        "estimated_latency_ms": "",
        "estimated_carbon_gco2": "",
        "estimated_cost_usd": "",
        "observed_end_to_end_ms": "",
        "observed_slo_violation": "",
        "worker_elapsed_ms": "",
        "worker_cold_start": "",
        "worker_simulated_delay_ms": "",
        "alternatives_json": "",
    }

    try:
        response = post_json(url, body, timeout=timeout)
        observed_ms = (time.perf_counter() - started) * 1000.0
        worker = response.get("worker_response", {}) or {}
        alternatives = response.get("alternatives", []) or []
        row.update(
            {
                "success": True,
                "selected_region": response.get("selected_region", ""),
                "provider": response.get("provider", ""),
                "scheduler_score": response.get("scheduler_score", ""),
                "estimated_latency_ms": response.get("estimated_latency_ms", ""),
                "estimated_carbon_gco2": response.get("estimated_carbon_gco2", ""),
                "estimated_cost_usd": response.get("estimated_cost_usd", ""),
                "observed_end_to_end_ms": observed_ms,
                "observed_slo_violation": observed_ms > scenario.slo_ms,
                "worker_elapsed_ms": worker.get("elapsed_ms", ""),
                "worker_cold_start": worker.get("cold_start", ""),
                "worker_simulated_delay_ms": worker.get("simulated_delay_ms", ""),
                "alternatives_json": json.dumps(alternatives, separators=(",", ":")),
            }
        )
        raw_record["response"] = response
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, json.JSONDecodeError, OSError) as exc:
        observed_ms = (time.perf_counter() - started) * 1000.0
        row["observed_end_to_end_ms"] = observed_ms
        row["error"] = f"{type(exc).__name__}: {exc}"
        raw_record["error"] = row["error"]
    return row, raw_record


def percentile(values: list[float], q: float) -> float | None:
    if not values:
        return None
    if len(values) == 1:
        return values[0]
    ordered = sorted(values)
    index = (len(ordered) - 1) * q
    lower = int(index)
    upper = min(lower + 1, len(ordered) - 1)
    weight = index - lower
    return ordered[lower] * (1.0 - weight) + ordered[upper] * weight


def to_float(value: Any) -> float | None:
    try:
        if value == "" or value is None:
            return None
        return float(value)
    except (TypeError, ValueError):
        return None


def summarize(rows: list[dict[str, Any]], scenarios: list[Scenario]) -> dict[str, Any]:
    summary: dict[str, Any] = {
        "generated_at_utc": utc_now(),
        "total_requests": len(rows),
        "successful_requests": sum(1 for row in rows if str(row.get("success")).lower() == "true"),
        "failed_requests": sum(1 for row in rows if str(row.get("success")).lower() != "true"),
        "scenarios": {},
    }
    scenario_names = [scenario.name for scenario in scenarios]
    for scenario_name in scenario_names:
        subset = [row for row in rows if row.get("scenario") == scenario_name]
        successful = [row for row in subset if str(row.get("success")).lower() == "true"]
        latencies = [value for value in (to_float(row.get("observed_end_to_end_ms")) for row in successful) if value is not None]
        worker_latencies = [value for value in (to_float(row.get("worker_elapsed_ms")) for row in successful) if value is not None]
        carbon = [value for value in (to_float(row.get("estimated_carbon_gco2")) for row in successful) if value is not None]
        cost = [value for value in (to_float(row.get("estimated_cost_usd")) for row in successful) if value is not None]
        regions: dict[str, int] = {}
        providers: dict[str, int] = {}
        for row in successful:
            regions[str(row.get("selected_region", "unknown"))] = regions.get(str(row.get("selected_region", "unknown")), 0) + 1
            providers[str(row.get("provider", "unknown"))] = providers.get(str(row.get("provider", "unknown")), 0) + 1
        observed_slo_violations = sum(1 for row in successful if str(row.get("observed_slo_violation")).lower() == "true")
        cold_starts = sum(1 for row in successful if str(row.get("worker_cold_start")).lower() == "true")
        summary["scenarios"][scenario_name] = {
            "requests": len(subset),
            "successes": len(successful),
            "failures": len(subset) - len(successful),
            "selected_regions": regions,
            "selected_providers": providers,
            "mean_observed_latency_ms": statistics.fmean(latencies) if latencies else None,
            "p50_observed_latency_ms": percentile(latencies, 0.50),
            "p95_observed_latency_ms": percentile(latencies, 0.95),
            "p99_observed_latency_ms": percentile(latencies, 0.99),
            "mean_worker_latency_ms": statistics.fmean(worker_latencies) if worker_latencies else None,
            "mean_estimated_carbon_gco2": statistics.fmean(carbon) if carbon else None,
            "total_estimated_carbon_gco2": sum(carbon),
            "mean_estimated_cost_usd": statistics.fmean(cost) if cost else None,
            "total_estimated_cost_usd": sum(cost),
            "observed_slo_violation_rate": observed_slo_violations / len(successful) if successful else None,
            "cold_start_rate": cold_starts / len(successful) if successful else None,
        }
    return summary


def write_summary_markdown(summary: dict[str, Any], scenarios: list[Scenario], path: Path) -> None:
    lines = [
        "# GreenScale Milestone 2 experiment summary",
        "",
        f"Generated at: `{summary['generated_at_utc']}`",
        "",
        "## Methodology",
        "",
        "The experiment suite sends repeated requests to the GreenScale orchestrator and records the selected cloud region, scheduler score, estimated carbon impact, estimated cost, worker latency, client-observed latency, cold-start status, and SLO outcomes.",
        "",
        "## Scenario configuration",
        "",
        "| Scenario | Workload | Priority | SLO ms | Description |",
        "|---|---:|---:|---:|---|",
    ]
    by_name = {scenario.name: scenario for scenario in scenarios}
    for scenario in scenarios:
        lines.append(
            f"| {scenario.name} | {scenario.workload} | {scenario.priority} | {scenario.slo_ms} | {scenario.description} |"
        )
    lines.extend(
        [
            "",
            "## Results",
            "",
            "| Scenario | Requests | Successes | Dominant region | Mean latency ms | p95 latency ms | SLO violation rate | Mean carbon gCO2 | Total carbon gCO2 | Total cost USD | Cold-start rate |",
            "|---|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for scenario_name, item in summary["scenarios"].items():
        regions = item.get("selected_regions", {}) or {}
        dominant_region = max(regions.items(), key=lambda pair: pair[1])[0] if regions else "n/a"
        lines.append(
            "| {scenario} | {requests} | {successes} | {dominant_region} | {mean_latency} | {p95_latency} | {slo_rate} | {mean_carbon} | {total_carbon} | {total_cost} | {cold_rate} |".format(
                scenario=scenario_name,
                requests=item.get("requests"),
                successes=item.get("successes"),
                dominant_region=dominant_region,
                mean_latency=format_metric(item.get("mean_observed_latency_ms"), 2),
                p95_latency=format_metric(item.get("p95_observed_latency_ms"), 2),
                slo_rate=format_percent(item.get("observed_slo_violation_rate")),
                mean_carbon=format_metric(item.get("mean_estimated_carbon_gco2"), 6),
                total_carbon=format_metric(item.get("total_estimated_carbon_gco2"), 6),
                total_cost=format_metric(item.get("total_estimated_cost_usd"), 10),
                cold_rate=format_percent(item.get("cold_start_rate")),
            )
        )
    lines.extend(
        [
            "",
            "## Interpretation guide",
            "",
            "- For latency-critical scenarios, the scheduler should favor lower estimated latency and avoid SLO-risk regions.",
            "- For delay-tolerant scenarios, the scheduler should be more willing to select lower-carbon or lower-cost regions when the SLO allows it.",
            "- Compare observed p95 latency against each scenario's SLO to evaluate whether scheduling choices preserve quality of service.",
            "- Compare selected-region distributions to evaluate whether the scheduler behaves differently across workload classes.",
        ]
    )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def format_metric(value: Any, digits: int) -> str:
    if value is None:
        return "n/a"
    return f"{float(value):.{digits}f}"


def format_percent(value: Any) -> str:
    if value is None:
        return "n/a"
    return f"{float(value) * 100.0:.1f}%"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Run repeatable GreenScale workload experiments.")
    parser.add_argument("--base-url", default="http://localhost:8080", help="GreenScale orchestrator base URL.")
    parser.add_argument("--scenarios", type=Path, default=DEFAULT_SCENARIOS_FILE, help="Path to scenarios JSON.")
    parser.add_argument("--scenario", action="append", help="Run only a named scenario. Can be repeated.")
    parser.add_argument("--out-dir", type=Path, default=Path("results"), help="Base output directory.")
    parser.add_argument("--iterations", type=int, default=10, help="Number of requests per scenario.")
    parser.add_argument("--concurrency", type=int, default=2, help="Maximum concurrent requests.")
    parser.add_argument("--timeout", type=float, default=15.0, help="HTTP timeout in seconds.")
    parser.add_argument("--analyze", action="store_true", help="Generate charts after collecting results.")
    args = parser.parse_args(argv)

    if args.iterations < 1:
        raise ValueError("--iterations must be >= 1")
    if args.concurrency < 1:
        raise ValueError("--concurrency must be >= 1")

    all_scenarios = load_scenarios(args.scenarios)
    if args.scenario:
        wanted = set(args.scenario)
        scenarios = [scenario for scenario in all_scenarios if scenario.name in wanted]
        missing = wanted - {scenario.name for scenario in scenarios}
        if missing:
            raise ValueError(f"Unknown scenario name(s): {', '.join(sorted(missing))}")
    else:
        scenarios = all_scenarios

    print(f"Checking GreenScale orchestrator at {args.base_url} ...", flush=True)
    try:
        health = get_json(f"{args.base_url.rstrip('/')}/health", timeout=args.timeout)
    except Exception as exc:  # noqa: BLE001 - show actionable CLI failure.
        print(f"ERROR: Could not reach GreenScale orchestrator: {exc}", file=sys.stderr)
        print("Make sure Docker Compose is running: docker compose up --build", file=sys.stderr)
        return 2
    print(f"Connected. Regions: {', '.join(health.get('configured_regions', []))}", flush=True)

    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_dir = args.out_dir / f"run_{run_id}"
    charts_dir = run_dir / "charts"
    charts_dir.mkdir(parents=True, exist_ok=True)
    raw_path = run_dir / "raw_responses.jsonl"
    csv_path = run_dir / "experiment_results.csv"
    summary_json_path = run_dir / "summary.json"
    summary_md_path = run_dir / "summary.md"

    jobs: list[tuple[Scenario, int]] = []
    for scenario in scenarios:
        for iteration in range(1, args.iterations + 1):
            jobs.append((scenario, iteration))

    rows: list[dict[str, Any]] = []
    raw_records: list[dict[str, Any]] = []
    print(f"Running {len(jobs)} requests across {len(scenarios)} scenario(s) ...", flush=True)
    with ThreadPoolExecutor(max_workers=args.concurrency) as executor:
        future_to_job = {
            executor.submit(run_single, args.base_url, scenario, iteration, run_id, args.timeout): (scenario, iteration)
            for scenario, iteration in jobs
        }
        completed = 0
        for future in as_completed(future_to_job):
            scenario, iteration = future_to_job[future]
            row, raw = future.result()
            rows.append(row)
            raw_records.append(raw)
            completed += 1
            status = "ok" if row["success"] else "failed"
            print(f"[{completed:03d}/{len(jobs):03d}] {scenario.name} iter={iteration} {status}", flush=True)

    rows.sort(key=lambda item: (str(item["scenario"]), int(item["iteration"])))
    raw_records.sort(key=lambda item: (str(item["scenario"]), int(item["iteration"])))

    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=CSV_FIELDS)
        writer.writeheader()
        writer.writerows(rows)

    with raw_path.open("w", encoding="utf-8") as handle:
        for record in raw_records:
            handle.write(json.dumps(record, separators=(",", ":")) + "\n")

    summary = summarize(rows, scenarios)
    summary_json_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    write_summary_markdown(summary, scenarios, summary_md_path)

    latest_file = args.out_dir / "latest_run.txt"
    latest_file.parent.mkdir(parents=True, exist_ok=True)
    latest_file.write_text(str(run_dir.resolve()), encoding="utf-8")

    print("\nExperiment run complete.")
    print(f"CSV:      {csv_path}")
    print(f"JSONL:    {raw_path}")
    print(f"Summary:  {summary_md_path}")

    if args.analyze:
        from analyze_results import generate_charts

        chart_paths = generate_charts(csv_path, charts_dir)
        print("Charts:")
        for chart in chart_paths:
            print(f"  {chart}")
    else:
        print("\nTo generate charts later:")
        print(f"python experiments/analyze_results.py --input {csv_path} --out-dir {charts_dir}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
