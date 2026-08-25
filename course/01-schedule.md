# 14-Week Schedule (2026-08-24 → 2026-11-29)

3 h/day, 7 days/week. Each week = 7 daily labs; Day 7 is always
consolidation + teardown/rebuild drill + tag + interview prep.

| Wk | Dates | Theme | Ships | Tag |
|----|-------|-------|-------|-----|
| 1 | Aug 24 – Aug 30 | Foundation & local platform | Workstation, repo, kind cluster, secured FastAPI on K8s, Kustomize base+dev, 3 break/fix labs | `v0.1.0` |
| 2 | Aug 31 – Sep 6 | CI/CD + Helm | GitHub Actions (lint/test/build/scan), Git-SHA image tags, GHCR, Helm chart + values-{dev,staging,prod}, Helm-vs-Kustomize ADR | `v0.2.0` |
| 3 | Sep 7 – Sep 13 | Argo CD + GitOps | Argo CD install, Applications + app-of-apps, dev/staging/prod, drift lab, rollback, gated prod promotion | `v0.3.0` |
| 4 | Sep 14 – Sep 20 | OpenTelemetry | Collector (receiver→processor→exporter), OTLP from the app, second service for distributed traces, metrics/logs/traces flowing | `v0.4.0` |
| 5 | Sep 21 – Sep 27 | SRE | SLIs/SLOs, error budget, burn-rate alerts, Grafana dashboards, injected incidents (latency, 5xx, dependency, resource), first real postmortem | `v0.5.0` |
| 6 | Sep 28 – Oct 4 | Supply-chain security | Syft SBOM (CycloneDX), Trivy/Grype gates, Cosign keyless signing via GitHub OIDC, verification | `v0.6.0` |
| 7 | Oct 5 – Oct 11 | SLSA + admission | Provenance/attestations, Kyverno policies (registries, non-root, resources, verification), rejected-workload proof | `v0.7.0` |
| 8 | Oct 12 – Oct 18 | Crossplane | XRD/XR/Compositions, `platform.example.io` App API, GitOps-driven, short-lived AWS managed-resource demo (created→validated→destroyed) | `v0.8.0` |
| 9 | Oct 19 – Oct 25 | Backstage | IDP running locally, software catalog, catalog-info.yaml for all services, TechDocs, ownership | `v0.9.0` |
| 10 | Oct 26 – Nov 1 | Golden path | "Production Service" scaffolder template: repo+CI+K8s+Argo+OTel+security defaults; measured manual-vs-golden-path onboarding time | `v0.10.0` |
| 11 | Nov 2 – Nov 8 | Kubernetes AI | CPU-friendly mock inference service, inference metrics (RPS, latency, tokens/s, queue depth), HPA + KEDA, load tests (p50/p95/p99), GPU/DRA concepts (DeviceClass, ResourceClaim) | `v0.11.0` |
| 12 | Nov 9 – Nov 15 | AI SRE | Guarded agent: alert→read-only collectors→structured evidence→ranked hypotheses→remediation→human approval→PR; incident fixtures; measured accuracy/cost | `v0.12.0` |
| 13 | Nov 16 – Nov 22 | FinOps | OpenCost concepts, cost_per_request / cost_per_inference / cost_per_1m_tokens scripts (assumptions labeled), AWS optimization review, short-lived cost-visibility lab | `v0.13.0` |
| 14 | Nov 23 – Nov 29 | Capstone | End-to-end integration + 8 game days (bad deploy, OOM, readiness, unsigned artifact, policy violation, AI overload, latency, cost spike), portfolio polish | `v1.0.0` |

## Week 1 day map

| Day | Date | Lab |
|-----|------|-----|
| 1 | Mon Aug 24 | Workstation + Git/GitHub + tools-check |
| 2 | Tue Aug 25 | kind cluster, kubeconfig/contexts, nginx, core objects, reconciliation |
| 3 | Wed Aug 26 | FastAPI service + non-root Docker image |
| 4 | Thu Aug 27 | Deploy to Kubernetes: probes, resources, hardened securityContext · Break/fix: bad image |
| 5 | Fri Aug 28 | Kustomize base + dev overlay · Break/fix: broken readiness |
| 6 | Sat Aug 29 | Requests/limits deep-dive, metrics + load · Break/fix: OOMKilled |
| 7 | Sun Aug 30 | Destroy & rebuild drill, docs, `v0.1.0`, interview prep |

Later weeks get their day map in their own `week-NN/README.md` when that
week starts (keeping day plans current with the versions you actually meet).

## Slippage policy

Life happens. If a day slips: do NOT compress break/fix or evidence time —
drop scope instead (move a stretch item to Day 7). If a whole week slips,
shift the calendar; never skip the teardown/rebuild drills, they are the
spaced repetition that makes this stick.
