from __future__ import annotations

import random

from locust import HttpUser, between, task


class GreenScaleUser(HttpUser):
    wait_time = between(0.2, 1.2)

    @task(5)
    def text_classify(self):
        self.client.post(
            "/invoke/text-classify",
            json={
                "payload": {"text": "cloud serverless carbon kubernetes research"},
                "slo_ms": random.choice([250, 350, 500, 800]),
                "priority": random.choice(["balanced", "latency-critical", "delay-tolerant"]),
            },
        )

    @task(3)
    def ml_inference(self):
        self.client.post(
            "/invoke/ml-inference",
            json={
                "payload": {"samples": random.choice([64, 128, 256, 512])},
                "slo_ms": random.choice([180, 300, 600]),
                "priority": random.choice(["balanced", "latency-critical"]),
            },
        )

    @task(2)
    def stream_aggregate(self):
        values = [random.random() * 100 for _ in range(50)]
        self.client.post(
            "/invoke/stream-aggregate",
            json={
                "payload": {"values": values},
                "slo_ms": 700,
                "priority": "delay-tolerant",
                "deadline_seconds": 120,
            },
        )
