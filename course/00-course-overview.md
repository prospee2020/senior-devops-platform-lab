# Senior DevOps / Platform Engineering Lab — Course Overview

**Duration:** 14 weeks · ~3h/day · 7 days/week (≈294 hours)
**Start:** Monday 2026-08-24 · **Finish:** Sunday 2026-11-29
**Output:** one production-style platform + a portfolio that proves you built it

## What this course is

You build **one evolving platform**, the same way a platform team would:
each week ships a capability on top of last week's work, with Git evidence,
real failures, real diagnoses, and honest measurements. By Week 14 the
system looks like the architecture in the root `README.md`: Backstage golden
paths → GitHub → CI with SBOM/signing/provenance → Argo CD GitOps →
Kubernetes (microservices + AI inference) → OpenTelemetry → SLOs → a guarded
AI SRE agent that proposes remediations as pull requests → FinOps cost
visibility.

What this course is **not**: disconnected tutorials, copy-paste-and-move-on,
or claims of results that were never measured.

## Daily structure (3 hours)

```text
45 min  LEARN      concepts for the day (each day's Steps 1–4)
90 min  BUILD      exact implementation + validation (Steps 5–6)
30 min  BREAK/FIX  introduce the failure, diagnose it cold (Steps 7–10)
15 min  EVIDENCE   commit, learning-log entry, done-criteria check (Steps 11–18)
```

Non-negotiables:

1. **Type the commands yourself.** The generated repo is a *reference
   implementation*. You learn by typing, mistyping, and fixing.
2. **Break/fix is done blind.** Apply the break, close the lab file,
   diagnose with `kubectl get/describe/events/logs` only, then compare.
3. **The learning log records reality.** "Docker wasn't running and I lost
   20 minutes" is a better entry than fiction about perfection.
4. **Every day ends in a commit.** No commit, day not done.

## Rules of the platform

- **Security:** the baseline in `SECURITY.md` applies from Day 4 onward.
  Labs never disable a security control to "make it work".
- **Cost:** local-first. kind + Docker cost $0. AWS appears only where the
  skill is AWS-specific (Weeks 8, 13), tagged, budgeted, and destroyed the
  same session. Never leave EKS, NAT Gateways, load balancers, GPUs, or
  databases running for study convenience.
- **Honesty:** results are labeled `syntax validated` / `configuration
  validated` / `runtime tested` / `not yet runtime tested`. Résumé bullets
  use `[measured baseline] → [measured result]` placeholders until you have
  numbers.

## Versions this course was written against (verified 2026-08-21)

| Tool | Version line | Note |
|------|--------------|------|
| Kubernetes | v1.36.x | via kind default node image; DRA has been GA since v1.34 |
| kind | v0.32.x | defaults to `kindest/node:v1.36.1` |
| Helm | 4.1.x | Helm 4 is the current major — older tutorials show Helm 3 |
| Node.js | 24 LTS | Node 26 is Current; Backstage wants LTS |
| Python | 3.13 | container base `python:3.13-slim` |
| Argo CD | 3.4.x | 3.2/3.3/3.4 are the supported lines |
| Crossplane | 2.0.x | v2 changed the XR model — ignore v1-era tutorials |
| SLSA | v1.x | verify the current spec revision at Week 7 |

**Re-verify at the start of every week** (each week's README repeats this):
check the official docs for the tools that week introduces. Version drift
between course-writing and your study date is expected; treating that drift
as a troubleshooting exercise is part of the training.

## Weekly cadence

Every week ends with: a tagged milestone (`v0.N.0`), an updated
`docs/architecture.md`, at least one break/fix entry in
`docs/failure-scenarios.md`, and the interview-prep block in the week's
README (5 technical questions, 2 architecture questions, 1 troubleshooting
scenario, 1 STAR story, 1 honest résumé bullet, 1 explain-without-notes list).

## Where to start

1. Read `01-schedule.md` (the 14-week calendar).
2. Open `week-01/README.md`.
3. Do `week-01/day-01.md`. First command: `make tools-check` (it will fail
   until the tools are installed — that failing output is your Day 1 baseline).
