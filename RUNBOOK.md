# Platform Runbook

Operational entry point for the lab platform. Service-specific runbooks live
in `docs/runbook.md` and grow as the platform grows.

## Bring the platform up from zero

```bash
make tools-check
make cluster-up
make app-build
make app-load
make app-deploy
```

Verify:

```bash
kubectl -n dev get pods            # all Running, READY 1/1
kubectl -n dev get endpoints       # senior-devops-api has addresses
make port-forward                  # then: curl localhost:8080/healthz
```

## Tear everything down

```bash
make cluster-down                  # deletes the kind cluster and ALL state
```

Cost note: local-only; teardown exists for hygiene and for proving the
platform is reproducible, not for cost. AWS teardown commands are added in
the weeks that create AWS resources.

## First-response triage (any workload)

```bash
kubectl -n <ns> get pods                              # what state?
kubectl -n <ns> describe pod <pod>                    # read Events last->first
kubectl -n <ns> get events --sort-by=.lastTimestamp   # cluster-side story
kubectl -n <ns> logs <pod> [--previous]               # app-side story
kubectl -n <ns> get endpoints <svc>                   # is traffic routable?
```

Common signatures:

| Symptom | Likely cause | Confirm with |
|---------|--------------|--------------|
| `ImagePullBackOff` | wrong tag/registry/auth | `describe pod` Events |
| Running but `0/1 READY` | readiness probe failing | `describe pod` probe messages |
| `CrashLoopBackOff` + exit 137 | OOMKilled (memory limit) | `describe pod` Last State |
| Service timeouts, pods healthy | empty endpoints / selector mismatch | `get endpoints` |
| Pending forever | unschedulable (resources/taints) | `describe pod` FailedScheduling |
