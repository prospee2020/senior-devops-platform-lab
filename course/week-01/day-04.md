# Day 4 — Deploy to Kubernetes: probes, resources, hardened securityContext · Break/fix: bad image

## Step 1 — Problem understanding

Yesterday's container becomes today's Kubernetes workload — but not a
tutorial-grade one. We deploy with the full production baseline from day
one: probes, resource requests/limits, non-root enforcement, seccomp,
dropped capabilities, read-only root filesystem, config via ConfigMap.
Then we run Break/Fix Lab 1 (bad image) as a blind drill.

## Step 2 — Concepts

- **kind image loading:** the cluster's containerd can't see your Docker
  images. `kind load docker-image` copies the image onto each node. With
  `imagePullPolicy: IfNotPresent`, no registry is needed yet. (`Always`
  would try to pull and fail — a classic kind gotcha.)
- **Probes:** readiness gates Service endpoint membership; liveness triggers
  container restarts; both are kubelet-run HTTP checks here. Wrong liveness
  = restart storms; wrong readiness = silent outage or traffic to broken pods.
- **Requests vs limits:** requests are the *scheduler's* currency (where a
  pod fits, what's guaranteed); limits are *runtime ceilings* enforced by
  cgroups — CPU is throttled, memory is OOM-killed.
- **securityContext layers:** pod-level (`runAsNonRoot`, `seccompProfile`)
  and container-level (`allowPrivilegeEscalation: false`,
  `capabilities.drop: ALL`, `readOnlyRootFilesystem`). The kubelet verifies
  `runAsNonRoot` against the image's user *at start time*.
- **ConfigMap:** non-sensitive config decoupled from the image; injected as
  env vars via `envFrom`. Secrets are a different object with different
  handling — never in ConfigMaps.

## Step 3 — Architecture

```text
 docker build → senior-devops-api:dev → kind load → containerd (both nodes)

 namespace: dev
 +--------------------------------------------------------------+
 | Deployment senior-devops-api (replicas: 1 today)             |
 |   pod securityContext: runAsNonRoot, uid 10001, seccomp      |
 |   container:                                                 |
 |     image: senior-devops-api:dev  (IfNotPresent)             |
 |     envFrom: ConfigMap senior-devops-api-config              |
 |     resources: req 50m/64Mi · lim 500m/256Mi                 |
 |     readiness /readyz · liveness /healthz                    |
 |     no-priv-esc · drop ALL caps · read-only rootfs           |
 +------------------------------|-------------------------------+
                                | selects app.kubernetes.io/name
                     Service senior-devops-api :80 → :8000
                                |
                     kubectl port-forward → localhost:8080
```

## Step 4 — Prerequisites

Cluster up (`make cluster-up` if you tore it down), image built (Day 3).
Today you type `k8s/base/deployment.yaml`, `service.yaml`, `configmap.yaml`
from the reference repo (leave `kustomization.yaml` for tomorrow).

## Step 5 — Exact implementation

**5.1 Load the image into kind:**

```bash
make app-load
# wraps: kind load docker-image senior-devops-api:dev --name platform-lab
```

EXPECT: "Image ... loaded" per node. Verify it's really there:

```bash
docker exec platform-lab-worker crictl images | grep senior-devops-api
```

**5.2 Type the manifests** (`k8s/base/*.yaml`, minus kustomization). While
typing `deployment.yaml`, say out loud what each securityContext line
prevents. If you can't, look it up now — this file is your Week 7 policy
baseline and a guaranteed interview topic.

**5.3 Deploy:**

```bash
kubectl create namespace dev
kubectl -n dev apply -f k8s/base/configmap.yaml -f k8s/base/deployment.yaml -f k8s/base/service.yaml
kubectl -n dev rollout status deployment/senior-devops-api
```

EXPECT: `deployment "senior-devops-api" successfully rolled out` within ~10s.

## Step 6 — Validation

