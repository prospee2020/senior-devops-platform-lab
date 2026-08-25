"""Senior DevOps Lab API.

A deliberately small FastAPI service used as the workload for the entire
14-week platform lab. It exposes:

  /healthz   - liveness  (process is alive)
  /readyz    - readiness (safe to receive traffic)
  /api/work  - business endpoint with simulated latency + failures
  /metrics   - Prometheus exposition format

Failure simulation (?delay_ms=, ?fail=true) exists so we can create
realistic SRE incidents (latency SLO burn, 5xx error budget burn)
without hacking the code later.
"""

import os
import time

from fastapi import FastAPI, Response
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Histogram,
    generate_latest,
)

app = FastAPI(title="Senior DevOps Lab API")

REQUESTS = Counter(
    "app_requests_total",
    "Total application requests",
    ["path", "status"],
)

LATENCY = Histogram(
    "app_request_duration_seconds",
    "Application request duration",
    ["path"],
)


@app.get("/healthz")
def healthz():
    """Liveness: only answers 'is the process alive'. Keep it dependency-free."""
    return {"status": "ok"}


@app.get("/readyz")
def readyz():
    """Readiness: 'can I serve traffic'. In later weeks this will check
    downstream dependencies; for Week 1 it is intentionally simple."""
    return {"ready": True}


@app.get("/api/work")
def work(delay_ms: int = 0, fail: bool = False):
    started = time.perf_counter()
    status = "200"

    try:
        if delay_ms > 0:
            # Cap simulated latency at 5s so a typo can't wedge a worker.
            time.sleep(min(delay_ms, 5000) / 1000)

        if fail:
            status = "500"
            return Response(
                content='{"error":"simulated failure"}',
                media_type="application/json",
                status_code=500,
            )

        return {
            "service": os.getenv("SERVICE_NAME", "senior-devops-api"),
            "environment": os.getenv("APP_ENV", "local"),
            "message": "service is healthy",
        }

    finally:
        REQUESTS.labels("/api/work", status).inc()
        LATENCY.labels("/api/work").observe(time.perf_counter() - started)


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
