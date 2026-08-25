# Break/Fix Scenarios — Week 1

Deliberately broken manifests. Each file's header comment contains the apply
command, the expected symptoms, the investigation commands, and cleanup.

| # | File | Failure | Core lesson |
|---|------|---------|-------------|
| 1 | `01-bad-image.yaml` | `ImagePullBackOff` | Read pod **Events**; rolling updates protect old pods |
| 2 | `02-broken-readiness.yaml` | Running but `READY 0/1` | Readiness gates Service **endpoints**; "Running" ≠ "serving" |
| 3 | `03-oom.yaml` | `OOMKilled` / exit 137 | Limits are enforced by the kernel; use `logs --previous` |

Rules of engagement:

1. Apply the break. **Do not read the fix first.**
2. Diagnose using only `kubectl get / describe / events / logs [--previous]`.
3. Write Symptom → Hypothesis → Evidence → Root cause → Fix → Validation → Prevention
   in `docs/learning-log.md` **before** cleaning up.
4. `kubectl delete ns breakfix` to reset.
