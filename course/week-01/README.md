# Week 1 — Foundation & Local Platform

**Goal:** a reproducible workstation, a Git-disciplined repository, a kind
Kubernetes cluster, and a security-hardened FastAPI service deployed via
Kustomize — plus three break/fix drills diagnosed like production incidents.

**Version check (do this before Day 1):** confirm on the official sites that
the current lines still match the course assumptions — kind (~v0.32,
K8s v1.36 node image), Helm 4.x, Node 24 LTS, Python 3.13. If something
moved, note the difference in your learning log and proceed with the
current release.

## Days

| Day | Lab | Break/Fix |
|-----|-----|-----------|
| 1 | [Workstation, Git, GitHub, tools-check](day-01.md) | kubectl with no cluster |
| 2 | [kind cluster, contexts, nginx, core objects](day-02.md) | reconciliation + bad nginx tag |
| 3 | [FastAPI service + non-root image](day-03.md) | daemon down, port mismatch |
| 4 | [Deploy to K8s with hardened manifests](day-04.md) | **Lab 1: bad image** |
| 5 | [Kustomize base + dev overlay](day-05.md) | **Lab 2: broken readiness** |
| 6 | [Resources, metrics, load](day-06.md) | **Lab 3: OOMKilled** |
| 7 | [Teardown/rebuild drill + v0.1.0](day-07.md) | rebuild from nothing, timed |

## End-of-week interview prep

### Five technical questions

1. A pod shows `ImagePullBackOff`. Walk me through your diagnosis, and name
   three distinct root causes that produce this exact symptom.
2. What is the difference between a readiness probe and a liveness probe,
   and what specifically goes wrong if you point a liveness probe at a
   dependency-checking endpoint?
3. Explain what happens between `kubectl apply -f deployment.yaml` and a
   running container — name every control-plane component involved and its role.
4. Why do we set both resource requests and limits? What does each one
   actually control, and which one can get your process SIGKILLed?
5. Your container runs fine locally but Kubernetes kills it with exit code
   137. What happened and how do you confirm it in one command?

### Two architecture questions

1. Defend running this lab on kind instead of a small EKS cluster. Where
   does that decision stop being valid? (Your answer is ADR-001.)
2. Why does the dev overlay patch the base instead of maintaining a full
   copy of the manifests per environment? What failure mode does
   copy-per-environment create at 10 services × 4 environments?

### One troubleshooting scenario

Users report the service is down. `kubectl get pods` shows all pods
`Running`. Walk through it. (Expected path: Running ≠ Ready → check READY
column → describe pod → readiness probe failing → `get endpoints` empty →
probe path vs app route mismatch → fix, validate, then propose prevention.)

### One STAR story (fill with YOUR numbers from the log)

- **S:** During my platform lab I deployed a workload where the pods showed
  Running but the service was returning timeouts.
- **T:** Restore service and explain the outage mechanism, using only
  cluster-side evidence.
- **A:** I checked the READY column rather than trusting STATUS, used
  `kubectl describe` to read probe failures (HTTP 404 on the readiness
  path), confirmed the Service had zero endpoints, fixed the probe path,
  and watched endpoints repopulate.
- **R:** Service restored in [your measured time]; documented in a
  postmortem-style log entry; prevention: probe paths reviewed with app
  routes in the same PR.

### One honest résumé bullet

> Built a security-hardened Kubernetes deployment pipeline on a local
> multi-node cluster (kind, Kubernetes v1.36): non-root containers, seccomp,
> capability dropping, resource governance, health probes, and Kustomize
> overlays — with documented break/fix drills for image, probe, and OOM
> failures.

(No performance numbers in Week 1 — nothing was measured yet.)

### Explain-without-notes list

Image vs container · Pod vs Deployment · Deployment vs Service · ConfigMap
vs Secret · request vs limit · readiness vs liveness · kubeconfig vs
context · Kustomize base vs overlay · ImagePullBackOff · Kubernetes
reconciliation · non-root containers · reproducible environments
