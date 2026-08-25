# Service Runbook — senior-devops-api

Platform-level runbook: `/RUNBOOK.md`. This file covers the lab service.

## Service facts

| | |
|-|-|
| Image | `senior-devops-api:<tag>` (local build, `kind load`-ed) |
| Port | 8000 (container) / 80 (Service) |
| Endpoints | `/healthz` (liveness), `/readyz` (readiness), `/api/work`, `/metrics` |
| Namespace | `dev` |
| Resources | req 50m/64Mi, lim 500m/256Mi |

## Quick checks

```bash
kubectl -n dev get pods -l app.kubernetes.io/name=senior-devops-api
kubectl -n dev get endpoints senior-devops-api
kubectl -n dev logs deploy/senior-devops-api --tail=50
# through port-forward (make port-forward):
curl -s localhost:8080/healthz
curl -s localhost:8080/metrics | grep app_requests_total
```

## Failure playbooks

Covered in `/RUNBOOK.md` triage table and `docs/failure-scenarios.md`.
The service can also *simulate* failures for drills:

```bash
curl "localhost:8080/api/work?delay_ms=800"   # latency injection
curl "localhost:8080/api/work?fail=true"      # HTTP 500 injection
```
