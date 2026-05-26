from __future__ import annotations

import pytest

from orchestrator.app.carbon_provider import CarbonProvider
from orchestrator.app.models import Priority, RegionEndpoint, WorkloadRequest
from orchestrator.app.scheduler import CarbonAwareScheduler, SchedulerWeights


@pytest.mark.asyncio
async def test_latency_critical_prefers_low_latency_when_slo_is_strict():
    regions = [
        RegionEndpoint(name="low-carbon-slow", provider="test", url="http://slow", base_latency_ms=300, carbon_gco2_kwh=50, cost_per_million_requests=0.10, cold_start_ms=50),
        RegionEndpoint(name="high-carbon-fast", provider="test", url="http://fast", base_latency_ms=50, carbon_gco2_kwh=600, cost_per_million_requests=0.20, cold_start_ms=50),
    ]
    scheduler = CarbonAwareScheduler(
        regions=regions,
        carbon_provider=CarbonProvider(None),
        weights=SchedulerWeights(alpha_latency=0.8, beta_cost=0.05, gamma_carbon=0.1, delta_coldstart=0.05),
        strict_slo=True,
    )
    request = WorkloadRequest(slo_ms=120, priority=Priority.latency_critical)
    choice = await scheduler.choose(request)
    assert choice.region.name == "high-carbon-fast"
    assert choice.slo_violation_risk is False


@pytest.mark.asyncio
async def test_carbon_weight_prefers_low_carbon_when_slo_allows():
    regions = [
        RegionEndpoint(name="low-carbon-slow", provider="test", url="http://slow", base_latency_ms=130, carbon_gco2_kwh=50, cost_per_million_requests=0.10, cold_start_ms=50),
        RegionEndpoint(name="high-carbon-fast", provider="test", url="http://fast", base_latency_ms=50, carbon_gco2_kwh=600, cost_per_million_requests=0.20, cold_start_ms=50),
    ]
    scheduler = CarbonAwareScheduler(
        regions=regions,
        carbon_provider=CarbonProvider(None),
        weights=SchedulerWeights(alpha_latency=0.1, beta_cost=0.05, gamma_carbon=0.8, delta_coldstart=0.05),
        strict_slo=True,
    )
    request = WorkloadRequest(slo_ms=300, priority=Priority.balanced)
    choice = await scheduler.choose(request)
    assert choice.region.name == "low-carbon-slow"


@pytest.mark.asyncio
async def test_rank_returns_all_regions_ordered_by_score():
    regions = [
        RegionEndpoint(name="a", provider="test", url="http://a", base_latency_ms=100, carbon_gco2_kwh=100, cost_per_million_requests=0.20, cold_start_ms=100),
        RegionEndpoint(name="b", provider="test", url="http://b", base_latency_ms=200, carbon_gco2_kwh=400, cost_per_million_requests=0.50, cold_start_ms=150),
        RegionEndpoint(name="c", provider="test", url="http://c", base_latency_ms=50, carbon_gco2_kwh=250, cost_per_million_requests=0.30, cold_start_ms=70),
    ]
    scheduler = CarbonAwareScheduler(
        regions=regions,
        carbon_provider=CarbonProvider(None),
        weights=SchedulerWeights(),
    )
    ranked = await scheduler.rank(WorkloadRequest(slo_ms=1000))
    assert len(ranked) == 3
    assert ranked == sorted(ranked, key=lambda item: item.score)
