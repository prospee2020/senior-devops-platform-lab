# Changelog

All notable changes to the platform. Format: [Keep a Changelog](https://keepachangelog.com), versioning: milestone tags per course week.

## [Unreleased]

## [0.1.0] - TBD (end of Week 1)

### Added
- Repository skeleton for the 14-week platform lab
- FastAPI lab service (`/healthz`, `/readyz`, `/api/work`, `/metrics`) with
  simulated latency and failure injection
- Non-root Dockerfile (python:3.13-slim, UID 10001)
- kind cluster definition (1 control-plane + 1 worker, Kubernetes v1.36.x)
- Kubernetes base manifests: Deployment, Service, ConfigMap, probes,
  resource requests/limits, hardened securityContext
- Kustomize base + dev overlay (replicas, image tag, config)
- Break/fix labs: bad image, broken readiness probe, OOMKilled
- Makefile automation, tools-check and validate scripts
- Docs: architecture, learning log, failure scenarios, runbooks, ADR-001
