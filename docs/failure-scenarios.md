# Failure Scenarios Catalog

Every break/fix drill practiced in this repo, with the production-style
diagnosis. Grows weekly. Format per scenario:

```text
Symptom → Hypothesis → Evidence → Root cause → Fix → Validation → Prevention
```

## Index

| # | Scenario | Signal | Week | Manifest |
|---|----------|--------|------|----------|
| 1 | No cluster behind kubectl | `connection refused localhost:8080` | 1 | — |
| 2 | Pod deletion vs reconciliation | pod recreated with new name | 1 | — |
| 3 | Bad image tag | `ImagePullBackOff` | 1 | `k8s/breakfix/01-bad-image.yaml` |
| 4 | Broken readiness probe | Running but `0/1 READY`, empty endpoints | 1 | `k8s/breakfix/02-broken-readiness.yaml` |
| 5 | Memory limit exceeded | `OOMKilled`, exit 137, CrashLoopBackOff | 1 | `k8s/breakfix/03-oom.yaml` |

## 3. Bad image tag → ImagePullBackOff

- **Symptom:** new pods stuck `ErrImagePull` → `ImagePullBackOff`; old
  ReplicaSet pods still serving.
- **Hypothesis path:** registry down? auth? typo in tag? → check Events first.
- **Evidence:** `kubectl describe pod` Events:
  `Failed to pull image "...:this-tag-does-not-exist": not found`.
- **Root cause:** image reference points at a tag that was never built/pushed
  (or never `kind load`-ed in the local case).
- **Fix:** correct the image reference; for kind, `make app-load` then re-apply.
- **Validation:** `kubectl rollout status`; pods `1/1 READY`.
- **Prevention:** immutable Git-SHA tags produced by CI (Week 2); admission
  policy restricting registries (Week 7).

## 4. Broken readiness probe → healthy-looking outage

- **Symptom:** pod `Running` but `0/1 READY`; curls via Service hang.
- **Evidence:** `describe pod`: `Readiness probe failed: HTTP probe failed
  with statuscode: 404`; `kubectl get endpoints` → empty.
- **Root cause:** probe path `/readyz-wrong-path` does not exist; readiness
  gates Service endpoint membership, so Kubernetes correctly withheld traffic.
- **Fix:** point the probe at `/readyz`; rollout restarts pods; endpoints fill.
- **Validation:** `get endpoints` shows addresses; curl succeeds.
- **Prevention:** probe paths come from the same source of truth as the app
  (reviewed together); CI smoke test hits the probe path (Week 2).

## 5. Memory limit exceeded → OOMKilled

- **Symptom:** restarts climbing; `CrashLoopBackOff`.
- **Evidence:** `describe pod` → `Last State: Terminated, Reason: OOMKilled,
  Exit Code: 137`; `kubectl logs --previous` shows the allocation log up to
  ~the limit.
- **Root cause:** workload's real memory footprint exceeds the 64Mi limit;
  the kernel cgroup OOM killer enforces the limit — this is a contract, not
  a bug in Kubernetes.
- **Fix:** right-size the limit based on observed usage (or fix the leak).
- **Validation:** pod stable across load; restart count stops increasing.
- **Prevention:** load-test before setting limits; memory usage dashboards +
  alerts (Weeks 4–5); rightsizing review in FinOps (Week 13).
