# Security Notes (working document)

Root policy and baseline: see `/SECURITY.md`.

This file collects week-by-week security decisions and evidence.

## Week 1

- Container runs as UID 10001, non-root enforced at three layers:
  Dockerfile `USER`, pod `runAsNonRoot`, container `allowPrivilegeEscalation: false`.
- `readOnlyRootFilesystem: true` — the app needs no writable disk
  (`PYTHONDONTWRITEBYTECODE=1` avoids .pyc writes).
- seccomp `RuntimeDefault` at pod level; all capabilities dropped.
- ConfigMap carries only non-sensitive values (`SERVICE_NAME`, `APP_ENV`).
- `.gitignore` blocks kubeconfig/credential patterns; verified before first push.
- Known gaps (accepted for now, closed later): no image scanning (Week 2),
  no signatures/SBOM (Week 6), no admission enforcement (Week 7), no
  NetworkPolicies yet.