```bash
kubectl -n dev get pods -o wide           # 1/1 Running; note the node
kubectl -n dev get endpoints senior-devops-api   # one IP:8000
kubectl -n dev describe pod -l app.kubernetes.io/name=senior-devops-api | sed -n '/Events:/,$p'
# Events: Scheduled → Pulled (already present) → Created → Started

# Traffic:
kubectl -n dev port-forward svc/senior-devops-api 8080:80 &
curl -s localhost:8080/healthz                     # {"status":"ok"}
curl -s localhost:8080/api/work | python3 -m json.tool   # environment: "base" (ConfigMap!)
curl -s localhost:8080/metrics | grep app_requests_total
kill %1

# Security claims, verified not assumed:
kubectl -n dev exec deploy/senior-devops-api -- id       # uid=10001
kubectl -n dev exec deploy/senior-devops-api -- touch /probe-readonly 2>&1
# Read-only file system  <- readOnlyRootFilesystem enforced
```

## Step 7 — Break/Fix — Lab 1: bad image (blind)

```bash
make bf-bad-image     # applies k8s/breakfix/01-bad-image.yaml
```

Also break the *real* deployment the way it happens in production — a bad
rollout:

```bash
kubectl -n dev set image deployment/senior-devops-api api=senior-devops-api:v9.9.9
```

Now close this file. Diagnose with kubectl only. Timebox 20 minutes.

## Step 8 — Investigation (compare after your attempt)

```bash
kubectl -n dev get pods
# old pod: 1/1 Running        <- still serving
# new pod: 0/1 ErrImagePull → ImagePullBackOff
kubectl -n dev describe pod <new-pod> | sed -n '/Events:/,$p'
#   Failed to pull image "senior-devops-api:v9.9.9": ... not found
kubectl -n dev get events --sort-by=.lastTimestamp | tail -10
kubectl -n dev rollout status deployment/senior-devops-api   # hangs: progress deadline
```

Key habit: **Events answer image questions.** Logs can't — there is no
container to log.

## Step 9 — Root cause

The tag `v9.9.9` exists nowhere (not built, not loaded). BackOff is
Kubernetes retrying with exponential delay. Three distinct producers of
this same symptom worth memorizing: (1) typo'd/never-built tag,
(2) private registry auth missing (imagePullSecrets), (3) right tag but
wrong registry/architecture. The Events text distinguishes them.

## Step 10 — Recovery

```bash
kubectl -n dev rollout undo deployment/senior-devops-api
kubectl -n dev rollout status deployment/senior-devops-api   # healthy
make bf-clean                                                # remove lab namespace
```

## Step 11 — Automation opportunity

Humans typed a tag; humans typo tags. Week 2: CI builds and tags images
with the Git SHA — a tag that *cannot* be wrong because the machine that
built it wrote it. Week 3: Argo CD makes manual `set image` visible drift.
Week 7: admission policy rejects unknown registries outright.

## Step 12 — Security review

Today the workload meets the full `SECURITY.md` baseline; you *verified*
uid and read-only rootfs from inside the pod. Gap you accepted: any image
that exists can still run (no signature verification until Weeks 6–7).

## Step 13 — Reliability review

The bad rollout caused **zero downtime** — old ReplicaSet kept serving
because the new pod never became Ready. This safety depends on readiness
probes being honest, which is exactly what tomorrow's break/fix subverts.

## Step 14 — Cost review

Local, $0. Requests (50m/64Mi) are what a cloud cluster would *bill you
capacity for* — over-requesting is the #1 silent Kubernetes cost problem;
Week 13 quantifies it.

## Step 15 — GitHub evidence

```bash
git add k8s/base/ k8s/breakfix/01-bad-image.yaml docs/
git commit -m "feat(k8s): hardened base manifests (probes, resources, securityContext); breakfix lab 1"
git push
```

## Step 16 — Learning log

Record your blind-diagnosis time, the exact Events line that named the
cause, and the zero-downtime observation.

## Step 17 — Interview question

*"Your deployment rollout is stuck. `get pods` shows one old pod Running
and one new pod ImagePullBackOff. Is the service down? What do you do?"* —
Not down (old pod serves). Read Events for the pull error; identify which
of the three causes; fix forward (correct tag) or `rollout undo`;
prevention: CI-generated immutable tags + registry allowlist policy.

## Step 18 — Done criteria

- [ ] App deployed with the complete security baseline; probes green
- [ ] uid 10001 + read-only rootfs verified from inside the pod
- [ ] ConfigMap value visible in `/api/work` response
- [ ] Lab 1 diagnosed blind (Events-based), recovered with rollout undo
- [ ] `make bf-clean` done; commit pushed; log updated
