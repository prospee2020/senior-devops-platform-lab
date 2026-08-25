# Architecture

This document always reflects the **current** state of the platform. The
target end-state lives in the root `README.md`. Update this file every week.

## Current state — Week 1: Local platform foundation

```text
 macOS workstation (Apple Silicon)
 ------------------------------------------------------------
 |                                                          |
 |  Docker Desktop                                          |
 |  +----------------------------------------------------+  |
 |  | kind cluster "platform-lab"  (Kubernetes v1.36.x)  |  |
 |  |                                                    |  |
 |  |  +----------------+   +------------------------+   |  |
 |  |  | control-plane  |   | worker                 |   |  |
 |  |  |  api-server    |   |  +------------------+  |   |  |
 |  |  |  etcd          |   |  | ns: dev          |  |   |  |
 |  |  |  scheduler     |   |  |  Deployment (x2) |  |   |  |
 |  |  |  controllers   |   |  |  senior-devops-  |  |   |  |
 |  |  +----------------+   |  |  api  :8000      |  |   |  |
 |  |                       |  |    ^             |  |   |  |
 |  |                       |  |    | Service :80 |  |   |  |
 |  |                       |  +------------------+  |   |  |
 |  |                       +------------------------+   |  |
 |  +----------------------------------------------------+  |
 |         ^                          ^                     |
 |         | kind load docker-image   | kubectl (kubeconfig |
 |         |                          |  context kind-platform-lab)
 |  docker build              kubectl port-forward :8080    |
 ------------------------------------------------------------
```

## Components

| Component | Role | Introduced |
|-----------|------|------------|
| FastAPI service (`app/`) | The workload everything else operates on | Week 1 |
| kind cluster (`kind/cluster.yaml`) | Local Kubernetes, destroyed/rebuilt freely | Week 1 |
| Kustomize base + overlays (`k8s/`) | Environment configuration without duplication | Week 1 |
| Break/fix manifests (`k8s/breakfix/`) | Reproducible failure drills | Week 1 |
| Makefile + scripts | One-command repeatability | Week 1 |

## Key decisions

See `docs/ADRs/`. Currently: ADR-001 (why kind for local labs).

## Data flows (Week 1)

1. **Build:** `docker build` → local image `senior-devops-api:dev` →
   `kind load docker-image` → containerd on both kind nodes.
2. **Deploy:** `kubectl apply -k k8s/overlays/dev` → API server → etcd →
   controllers create ReplicaSet → scheduler places pods → kubelet runs them.
3. **Traffic:** `kubectl port-forward svc/senior-devops-api 8080:80` →
   Service → ready endpoints only.
