# Day 3 — The FastAPI service and a non-root container image

## Step 1 — Problem understanding

The platform needs a workload worth operating. Today we build it: a small
FastAPI service with health endpoints, Prometheus metrics, and *built-in
failure injection* (latency + 500s). That injection is not a toy — Weeks 5
and 12 use it to burn error budgets and feed the AI SRE agent real
incidents. Then we containerize it properly: non-root, pinned, cache-aware.

## Step 2 — Concepts

- **Image vs container:** an image is an immutable layered filesystem +
  metadata; a container is a running (or stopped) instance of one with its
  own writable layer, namespaces, and cgroups. Interview staple.
- **Liveness vs readiness endpoints:** `/healthz` answers "is the process
  alive" (dependency-free!); `/readyz` answers "should I receive traffic".
  Confusing them causes restart storms (liveness checking a dependency) or
  traffic to broken pods.
- **Metrics-first:** `/metrics` exposes a Counter (`app_requests_total` by
  path+status) and a Histogram (`app_request_duration_seconds`). These are
  exactly the RED-method signals SLOs are built from in Week 5.
- **Non-root images:** a container escaping as root is a host problem; as
  UID 10001 it's a contained problem. Defense in depth starts in the
  Dockerfile, and Kubernetes will *verify* it (Day 4) and *enforce* it
  (Week 7).
- **Layer caching:** copy `requirements.txt` and install *before* copying
  code, so code edits don't re-run dependency installation.

## Step 3 — Architecture

```text
        docker build -t senior-devops-api:dev app/
 +---------------------------------------------------+
 | image: senior-devops-api:dev                      |
 |  layer: python:3.13-slim                          |
 |  layer: user app (uid 10001)                      |
 |  layer: pip install -r requirements.txt  (cached) |
 |  layer: COPY main.py                     (cheap)  |
 |  USER 10001 · EXPOSE 8000 · CMD uvicorn           |
 +---------------------------------------------------+
        | docker run -p 8000:8000
        v
   http://localhost:8000
     /healthz  /readyz  /api/work?delay_ms&fail  /metrics
```

## Step 4 — Prerequisites

Docker running; repo from Day 1. Today you **type** `app/main.py`,
`app/requirements.txt`, `app/Dockerfile`, `app/.dockerignore`, and the tests
from the reference repo — reading them as you go. Muscle memory is the point.

## Step 5 — Exact implementation

**5.1 Create the app** — type in `app/main.py`, `app/requirements.txt`,
`app/requirements-dev.txt`, `app/Dockerfile`, `app/.dockerignore`,
`app/tests/test_main.py` from the reference repo. As you type, answer for
yourself: why is `/healthz` dependency-free? why is `delay_ms` capped at
5000? why does the Dockerfile use UID 10001 instead of a name?

**5.2 Run it uncontainerized first** (isolate app bugs from container bugs):

```bash
cd app
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
uvicorn main:app --port 8000 &
curl -s localhost:8000/healthz             # {"status":"ok"}
curl -s "localhost:8000/api/work"          # healthy body
curl -s "localhost:8000/api/work?delay_ms=300"        # ~300ms slower
curl -si "localhost:8000/api/work?fail=true" | head -1 # HTTP/1.1 500
curl -s localhost:8000/metrics | grep app_requests_total
kill %1; deactivate; cd ..
```

**5.3 Unit tests:**

```bash
make app-test
```

EXPECT: 5 passed. These same tests gate CI in Week 2.

**5.4 Build the image:**

```bash
make app-build
# wraps: docker build -t senior-devops-api:dev app/
```

EXPECT: layer-by-layer build. Run it a second time — near-instant, every
layer `CACHED`. Now touch `main.py` and rebuild: only the COPY layer and
later rebuild. That asymmetry is the caching lesson.

**5.5 Run the container:**

```bash
make app-run     # foreground; or: docker run -d --rm -p 8000:8000 --name senior-devops-api senior-devops-api:dev
# in another terminal:
curl -s localhost:8000/healthz
```

**5.6 Prove non-root and inspect:**

