# Security Policy & Baseline

## Reporting

This is a learning lab. If you find a real security issue in it, open a
GitHub issue or contact the repository owner.

## Workload security baseline (enforced from Week 1)

Every workload in this repository must run with:

```yaml
# container level
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]

# pod level
securityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault
```

plus CPU/memory requests **and** limits, readiness and liveness probes, and
images built from non-root Dockerfiles.

## Rules

1. **No secrets in Git. Ever.** Not in ConfigMaps, not in values files, not
   in "temporary" commits. `.gitignore` blocks common credential patterns,
   but the control is behavior, not the ignore file.
2. **No `latest` tags** past Week 1's first build; images are addressed by
   immutable tags (Git SHA) from Week 2 and by digest/signature from Week 6.
3. **Break/fix labs never weaken security to "make things work".** If a
   security control blocks something, the lab explains the control instead
   of disabling it.

## Roadmap of controls added by the course

| Week | Control |
|------|---------|
| 1 | Non-root, seccomp, dropped caps, resource limits, probes |
| 2 | CI vulnerability scanning (Trivy) |
| 6 | SBOM (Syft), scan gates (Trivy/Grype), keyless signing (Cosign + GitHub OIDC) |
| 7 | SLSA provenance, admission policy (Kyverno): registries, non-root, resources, verification |
| 12 | AI agent guardrails: read-only RBAC, allowlisted tools, secret filtering, human approval |
