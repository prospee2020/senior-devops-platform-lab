# Day 6 — Requests & limits deep-dive, metrics under load · Break/fix: OOMKilled

## Step 1 — Problem understanding

Resource governance is where reliability, scheduling, and cost meet. Today
we understand what requests and limits *actually* do (scheduler math vs
cgroup enforcement), watch our metrics move under synthetic load, and then
run the classic memory incident: OOMKilled → CrashLoopBackOff, diagnosed
with `--previous` logs like a real 2am page.

## Step 2 — Concepts

- **Requests** feed the scheduler: a node is eligible only if unallocated
  capacity ≥ the pod's requests. They also set guaranteed minimum CPU share
  under contention.
- **Limits** are cgroup ceilings: CPU over limit → *throttled* (slow, alive);
  memory over limit → **OOM kill** (SIGKILL, exit 137). Asymmetry worth
  tattooing somewhere: CPU is compressible, memory is not.
- **QoS classes:** Guaranteed (req=lim for all resources), Burstable (ours),
  BestEffort (none set — first evicted under node pressure).
- **Exit 137** = 128 + signal 9 (SIGKILL). `describe pod` shows
  `Reason: OOMKilled` in Last State.
- **CrashLoopBackOff** is not an error itself — it's Kubernetes rate-limiting
  restarts of something that keeps dying; the cause is in the *previous*
  container's logs and Last State.
- **`kubectl logs --previous`:** logs of the last terminated container —
  the single most useful flag in crash diagnosis.

## Step 3 — Architecture

```text
             scheduler (requests: 50m CPU, 64Mi)
                 |
                 v   fits? -> bind to node
 +--------------------- worker node ----------------------+
 | kubelet + containerd                                   |
 |   cgroup for pod:                                      |
 |     cpu.max    <- limit 500m  (throttle)               |
 |     memory.max <- limit 256Mi (kernel OOM kill at 137) |
 +--------------------------------------------------------+

 load.sh -> port-forward -> Service -> pods -> /metrics counters move
```

## Step 4 — Prerequisites

Dev overlay deployed and healthy (Day 5). `scripts/load.sh` present.

## Step 5 — Exact implementation

**5.1 See allocation math on the node:**

```bash
kubectl describe node platform-lab-worker | sed -n '/Allocated resources:/,/Events:/p'
```

WHAT: totals of *requests* on the node vs capacity — this table is exactly
what the scheduler consults; note our pods' 50m/64Mi contributions.

**5.2 Generate load and watch metrics move:**

```bash
kubectl -n dev port-forward svc/senior-devops-api 8080:80 &
./scripts/load.sh 100
# EXPECT: sent=100 ok=90 err=10  (every 10th request injects fail=true)
curl -s localhost:8080/metrics | grep 'app_requests_total'
# app_requests_total{path="/api/work",status="200"} ~90
# app_requests_total{path="/api/work",status="500"} ~10
curl -s localhost:8080/metrics | grep 'app_request_duration_seconds_bucket' | head -6
kill %1
```

Caveat worth noticing: with 2 replicas, port-forward pins one pod — your
counters live on that pod only. Per-pod metrics needing aggregation is
*the* reason Prometheus exists (Week 4/5).

**5.3 Live resource usage** (kind ships without metrics-server; install the
components upstream provides):

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type json \
  -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
