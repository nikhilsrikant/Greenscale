from __future__ import annotations

import hashlib
import math
import os
import random
import statistics
import time
from typing import Any

from fastapi import FastAPI, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from pydantic import BaseModel, Field

REGION_NAME = os.getenv("REGION_NAME", "local-region")
PROVIDER = os.getenv("PROVIDER", "local")
SIMULATED_LATENCY_MS = float(os.getenv("SIMULATED_LATENCY_MS", "50"))
COLD_START_PROBABILITY = float(os.getenv("COLD_START_PROBABILITY", "0.05"))
COLD_START_MS = float(os.getenv("COLD_START_MS", "150"))

RUNS_TOTAL = Counter(
    "greenscale_worker_runs_total",
    "Total workloads executed by a worker.",
    ["region", "provider", "workload"],
)
COLD_STARTS_TOTAL = Counter(
    "greenscale_worker_cold_starts_total",
    "Simulated cold starts.",
    ["region", "provider", "workload"],
)
RUN_LATENCY = Histogram(
    "greenscale_worker_run_latency_seconds",
    "Worker workload execution latency.",
    ["region", "provider", "workload"],
)


class WorkloadRequest(BaseModel):
    payload: dict[str, Any] = Field(default_factory=dict)
    slo_ms: int = 500
    priority: str = "balanced"
    estimated_energy_kwh: float = 0.00008
    deadline_seconds: int | None = None


app = FastAPI(
    title="GreenScale Worker",
    version="0.1.0",
    description="Cloud-region worker used by the GreenScale orchestrator.",
)


@app.get("/health")
async def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "region": REGION_NAME,
        "provider": PROVIDER,
        "simulated_latency_ms": SIMULATED_LATENCY_MS,
        "cold_start_probability": COLD_START_PROBABILITY,
        "cold_start_ms": COLD_START_MS,
    }


@app.post("/run/{workload}")
async def run_workload(workload: str, request: WorkloadRequest) -> dict[str, Any]:
    started = time.perf_counter()
    cold_start = random.random() < COLD_START_PROBABILITY
    delay_ms = SIMULATED_LATENCY_MS + (COLD_START_MS if cold_start else 0.0)
    time.sleep(delay_ms / 1000.0)

    result = execute(workload, request.payload)
    elapsed_ms = (time.perf_counter() - started) * 1000.0

    RUNS_TOTAL.labels(region=REGION_NAME, provider=PROVIDER, workload=workload).inc()
    if cold_start:
        COLD_STARTS_TOTAL.labels(region=REGION_NAME, provider=PROVIDER, workload=workload).inc()
    RUN_LATENCY.labels(region=REGION_NAME, provider=PROVIDER, workload=workload).observe(elapsed_ms / 1000.0)

    return {
        "region": REGION_NAME,
        "provider": PROVIDER,
        "workload": workload,
        "cold_start": cold_start,
        "simulated_delay_ms": delay_ms,
        "elapsed_ms": elapsed_ms,
        "result": result,
    }


@app.get("/metrics")
async def metrics() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


def execute(workload: str, payload: dict[str, Any]) -> dict[str, Any]:
    if workload == "text-classify":
        return text_classify(str(payload.get("text", "")))
    if workload == "ml-inference":
        return ml_inference(int(payload.get("samples", 128)))
    if workload == "image-compress":
        return image_compress(str(payload.get("image_id", "synthetic-image")))
    if workload == "stream-aggregate":
        return stream_aggregate(payload.get("values", [1, 2, 3, 4, 5]))
    return generic_hash(payload)


def text_classify(text: str) -> dict[str, Any]:
    tokens = [token.lower() for token in text.split()]
    cloud_terms = {"cloud", "kubernetes", "serverless", "aws", "azure", "gcp", "carbon"}
    score = sum(1 for token in tokens if token in cloud_terms)
    label = "cloud-computing" if score > 0 else "general"
    digest = hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]
    return {"label": label, "keyword_hits": score, "digest": digest}


def ml_inference(samples: int) -> dict[str, Any]:
    samples = max(1, min(samples, 5000))
    values = [math.sin(i / 11.0) * math.cos(i / 17.0) for i in range(samples)]
    probability = 1.0 / (1.0 + math.exp(-sum(values) / samples))
    return {"class_id": int(probability > 0.5), "probability": probability, "samples": samples}


def image_compress(image_id: str) -> dict[str, Any]:
    raw = (image_id * 1024).encode("utf-8")
    digest = hashlib.blake2b(raw, digest_size=16).hexdigest()
    estimated_original_kb = len(raw) / 1024.0
    estimated_compressed_kb = estimated_original_kb * 0.37
    return {
        "image_id": image_id,
        "digest": digest,
        "estimated_original_kb": estimated_original_kb,
        "estimated_compressed_kb": estimated_compressed_kb,
    }


def stream_aggregate(values: Any) -> dict[str, Any]:
    if not isinstance(values, list):
        values = [values]
    numeric = [float(value) for value in values if isinstance(value, (int, float))]
    if not numeric:
        numeric = [0.0]
    return {
        "count": len(numeric),
        "mean": statistics.fmean(numeric),
        "min": min(numeric),
        "max": max(numeric),
    }


def generic_hash(payload: dict[str, Any]) -> dict[str, Any]:
    body = repr(sorted(payload.items())).encode("utf-8")
    return {"digest": hashlib.sha256(body).hexdigest()}