```bash
docker exec senior-devops-api id
# uid=10001(app) gid=10001(app)
docker inspect senior-devops-api --format 'user={{.Config.User}} image={{.Config.Image}}'
docker image ls senior-devops-api    # note the size (~150-200MB)
docker stop senior-devops-api
```

## Step 6 — Validation

- All four endpoints answer in the container exactly as they did in the venv.
- `docker exec ... id` shows uid 10001, not root.
- `make app-test` green.
- Second `docker build` fully cached.

## Step 7 — Break/Fix (two drills)

**Drill A:** quit Docker Desktop entirely. Run `make app-build`.
**Drill B:** start the container with a wrong port mapping:

```bash
docker run -d --rm -p 8000:9999 --name wrongport senior-devops-api:dev
curl -s --max-time 3 localhost:8000/healthz
```

## Step 8 — Investigation

Drill A output:

```text
Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
```

Layered thinking again: the *client* printed the error; the *daemon* is the
missing layer. `docker version` shows Client info then the same error for
Server — a perfect one-command layer diagnosis.

Drill B: curl gets an empty reply/reset. Investigate:

```bash
docker ps --format '{{.Names}} {{.Ports}}'   # 0.0.0.0:8000->9999/tcp
docker logs wrongport | tail -2              # uvicorn: listening on 0.0.0.0:8000
```

The mapping forwards host:8000 → container:9999, but the app listens on
container:8000. Nothing is listening where traffic lands.

## Step 9 — Root cause

A: no daemon; the CLI is a thin client over a Unix socket.
B: port publishing maps *host* to *container* ports; it does not tell the
app anything. The contract has three parts that must agree: app listen port,
`-p` right side, and consumer target. (Kubernetes has the same triple:
containerPort / targetPort / port — tomorrow.)

## Step 10 — Recovery

A: `open -a Docker`, wait, re-run — then note in the log how much time the
default error message cost you before you checked the daemon.
B: `docker stop wrongport; docker run -d --rm -p 8000:8000 ... ` and
re-curl.

## Step 11 — Automation opportunity

Build+test become CI on every push (Week 2), with immutable Git-SHA tags
replacing `:dev`. The venv dance gets captured by `make app-test` already.

## Step 12 — Security review

- Non-root at build time (`USER 10001`) — verified with `id`, not assumed.
- Pinned base (`python:3.13-slim`) and pinned deps — floating versions are
  a supply-chain door; Week 6 tightens tags→digests and adds SBOM+scan.
- `.dockerignore` keeps tests, venv, and dev deps out of the image: smaller
  attack surface, no accidental secret files in layers.
- `/api/work?fail=true` is deliberate chaos tooling; in a real product this
  would be auth-gated or non-prod only — note it in `docs/security.md`.

## Step 13 — Reliability review

Failure injection makes reliability *testable*: you can now create latency
and 5xx on demand, which turns Weeks 5's SLO math from theory into drills.
Single-worker uvicorn is a deliberate choice: replicas are Kubernetes' job.

## Step 14 — Cost review

Local, $0. Image size matters later: smaller images = faster pulls = faster
scaling and cheaper registry storage/transfer. Note your image's size in
the log; you'll compare it if you optimize in Week 6.

## Step 15 — GitHub evidence

```bash
git add app/
git commit -m "feat(app): FastAPI lab service with metrics + failure injection; non-root image"
git push
```

## Step 16 — Learning log

Include: measured cached-vs-uncached build times, the Drill B diagnosis
chain, and the container's user/size facts from `docker inspect`.

## Step 17 — Interview question

*"Why do we run containers as non-root when containers are 'isolated'
anyway?"* — isolation is namespaces/cgroups, not a security boundary
guarantee; kernel exploits and misconfigurations (mounted sockets,
privileged mode) escalate from root in-container to root on host; non-root
+ dropped capabilities + seccomp shrink the blast radius. Defense in depth.

## Step 18 — Done criteria

- [ ] App runs in venv and container; all 4 endpoints verified in both
- [ ] `make app-test` green (5 tests)
- [ ] Container proven non-root via `docker exec ... id`
- [ ] Rebuild cache behavior observed and explained
- [ ] Both drills diagnosed with evidence in the log
- [ ] Commit pushed
