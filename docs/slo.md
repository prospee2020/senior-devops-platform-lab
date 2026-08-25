# Service Level Objectives

Defined properly in Week 5. Recorded here from Day 1 so the target is known
while the platform is built toward it.

## Draft SLOs for senior-devops-api (to be measured, not asserted)

```text
Availability:  >= 99.9% of requests succeed (non-5xx), 30-day window
Latency:       95% of requests complete in < 400ms, 30-day window
```

Week 5 will define: the SLIs behind these (from Prometheus histograms), the
error budget (0.1% ≈ 43m 12s of full downtime per 30 days), burn-rate alert
thresholds, and the incident process when the budget burns.

Nothing in this file is a measured result yet.
