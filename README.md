# Senior DevOps Platform Lab

One evolving, production-style platform built over 14 weeks — not a pile of
disconnected tutorials. Every week adds a layer to the same system, ending in
an Internal Developer Platform with GitOps delivery, a signed supply chain,
full observability, SLO-driven reliability, AI workload operations, a guarded
AI SRE agent, and FinOps cost visibility.

## Results

> This section is filled with **measured** results only, as the course
> progresses. No fabricated numbers.

| Milestone | Tag | Status |
|-----------|-----|--------|
| Local platform: kind + secured FastAPI + Kustomize | `v0.1.0` | in progress |
| CI/CD + Helm | `v0.2.0` | pending |
| GitOps (Argo CD) | `v0.3.0` | pending |
| Observability (OpenTelemetry) | `v0.4.0` | pending |
| SRE: SLOs + error budgets | `v0.5.0` | pending |
| Supply chain: SBOM + signing | `v0.6.0` | pending |
| SLSA + admission policy | `v0.7.0` | pending |
| Platform API (Crossplane) | `v0.8.0` | pending |
| IDP (Backstage) | `v0.9.0` | pending |
| Golden path template | `v0.10.0` | pending |
| AI workloads on Kubernetes | `v0.11.0` | pending |
| Guarded AI SRE agent | `v0.12.0` | pending |
| FinOps | `v0.13.0` | pending |
| Capstone + game days | `v1.0.0` | pending |

## Architecture (target state)

```text
                           Developers
                               |
                               v
                         +-----------+
                         | Backstage |
                         |    IDP    |
                         +-----+-----+
                               |
                         Golden Paths
                               |
                +--------------+---------------+
                |                              |
                v                              v
          GitHub Repository              Crossplane API
                |                              |
                v                              v
        GitHub Actions                    Cloud Resources
                |
      +---------+---------+
      | Testing | SBOM    |
      | Security| Signing |
      +---------+---------+
                |
                v
             Registry
                |
                v
             Argo CD
                |
                v
             Kubernetes
           /            \
   Microservices     AI Inference
           \            /
                |
                v
          OpenTelemetry
                |
        Metrics  Traces  Logs
                |
                v
             Grafana
                |
                v
          AI SRE Agent  ->  root-cause  ->  remediation PR (human-approved)

  FinOps: AWS cost | Kubernetes cost | cost/request | cost/inference | cost/token
```

Current state (Week 1): see `docs/architecture.md`.

## Problem

Teams ship faster and more safely when infrastructure is a product: paved
roads instead of tickets, GitOps instead of kubectl-by-hand, provable
artifacts instead of trust, SLOs instead of vibes. This repo demonstrates
that platform end to end at lab scale — including operating AI workloads and
using AI safely inside the operations loop.

## Technology

Kubernetes (kind, v1.36.x) · Docker · Kustomize · Helm 4 · GitHub Actions ·
Argo CD 3.4 · OpenTelemetry · Prometheus · Grafana · Syft/Trivy/Grype ·
Cosign/Sigstore · SLSA · Kyverno · Crossplane 2 · Backstage · vLLM/KServe
(concepts) · KEDA · OpenCost concepts · AWS (short-lived labs only)

## Security · Reliability · Observability · Cost

- **Security:** non-root containers, seccomp `RuntimeDefault`, dropped
  capabilities, no privilege escalation, no secrets in ConfigMaps; from Week 6:
  SBOMs, scanning, keyless signing, admission enforcement. See `SECURITY.md`.
- **Reliability:** probes, resource governance, reconciliation-driven
  operations; from Week 5: SLOs, error budgets, burn-rate alerts, postmortems
  (`docs/slo.md`, `docs/postmortems/`).
- **Observability:** Prometheus metrics from day one; OpenTelemetry
  metrics/traces/logs from Week 4.
- **Cost:** everything possible runs locally at $0; AWS resources are tagged,
  budgeted, and destroyed immediately after validation. See `finops/`.

## Deployment & Testing

```bash
make tools-check   # verify workstation
make cluster-up    # kind cluster (1 control-plane + 1 worker)
make app-build && make app-load && make app-deploy
make validate      # static validation (same checks CI will run)
make app-test      # unit tests
```

## Failure scenarios

Practiced break/fix labs with real diagnoses: `docs/failure-scenarios.md`
and `k8s/breakfix/`.

## Lessons learned

Running log with real (not sanitized) failures: `docs/learning-log.md`.

## Course

The full 14-week curriculum lives in `course/`. Start at
`course/00-course-overview.md`.
