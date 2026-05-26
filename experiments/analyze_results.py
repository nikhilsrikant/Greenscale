from __future__ import annotations

import argparse
import csv
import json
import statistics
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


def read_rows(csv_path: Path) -> list[dict[str, Any]]:
    with csv_path.open("r", newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def as_float(value: Any) -> float | None:
    try:
        if value in (None, ""):
            return None
        return float(value)
    except (TypeError, ValueError):
        return None


def is_true(value: Any) -> bool:
    return str(value).lower() == "true"


def successful_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [row for row in rows if is_true(row.get("success"))]


def scenario_order(rows: list[dict[str, Any]]) -> list[str]:
    seen: list[str] = []
    for row in rows:
        name = str(row.get("scenario", "unknown"))
        if name not in seen:
            seen.append(name)
    return seen


def generate_charts(csv_path: Path, out_dir: Path) -> list[Path]:
    try:
        import matplotlib.pyplot as plt
    except ImportError as exc:
        raise SystemExit(
            "matplotlib is required for charts. Install it with: pip install -r experiments/requirements.txt"
        ) from exc

    rows = successful_rows(read_rows(csv_path))
    if not rows:
        raise SystemExit("No successful rows found in CSV; charts cannot be generated.")

    out_dir.mkdir(parents=True, exist_ok=True)
    charts: list[Path] = []

    # Chart 1: selected region counts.
    region_counts = Counter(str(row.get("selected_region", "unknown")) for row in rows)
    fig = plt.figure(figsize=(9, 5))
    plt.bar(list(region_counts.keys()), list(region_counts.values()))
    plt.title("Selected region counts")
    plt.xlabel("Region")
    plt.ylabel("Requests")
    plt.xticks(rotation=25, ha="right")
    plt.tight_layout()
    path = out_dir / "selected_region_counts.png"
    fig.savefig(path, dpi=160)
    plt.close(fig)
    charts.append(path)

    # Chart 2: observed end-to-end latency by scenario.
    scenarios = scenario_order(rows)
    latency_groups: list[list[float]] = []
    labels: list[str] = []
    for scenario in scenarios:
        values = [as_float(row.get("observed_end_to_end_ms")) for row in rows if row.get("scenario") == scenario]
        numeric = [value for value in values if value is not None]
        if numeric:
            latency_groups.append(numeric)
            labels.append(scenario)
    if latency_groups:
        fig = plt.figure(figsize=(11, 6))
        plt.boxplot(latency_groups, tick_labels=labels, showmeans=True)
        plt.title("Observed end-to-end latency by scenario")
        plt.xlabel("Scenario")
        plt.ylabel("Latency (ms)")
        plt.xticks(rotation=25, ha="right")
        plt.tight_layout()
        path = out_dir / "observed_latency_by_scenario.png"
        fig.savefig(path, dpi=160)
        plt.close(fig)
        charts.append(path)

    # Chart 3: SLO violation rate by scenario.
    slo_rates: list[float] = []
    labels = []
    for scenario in scenarios:
        subset = [row for row in rows if row.get("scenario") == scenario]
        if subset:
            labels.append(scenario)
            slo_rates.append(sum(1 for row in subset if is_true(row.get("observed_slo_violation"))) / len(subset) * 100.0)
    fig = plt.figure(figsize=(11, 5))
    plt.bar(labels, slo_rates)
    plt.title("Observed SLO violation rate by scenario")
    plt.xlabel("Scenario")
    plt.ylabel("SLO violation rate (%)")
    plt.xticks(rotation=25, ha="right")
    plt.tight_layout()
    path = out_dir / "slo_violation_rate_by_scenario.png"
    fig.savefig(path, dpi=160)
    plt.close(fig)
    charts.append(path)

    # Chart 4: mean estimated carbon by scenario.
    carbon_means: list[float] = []
    labels = []
    for scenario in scenarios:
        values = [as_float(row.get("estimated_carbon_gco2")) for row in rows if row.get("scenario") == scenario]
        numeric = [value for value in values if value is not None]
        if numeric:
            labels.append(scenario)
            carbon_means.append(statistics.fmean(numeric))
    if carbon_means:
        fig = plt.figure(figsize=(11, 5))
        plt.bar(labels, carbon_means)
        plt.title("Mean estimated carbon per request by scenario")
        plt.xlabel("Scenario")
        plt.ylabel("Estimated carbon (gCO2/request)")
        plt.xticks(rotation=25, ha="right")
        plt.tight_layout()
        path = out_dir / "mean_estimated_carbon_by_scenario.png"
        fig.savefig(path, dpi=160)
        plt.close(fig)
        charts.append(path)

    # Chart 5: selected region counts per scenario as stacked-like grouped bars.
    # Implemented as plain grouped bars with default matplotlib styling.
    all_regions = sorted({str(row.get("selected_region", "unknown")) for row in rows})
    scenario_counts: dict[str, Counter[str]] = defaultdict(Counter)
    for row in rows:
        scenario_counts[str(row.get("scenario", "unknown"))][str(row.get("selected_region", "unknown"))] += 1
    x = list(range(len(scenarios)))
    width = 0.8 / max(1, len(all_regions))
    fig = plt.figure(figsize=(12, 6))
    for idx, region in enumerate(all_regions):
        offsets = [position + (idx - (len(all_regions) - 1) / 2.0) * width for position in x]
        values = [scenario_counts[scenario][region] for scenario in scenarios]
        plt.bar(offsets, values, width=width, label=region)
    plt.title("Selected regions by scenario")
    plt.xlabel("Scenario")
    plt.ylabel("Requests")
    plt.xticks(x, scenarios, rotation=25, ha="right")
    plt.legend()
    plt.tight_layout()
    path = out_dir / "selected_regions_by_scenario.png"
    fig.savefig(path, dpi=160)
    plt.close(fig)
    charts.append(path)

    manifest = out_dir / "charts_manifest.json"
    manifest.write_text(json.dumps([str(path) for path in charts], indent=2), encoding="utf-8")
    return charts


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate GreenScale experiment charts.")
    parser.add_argument("--input", type=Path, required=True, help="Path to experiment_results.csv.")
    parser.add_argument("--out-dir", type=Path, default=None, help="Chart output directory.")
    args = parser.parse_args()

    out_dir = args.out_dir or (args.input.parent / "charts")
    charts = generate_charts(args.input, out_dir)
    print("Generated charts:")
    for path in charts:
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
