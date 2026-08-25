# Day 5 — Kustomize base + dev overlay · Break/fix: broken readiness probe

## Step 1 — Problem understanding

Yesterday's manifests are one environment. Real platforms run dev, staging,
prod — same app, different replicas/tags/config. Copy-pasting manifests per
environment rots instantly (fix a probe in dev, forget prod). Kustomize
solves this with a **base** (the truth) and **overlays** (patches per
environment). Then Break/Fix Lab 2 delivers Week 1's most important
operational lesson: *Running does not mean serving.*

## Step 2 — Concepts

- **Kustomize model:** no templates, no values language — plain YAML plus a
  `kustomization.yaml` that lists resources and transformations (namespace,
  labels, replicas, images, patches). Built into kubectl (`kubectl apply -k`).
- **Base:** environment-agnostic, complete, deployable truth.
- **Overlay:** references the base, changes *only* what differs. Ours
  changes exactly the canonical three: replicas (2), image tag, ConfigMap
  value (`APP_ENV: dev`), plus namespace.
- **Strategic merge patch:** the overlay's `patch-configmap.yaml` is a
  partial object; Kustomize merges it by kind+name onto the base object.
- **vs Helm (preview of Week 2's ADR):** Kustomize customizes *your own*
  environments; Helm packages/distributes parameterized charts. Mature
  platforms commonly use both: Helm for third-party software, Kustomize for
  first-party config. We adopt exactly that split.

## Step 3 — Architecture

```text
 k8s/base/                       k8s/overlays/dev/
 ├── deployment.yaml             ├── kustomization.yaml
 ├── service.yaml        <------ │    namespace: dev
 ├── configmap.yaml     resources│    replicas: 2
 └── kustomization.yaml          │    images: newTag
                                 └── patch-configmap.yaml (APP_ENV: dev)

        kubectl apply -k k8s/overlays/dev
                        |
                        v
        rendered manifests → API server → reconciliation
```

## Step 4 — Prerequisites

Day 4 deployed and healthy. Today you type `k8s/base/kustomization.yaml`,
`k8s/overlays/dev/kustomization.yaml`, and
`k8s/overlays/dev/patch-configmap.yaml`.

## Step 5 — Exact implementation

**5.1 Render before applying — always:**

```bash
kubectl kustomize k8s/base | head -40
kubectl kustomize k8s/overlays/dev > /tmp/dev.yaml
diff <(kubectl kustomize k8s/base) /tmp/dev.yaml
```

WHAT: `kustomize` renders without touching the cluster. The diff IS the
overlay: namespace added, replicas 1→2, APP_ENV base→dev, labels merged.
Reading rendered diffs before apply is the habit that Argo CD later
automates as its diff view.

**5.2 Apply the overlay:**

```bash
make app-deploy
# wraps: create ns if missing; kubectl apply -k k8s/overlays/dev; rollout status
```

EXPECT: `unchanged` lines for what Day 4 already created (only if names/ns
match), `configured` where the overlay differs, then rollout success with 2
replicas.

**5.3 Verify the three overlay changes landed:**

```bash
kubectl -n dev get deploy senior-devops-api -o jsonpath='{.spec.replicas}{"\n"}'   # 2
kubectl -n dev get cm senior-devops-api-config -o jsonpath='{.data.APP_ENV}{"\n"}' # dev
kubectl -n dev get deploy senior-devops-api -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n dev port-forward svc/senior-devops-api 8080:80 &
curl -s localhost:8080/api/work | python3 -m json.tool    # "environment": "dev"
kill %1
```

Note: changing a ConfigMap does not restart pods by itself. If
`environment` still says `base`, run
`kubectl -n dev rollout restart deploy/senior-devops-api` — and remember
this gotcha; Kustomize's `configMapGenerator` (name-hashing) is the clean
fix, which you can explore as a stretch goal.

## Step 6 — Validation

```bash
./scripts/validate.sh     # includes kustomize builds of base + dev
kubectl -n dev get pods   # 2/2 Running, READY 1/1
```

## Step 7 — Break/Fix — Lab 2: broken readiness (blind)

```bash
make bf-broken-readiness    # needs the image kind-loaded (Day 4 did it)
```

Scenario (don't peek at the manifest): "Monitoring says the new service in
namespace `breakfix` times out, but the dashboard shows its pod Running."
Diagnose with kubectl only. Timebox 20 minutes.

## Step 8 — Investigation (compare after)

```bash
kubectl -n breakfix get pods
# NAME                 READY   STATUS    RESTARTS
# broken-readiness-…   0/1     Running   0          <- Running BUT 0/1
kubectl -n breakfix describe pod -l scenario=broken-readiness | sed -n '/Events:/,$p'
#   Warning  Unhealthy ... Readiness probe failed: HTTP probe failed with statuscode: 404
kubectl -n breakfix get endpoints broken-readiness
# ENDPOINTS: <none>        <- the outage, explained in one line
```

The pod is healthy; the *probe definition* asks for `/readyz-wrong-path`,
the app serves `/readyz`, kubelet gets 404, pod never becomes Ready,
Service never gets endpoints, every consumer times out.

## Step 9 — Root cause

Configuration contract violation between probe path and app routes.
Kubernetes did its job *correctly* — it refused to route traffic to a pod
that never declared itself ready. The deeper lesson: `STATUS Running`
answers "is the process up", `READY` answers "is it serving". Dashboards
that only show STATUS lie.

## Step 10 — Recovery

```bash
kubectl -n breakfix patch deployment broken-readiness --type json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/readyz"}]'
kubectl -n breakfix rollout status deployment/broken-readiness
kubectl -n breakfix get endpoints broken-readiness   # address appears
make bf-clean
```

## Step 11 — Automation opportunity

- CI smoke test curls the real probe paths of the built image (Week 2), so
  a path drift fails the pipeline, not production.
- Week 5 alerts on `kube_deployment_status_replicas_available <
  spec_replicas` — detecting "green but not serving" in minutes, not via
  user reports.

## Step 12 — Security review

Overlays are also where env-specific security posture will live (e.g.,
prod-only NetworkPolicies later). Note that base stays deployable and
hardened — an overlay must never *weaken* base security to make dev easy;
that's how dev-grade posture leaks to prod.

## Step 13 — Reliability review

Readiness is the load-balancer contract. Two replicas now also means a
rolling update takes pods out one at a time with traffic continuity —
observe it: `kubectl -n dev rollout restart deploy/senior-devops-api`
while curling in a loop.

## Step 14 — Cost review

Local, $0. Replicas 1→2 doubled the *requested* footprint — in the cloud
that's real money reserved whether used or not. Environment-appropriate
replica counts (dev:2, prod:3+) are a cost decision as much as a
reliability one.

## Step 15 — GitHub evidence

```bash
git add k8s/ docs/
git commit -m "feat(k8s): kustomize base + dev overlay (replicas, tag, config); breakfix lab 2"
git push
```

## Step 16 — Learning log

Record: the rendered diff you read in 5.1, your blind-diagnosis path for
Lab 2 (did you check endpoints before or after describe?), and the
ConfigMap-doesn't-restart-pods gotcha if you hit it.

## Step 17 — Interview question

*"Helm or Kustomize?"* — Wrong answer: picking one absolutely. Strong
answer: they solve different problems (packaging/templating vs
environment-patching); common pattern is Helm for third-party dependencies,
Kustomize for your own services; and the decision belongs in an ADR with
the team's context. (You'll write ADR-004 in Week 2 with hands-on evidence
for both.)

## Step 18 — Done criteria

- [ ] Base + dev overlay typed; rendered diff read and understood
- [ ] Overlay proves the three changes (replicas/tag/config) without touching base
- [ ] `environment: "dev"` confirmed via the API response
- [ ] Lab 2 diagnosed blind; endpoints-empty evidence captured; fixed via patch
- [ ] `scripts/validate.sh` green; commit pushed; log updated
