"""Unit tests for the lab API. Run with:  make app-test  (or: pytest app/tests)"""

import sys
from pathlib import Path

from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from main import app  # noqa: E402

client = TestClient(app)


def test_healthz():
    r = client.get("/healthz")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_readyz():
    r = client.get("/readyz")
    assert r.status_code == 200
    assert r.json() == {"ready": True}


def test_work_success():
    r = client.get("/api/work")
    assert r.status_code == 200
    body = r.json()
    assert body["service"] == "senior-devops-api"
    assert body["message"] == "service is healthy"


def test_work_simulated_failure():
    r = client.get("/api/work", params={"fail": "true"})
    assert r.status_code == 500
    assert r.json() == {"error": "simulated failure"}


def test_metrics_exposes_counters():
    client.get("/api/work")
    r = client.get("/metrics")
    assert r.status_code == 200
    assert "app_requests_total" in r.text
    assert "app_request_duration_seconds" in r.text
