# Day 2 — kind cluster, kubeconfig & contexts, nginx, core objects, reconciliation

## Step 1 — Problem understanding

Yesterday kubectl had nothing to talk to. Today we create a real multi-node
Kubernetes cluster on the laptop, deploy nginx as a known-good workload, and
learn the object model (Pod → ReplicaSet → Deployment → Service) plus the
idea that makes Kubernetes what it is: **reconciliation**.

## Step 2 — Concepts

- **kind** runs each Kubernetes *node* as a Docker container; inside each
  node-container, containerd runs the pods. Cluster-in-Docker.
- **kubeconfig** holds three lists — clusters, users, contexts. A **context**
  is a named (cluster, user, default-namespace) triple; `current-context` is
  the one kubectl uses. Multi-cluster accidents ("I deleted from prod") are
  context accidents.
- **Namespaces** partition one cluster logically (dev/staging/prod teams,
  quotas, RBAC scopes). Not a security boundary by themselves.
- **Object model:** you declare a *Deployment* (desired state); it manages a
  *ReplicaSet* (identical-pod count for one template revision); the
  ReplicaSet manages *Pods* (the schedulable unit). A *Service* gives a
  stable virtual IP + DNS name selecting pods by label.
- **Reconciliation:** controllers run a loop — observe actual state, compare
  to desired state, act to converge. You never "start a container" on
  Kubernetes; you change desired state and the system converges. This is
  also the foundation GitOps builds on in Week 3.

## Step 3 — Architecture

```text
 Docker Desktop VM
 +-----------------------------------------------------------+
 | kind "platform-lab"                                       |
 |  +--------------------+     +---------------------------+ |
 |  | control-plane node |     | worker node               | |
 |  |  kube-apiserver <--+-----+--- kubelet                | |
 |  |  etcd              |     |   containerd              | |
 |  |  kube-scheduler    |     |    └── nginx pod(s)       | |
 |  |  controller-mgr    |     |                           | |
 |  +--------------------+     +---------------------------+ |
 +-----------|-----------------------------------------------+
             | https (API)
       kubectl (context: kind-platform-lab)
```

## Step 4 — Prerequisites

Day 1 complete; Docker Desktop running; repo contains `kind/cluster.yaml`
and the `Makefile`.

## Step 5 — Exact implementation

**5.1 Create the cluster:**

```bash
make cluster-up
# wraps: kind create cluster --config kind/cluster.yaml
```

WHAT: pulls the `kindest/node` image (~1GB, first time only), boots two
node containers, runs kubeadm inside them, writes kubeconfig context
`kind-platform-lab` and switches to it.
EXPECT: "You can now use your cluster with: kubectl cluster-info ..." then
the cluster-info output from the Makefile.
COULD FAIL: Docker not running (start it); low VM memory (Docker Desktop →
Settings → Resources, give it ≥6GB).

**5.2 Inspect what you got:**

```bash
docker ps                                   # 2 containers = your "nodes"
kubectl config current-context              # kind-platform-lab
kubectl get nodes -o wide                   # both Ready, VERSION v1.36.x
kubectl get pods -A                         # system pods: which node runs what?
kubectl get namespaces
```

Note how the control-plane components (`kube-apiserver-...`, `etcd-...`)
are themselves pods in `kube-system` — Kubernetes runs on Kubernetes.

**5.3 Deploy nginx into its own namespace:**

```bash
kubectl create namespace web
kubectl -n web create deployment nginx --image=nginx:1.29 --replicas=2
kubectl -n web expose deployment nginx --port=80
```

WHY imperative commands today (and only today): to feel what the YAML
generates. From Day 4 on, everything is declarative files in Git.

**5.4 Read the object chain:**

```bash
kubectl -n web get deploy,rs,pods,svc,endpoints
kubectl -n web describe deployment nginx | head -30
kubectl -n web describe pod -l app=nginx | sed -n '/Events:/,$p'
kubectl -n web logs deploy/nginx --tail=5
```

Trace it: Deployment `nginx` → ReplicaSet `nginx-<hash>` → Pods
`nginx-<hash>-<rand>` → Service selects them → Endpoints lists their IPs.

**5.5 Touch the service:**

```bash
kubectl -n web port-forward svc/nginx 8080:80 &
curl -s localhost:8080 | head -4        # nginx welcome HTML
kill %1
```

## Step 6 — Validation

```bash
kubectl get nodes                 # 2 Ready
kubectl -n web get pods           # 2/2 Running, READY 1/1
kubectl -n web get endpoints nginx  # two IP:80 pairs  <- service is routable
```

