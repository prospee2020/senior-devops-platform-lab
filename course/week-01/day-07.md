# Day 7 — Destroy & rebuild drill, documentation, v0.1.0, interview prep

## Step 1 — Problem understanding

If your platform only exists because you clicked things in order last
Tuesday, you don't have a platform — you have an accident. Today we prove
reproducibility the only honest way: destroy everything, rebuild from Git
alone, and time it. Then we finish Week 1's evidence: docs, changelog, tag.

## Step 2 — Concepts

- **Cattle, not pets:** the cluster is disposable *because* everything that
  matters lives in Git. Anything you're afraid to delete is a liability.
- **Recovery time as a metric:** MTTR starts with "how fast can I rebuild
  from nothing" — measure it now for a baseline; automation weeks will
  shrink it.
- **Tagged milestones:** `v0.1.0` marks a provable capability state; each
  course week ends in one. Tags + changelog + architecture doc = the
  portfolio trail an interviewer can actually walk.

## Step 3 — Architecture

Rebuild flow — everything on the left is Git-tracked; nothing on the right
survives:

```text
   Git repo (survives)              kind cluster (disposable)
   ├── kind/cluster.yaml   ──┐
   ├── app/ (Dockerfile…)  ──┼──>  make cluster-up
   ├── k8s/base + overlays ──┤     make app-build
   ├── Makefile, scripts/  ──┘     make app-load
   └── docs/                       make app-deploy  → identical platform
```

## Step 4 — Prerequisites

Days 1–6 committed. Nothing else — that's the point.

## Step 5 — Exact implementation

**5.1 Destroy:**

```bash
make cluster-down
kubectl config get-contexts     # kind-platform-lab GONE (kind cleans up)
docker ps                       # no node containers
```

Sit with the discomfort for a second, then:

**5.2 Rebuild from Git, timed:**

```bash
time ( make cluster-up && make app-build && make app-load && make app-deploy )
```

EXPECT: a few minutes, most of it cluster boot. Record the real number.

**5.3 Prove it's the same platform:**

```bash
kubectl -n dev get pods                       # 2/2 Running 1/1 READY
kubectl -n dev port-forward svc/senior-devops-api 8080:80 &
curl -s localhost:8080/api/work | python3 -m json.tool    # environment: dev
kill %1
./scripts/validate.sh
make app-test
```

**5.4 Documentation pass:**

- `docs/architecture.md`: confirm it matches reality (it should — you just
  rebuilt reality from it).
- `docs/failure-scenarios.md`: all five Week 1 scenarios present with YOUR
  evidence lines.
- `docs/learning-log.md`: seven entries, real failures included.
- `CHANGELOG.md`: fill the `0.1.0` date.
- `README.md` Results table: Week 1 row → shipped.

**5.5 Tag the milestone:**

```bash
git add -A
git commit -m "docs: week 1 evidence complete; rebuild drill timed"
git tag -a v0.1.0 -m "Week 1: local platform — kind cluster, hardened FastAPI, Kustomize, 3 break/fix labs"
git push && git push origin v0.1.0
gh release create v0.1.0 --title "v0.1.0 — Local platform foundation" \
  --notes "kind (K8s v1.36) + non-root FastAPI + Kustomize base/dev + break/fix labs 1-3. Rebuild-from-zero time: <your measured time>."
```

## Step 6 — Validation

```bash
git describe --tags        # v0.1.0
gh release view v0.1.0
git status                 # clean
```

## Step 7 — Break/Fix

Today's break IS the destroy. But run one bonus reflex-check: after
rebuild, is anything you needed *not* in Git? (Common catch: the
metrics-server install from Day 6 — it's gone. Was that in your rebuild
notes? Should it be a Makefile target? Decide and implement your answer.)

## Step 8 — Investigation

If any rebuild step failed, that failure is Week 1 gold: it means a
dependency lived outside Git. Find it, capture it as code, re-run the drill.

## Step 9 — Root cause

(Of any rebuild gap): implicit state — things done by hand and remembered
instead of declared. The whole course is a war on implicit state; Week 3
(GitOps) makes the cluster itself agree.

## Step 10 — Recovery

Re-run `time (...)` until the rebuild is clean end-to-end. The second run's
time is your honest baseline (first run pays image-pull taxes).

## Step 11 — Automation opportunity

Chain the rebuild as one target if you found yourself typing four commands
(e.g., a `make up` meta-target). Week 3 replaces `make app-deploy` with
Argo CD syncing from Git — the rebuild drill then becomes: cluster-up,
install Argo CD, point it at the repo, watch everything return.

## Step 12 — Security review

Confirm before tagging: `git log --all --oneline | head`, then
`git grep -iE 'password|token|secret' -- ':!docs' ':!course'` — expect only
legitimate mentions (docs, `.gitignore`). A tag is a publication event;
this check is your pre-publication gate.

## Step 13 — Reliability review

You measured recovery-from-nothing. That number is your platform's current
disaster-recovery story. Write it down; watch it improve as automation
accumulates (and cite it in interviews — measured, not vibes).

## Step 14 — Cost review

Week 1 total cloud spend: $0. Confirm honestly. This is also the FinOps
pattern in miniature: teardown as a habit, not an afterthought.

## Step 15 — GitHub evidence

The tag + release + clean tree ARE the evidence. Portfolio checklist below
is the audit.

## Step 16 — Learning log

Final Week 1 entry: rebuild time (run 1 vs run 2), any implicit-state gaps
found, and your own one-paragraph summary of the week — written for
future-you, who will have forgotten.

## Step 17 — Interview question

*"How do you know your infrastructure is reproducible?"* — Weak: "it's all
in Git." Strong: "I destroy and rebuild it on a schedule and time it; the
last drill took N minutes from empty Docker to serving traffic, and every
gap the drill ever found became a committed automation." You can now say
the strong version truthfully.

## Step 18 — Done criteria (Week 1 portfolio checklist)

- [ ] Rebuild-from-zero succeeded purely from Git; time recorded
- [ ] All Makefile targets work: tools-check, cluster-up/down, app-build/run/test/load/deploy, validate, port-forward, bf-*
- [ ] `v0.1.0` tag + GitHub release published
- [ ] 7 learning-log entries with real failures
- [ ] 5 failure scenarios documented with evidence
- [ ] ADR-001 committed; architecture.md current; CHANGELOG dated
- [ ] Security check ran clean before tagging
- [ ] Week 1 interview-prep block (week-01/README.md) answered out loud, without notes
