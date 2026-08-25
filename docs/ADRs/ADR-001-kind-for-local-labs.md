# ADR-001: kind for local Kubernetes labs

- **Status:** Accepted
- **Date:** 2026-08-24 (Week 1)
- **Deciders:** platform lab owner

## Context

The course needs a Kubernetes cluster that costs $0, can be destroyed and
rebuilt in minutes (reproducibility is a graded skill here), runs on an
Apple Silicon Mac with 16GB-class RAM, supports multi-node scheduling
behavior, and matches upstream Kubernetes closely enough that everything
learned transfers to EKS.

Options considered: kind, minikube, k3d/k3s, Docker Desktop's built-in
Kubernetes, a cheap cloud cluster (EKS).

## Decision

Use **kind** (Kubernetes-in-Docker), pinned via `kind/cluster.yaml`, with
one control-plane and one worker node.

## Rationale

- Runs upstream `kindest/node` images — real kubeadm-built Kubernetes, not a
  trimmed distribution, so API/behavior match what admission control,
  Argo CD, and Crossplane expect in later weeks.
- Cluster-as-code: the YAML config commits to Git; `make cluster-up` is the
  entire provisioning story. minikube/Docker Desktop K8s are more
  click/flag-driven.
- Multi-node out of the box, which we need to observe real scheduling
  (Week 1) and taints/affinity (Week 11).
- `kind load docker-image` gives an inner-loop without running a registry
  (a registry arrives in Week 2 anyway, via GHCR).
- CI-friendly: the same kind config runs in GitHub Actions later.

## Consequences

- No cloud load balancers/EBS/IAM — fine; AWS-specific behavior is exercised
  in short-lived AWS labs (Weeks 8 and 13).
- kind clusters are disposable by design; nothing durable may live only
  in-cluster. This is a feature: it forces GitOps discipline.
- k3s knowledge (edge/lightweight distro) is not covered; acceptable trade-off.