# ^ kind nodes use self-signed kubelet certs; this flag is a LOCAL-LAB-ONLY concession — never in prod.
sleep 30
kubectl top pods -n dev
kubectl top nodes
```

EXPECT: our pods idle around a few m CPU / ~50-60Mi — data you can now
compare against the 64Mi request. This is rightsizing evidence, Week 13's
raw material.

## Step 6 — Validation

- Metrics counters reflect load.sh's exact ok/err split.
- `kubectl top` returns numbers for pods and nodes.
- Node's Allocated resources table understood (you can point at our pods in it).

## Step 7 — Break/Fix — Lab 3: OOMKilled (blind)

```bash
make bf-oom
```

Scenario: "A batch workload in `breakfix` keeps restarting." Diagnose with
kubectl only — find *what* kills it, *at what threshold*, and *the evidence
from the dead container itself*. Timebox 20 minutes.

## Step 8 — Investigation (compare after)

```bash
kubectl -n breakfix get pods -w        # Running → OOMKilled → CrashLoopBackOff, RESTARTS climbing
kubectl -n breakfix describe pod -l scenario=oom | sed -n '/Last State:/,/Restart Count/p'
#     Last State:  Terminated
#       Reason:    OOMKilled
#       Exit Code: 137
kubectl -n breakfix logs -l scenario=oom --previous | tail -3
#   allocated 40 MiB ... (log ends mid-allocation — the kill is abrupt)
```

Note what the previous-logs show: the app printed "allocated N MiB" and
then *nothing* — no error, no stack trace. SIGKILL gives no goodbye. The
kernel, not the app, ended it; only Kubernetes metadata (Last State) tells
you why.

## Step 9 — Root cause

The container allocates ~1MiB/50ms indefinitely; the 64Mi memory limit is a
cgroup ceiling; the kernel OOM killer terminates the process when it
crosses it. Kubernetes restarts it (restartPolicy Always), it dies again,
backoff grows → CrashLoopBackOff. The limit worked *as designed* — the bug
is the mismatch between workload footprint and declared ceiling (or a leak
in the app; production requires deciding which).

## Step 10 — Recovery

Two legitimate paths — pick based on diagnosis, and say why:

1. Workload genuinely needs more: raise the limit
   (`kubectl -n breakfix patch deployment oom-demo ...` or edit the manifest) —
   here the loop allocates ~300MiB, so it needs that much or it's path 2.
2. Workload is leaking/unbounded: fix the workload; raising limits just
   delays the kill and hides the leak. (Our demo is *deliberately*
   unbounded — the honest fix is bounding the allocation, i.e., fix the app.)

```bash
make bf-clean
```

## Step 11 — Automation opportunity

- Alert on container restarts and on memory usage > 80% of limit (Week 5).
- Rightsizing from real usage data instead of folklore (Weeks 5/13);
  VPA-style recommendations are the industrial version.

## Step 12 — Security review

Limits are also a defense: an unbounded-memory pod without limits can
starve the *node* and everything on it (noisy-neighbor DoS). Resource
governance is a security control, which is why Week 7's admission policy
makes requests/limits mandatory.

## Step 13 — Reliability review

Memory limits convert "one leaking pod takes down the node" into "one pod
restarts" — blast-radius reduction by contract. But limits set too low
convert normal load into an outage; the only defensible limit is a
*measured* one. You now have `kubectl top` and histograms to measure with.

## Step 14 — Cost review

Requests are reserved capacity = money. Our pods idle at ~half their 64Mi
request — at laptop scale irrelevant, at 500-pod scale that gap is a
cluster you're paying for and not using. Write the observed idle vs request
numbers in today's log; Week 13 turns this exact arithmetic into
cost-per-service.

## Step 15 — GitHub evidence

```bash
git add k8s/breakfix/03-oom.yaml docs/
git commit -m "docs: resource governance evidence + OOMKilled drill (lab 3)"
git push
```

## Step 16 — Learning log

Must include: exit code 137 decomposition, the truncated previous-logs
observation, your `kubectl top` numbers vs requests, and which recovery
path you argued for and why.

## Step 17 — Interview question

*"A pod is in CrashLoopBackOff. Give me your first three commands and what
each rules in or out."* — `kubectl describe pod` (Last State/Reason: OOM?
error exit? probe kills?), `kubectl logs --previous` (app's dying words, if
any), `kubectl get events` (scheduling/volume/config context). Bonus:
exit 137 vs exit 1 vs liveness-kill distinctions.

## Step 18 — Done criteria

- [ ] Requests-vs-limits mechanics explained (scheduler vs cgroup) in your own words
- [ ] Load generated; counters matched sent/ok/err arithmetic
- [ ] metrics-server installed; `kubectl top` data recorded vs requests
- [ ] Lab 3 diagnosed blind: OOMKilled + 137 + previous-logs evidence
- [ ] Recovery path chosen and justified; `make bf-clean` done
- [ ] Commit pushed; log updated
