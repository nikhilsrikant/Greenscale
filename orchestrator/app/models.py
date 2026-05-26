from __future__ import annotations

from enum import Enum
from typing import Any

from pydantic import BaseModel, Field, HttpUrl, field_validator


class Priority(str, Enum):
    latency_critical = "latency-critical"
    balanced = "balanced"
    delay_tolerant = "delay-tolerant"


class WorkloadRequest(BaseModel):
    payload: dict[str, Any] = Field(default_factory=dict)
    slo_ms: int = Field(default=500, ge=50, le=60_000)
    priority: Priority = Priority.balanced
    estimated_energy_kwh: float = Field(default=0.00008, gt=0.0)
    deadline_seconds: int | None = Field(default=None, ge=1)


class RegionEndpoint(BaseModel):
    name: str
    provider: str
    url: str
    zone: str | None = None
    base_latency_ms: float = Field(default=100.0, ge=0.0)
    carbon_gco2_kwh: float = Field(default=400.0, ge=0.0)
    cost_per_million_requests: float = Field(default=0.20, ge=0.0)
    cold_start_ms: float = Field(default=150.0, ge=0.0)
    capacity_weight: float = Field(default=1.0, gt=0.0)
    enabled: bool = True

    @field_validator("url")
    @classmethod
    def strip_trailing_slash(cls, value: str) -> str:
        return value.rstrip("/")


class RegionScore(BaseModel):
    region: RegionEndpoint
    score: float
    estimated_latency_ms: float
    estimated_carbon_gco2: float
    estimated_cost_usd: float
    slo_violation_risk: bool
    components: dict[str, float]


class InvocationResult(BaseModel):
    selected_region: str
    provider: str
    workload: str
    scheduler_score: float
    estimated_latency_ms: float
    estimated_carbon_gco2: float
    estimated_cost_usd: float
    slo_ms: int
    worker_response: dict[str, Any]
    alternatives: list[dict[str, Any]]