If endpoints are empty while pods run, you've met tomorrow's lesson early:
selector or readiness mismatch.

## Step 7 — Break/Fix (two drills)

**Drill A — fight the reconciler:**

```bash
kubectl -n web get pods                       # note the pod names
kubectl -n web delete pod -l app=nginx --wait=false
kubectl -n web get pods -w                    # watch; Ctrl-C when stable
```

**Drill B — bad image tag:**

```bash
kubectl -n web set image deployment/nginx nginx=nginx:1.29-doesnotexist
kubectl -n web get pods
```

## Step 8 — Investigation

Drill A: pods die, but **new pods with new names appear within seconds**.
You deleted actual state; desired state (replicas: 2) never changed; the
ReplicaSet controller reconciled. Killing pods is not how you stop things —
`kubectl scale --replicas=0` or deleting the Deployment is.

Drill B:

```bash
kubectl -n web get pods
# NAME          READY  STATUS             ...
# nginx-new...  0/1    ErrImagePull / ImagePullBackOff
# nginx-old...  1/1    Running            <- still serving!
kubectl -n web describe pod -l app=nginx | sed -n '/Events:/,$p'
# Failed to pull image "nginx:1.29-doesnotexist": ... not found
kubectl -n web rollout status deployment/nginx   # stuck, waiting
```

## Step 9 — Root cause

Drill A: reconciliation — controllers converge actual toward desired state;
manual pod deletion is just an "actual state" disturbance to repair.
Drill B: the tag doesn't exist in the registry. Note the reliability
architecture: the rolling update strategy kept the old ReplicaSet serving
because the new pods never became ready. A bad image is an availability
non-event *if* probes and rollout strategy are right — that's why we
configure them tomorrow onward.

## Step 10 — Recovery

```bash
kubectl -n web rollout undo deployment/nginx
kubectl -n web rollout status deployment/nginx    # back to healthy
kubectl -n web rollout history deployment/nginx   # revisions recorded
```

`rollout undo` re-points the Deployment at the previous ReplicaSet — this
exact mechanism is what Argo CD drives declaratively in Week 3.

## Step 11 — Automation opportunity

Cluster creation is already `make cluster-up` (config in Git). Later:
CI spins the same cluster (Week 2); Argo CD owns deployments so `set image`
by hand becomes forbidden drift (Week 3).

## Step 12 — Security review

- kind's kubeconfig credentials are client certs for a local cluster —
  still: never commit them (`.gitignore` covers it).
- `nginx:1.29` official image runs as root by default — acceptable for a
  10-minute demo namespace, exactly what our own app will NOT do from Day 3.
- Namespaces used from the start; cluster-admin-everything habits die today.

## Step 13 — Reliability review

Reconciliation + rolling updates turned a bad deploy into zero downtime.
Note what saved you: the *old* pods stayed until new ones were Ready.
Anything that makes "Ready" lie (tomorrow's probes) breaks this safety net.

## Step 14 — Cost review

Local, $0. The mental model transfers: a managed EKS control plane bills
~$0.10/hour before any nodes — one more reason labs run on kind.

## Step 15 — GitHub evidence

```bash
git add kind/cluster.yaml docs/learning-log.md docs/failure-scenarios.md
git commit -m "feat: kind cluster config; document reconciliation and bad-image drills"
git push
```

(The nginx namespace is throwaway practice — deliberately not in Git.
Clean it: `kubectl delete ns web`.)

## Step 16 — Learning log

Record both drills with the Symptom→…→Prevention structure. Include the
actual Event lines you read, not paraphrases.

## Step 17 — Interview question

*"What happens, component by component, between `kubectl create deployment`
and a running container?"* — apiserver validates+persists to etcd →
deployment controller creates ReplicaSet → RS controller creates Pod
objects → scheduler binds pods to nodes → kubelet on each node sees its
binding, tells containerd to pull/run → kubelet reports status back.
Bonus: name where it stalls for a bad image (kubelet pull) vs no resources
(scheduler).

## Step 18 — Done criteria

- [ ] 2-node cluster up via `make cluster-up`; both nodes Ready
- [ ] nginx: Deployment→RS→Pod→Service→Endpoints chain traced and explained
- [ ] Reconciliation drill observed (pod resurrection)
- [ ] Bad-image drill: diagnosed from Events, recovered with `rollout undo`
- [ ] `kubectl delete ns web` cleanup done
- [ ] Learning log updated; commit pushed
