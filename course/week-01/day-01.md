# Day 1 — Workstation, Git, GitHub, tools-check

## Step 1 — Problem understanding

Everything we build for 14 weeks runs through ten tools. Today we install
them, prove they work with a script (not by hoping), and put the repository
under Git discipline. The deliverable is a workstation someone else could
reproduce from the README — reproducibility is the first production skill.

## Step 2 — Concepts

- **Package manager over downloads:** Homebrew gives you upgradeable,
  scriptable installs. A tool you can't reinstall from a one-liner is a
  future outage.
- **Client vs server:** `kubectl`, `helm`, `docker` are *clients*. Installing
  them proves nothing about the systems they talk to. Today you'll see
  kubectl fail precisely because there is no server — on purpose.
- **The kubectl connection path:** kubectl → kubeconfig (`~/.kube/config`) →
  context → credentials → API server. Every kubectl failure lives in exactly
  one of those layers.
- **Evidence culture:** we script the environment check so "works on my
  machine" becomes "here is the output".

## Step 3 — Architecture

```text
 macOS (Apple Silicon)
 +---------------------------------------------------+
 | Homebrew                                          |
 |   ├── git, gh          (source control)           |
 |   ├── docker desktop   (container runtime + VM)   |
 |   ├── kubectl, kind,   (kubernetes toolchain)     |
 |   │   helm                                        |
 |   ├── python, node/npm (app + tooling runtimes)   |
 |   └── make             (automation entry point)   |
 +---------------------------------------------------+
          |
          v
 senior-devops-platform-lab (Git repo) ---> GitHub (remote)
```

## Step 4 — Prerequisites

- macOS on Apple Silicon, admin rights, ~20GB free disk.
- A GitHub account.
- The reference repo unzipped (you'll re-type key files, not just push it).

## Step 5 — Exact implementation

**5.1 Xcode Command Line Tools (gives you git and make):**

```bash
xcode-select --install || true   # "already installed" is fine
```

**5.2 Homebrew** (skip if `brew --version` works):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

WHAT: installs Homebrew. WHY: every remaining install is one line.
COULD FAIL: corporate proxy/TLS interception → read the error, it names the
blocked URL.

**5.3 Tools:**

```bash
brew install git kubectl helm kind gh node python
brew install --cask docker
```

WHAT: CLI tools via formulae; Docker Desktop via cask (it's a GUI app that
runs the Linux VM containers actually live in on macOS).
EXPECT: several minutes; `node` from brew is currently the latest major —
that's fine for Week 1 tooling; Week 9 (Backstage) will pin Node 24 LTS
explicitly with `brew install node@24`.

**5.4 Start Docker Desktop** (first run needs the GUI):

```bash
open -a Docker
# wait for the whale icon to settle, then:
docker run --rm hello-world
```

EXPECT: "Hello from Docker!". This proves client → daemon → image pull →
container run, the whole chain.

**5.5 Repository:**

```bash
cd ~/code   # or wherever you keep work
# Option A (recommended): create YOUR repo and type files in as the course needs them
mkdir senior-devops-platform-lab && cd senior-devops-platform-lab
git init -b main
# copy in from the reference zip ONLY: Makefile, scripts/, .gitignore, docs/, course/
# (app/ and k8s/ get typed by hand on Days 3–5 — that's where the learning is)

git add .
git commit -m "chore: course scaffolding, automation, and docs baseline"
```

**5.6 GitHub remote:**

```bash
gh auth login          # choose GitHub.com → HTTPS → browser login
gh repo create senior-devops-platform-lab --public --source=. --remote=origin --push
```

WHAT: authenticates the GitHub CLI, creates the remote, pushes main.
COULD FAIL: `gh` not authenticated (re-run `gh auth login`), or repo name
collision (pick another name, adjust nothing else).

## Step 6 — Validation

```bash
make tools-check
```

EXPECT: every line `OK` with a version, `== 10 passed, 0 failed ==`.
Each check *executes* the tool — a broken install fails here, today,
instead of on Day 4 mid-deploy.

```bash
git remote -v      # origin → your GitHub URL (fetch + push)
git status         # clean tree
gh repo view --web # repo opens in browser with your commit
```

## Step 7 — Break/Fix (deliberate)

Run:

```bash
kubectl cluster-info
```

## Step 8 — Investigation

You'll see something like:

```text
E... couldn't get current server API group list: Get "http://localhost:8080/api"...
The connection to the server localhost:8080 was refused
```

Work the layers — client first, then config, then server:

```bash
kubectl version --client        # client fine?
kubectl config current-context  # "current-context is not set"
kubectl config view             # empty: no clusters, no users
ls ~/.kube/config 2>/dev/null   # may not even exist
```

## Step 9 — Root cause

kubectl is healthy; there is simply **no cluster and no kubeconfig**.
`localhost:8080` is kubectl's ancient last-resort default when it has no
config at all. The error *looks* like a network problem but is a
configuration-absence problem — this exact misread wastes real engineers'
time weekly.

## Step 10 — Recovery

None needed today. Tomorrow `kind create cluster` creates the cluster AND
writes the `kind-platform-lab` context. Knowing that "no fix required, the
missing layer arrives tomorrow" is itself a diagnosis.

## Step 11 — Automation opportunity

`tools-check.sh` already automates environment verification. Later: CI runs
the same validation (Week 2), and golden-path templates make whole-repo
setup a generated artifact (Week 10).

## Step 12 — Security review

- `gh auth login` stored an OAuth token in the macOS keychain — not in the
  repo. Verify nothing sensitive is staged: `git diff --cached` before every
  commit, starting now.
- `.gitignore` blocks `kubeconfig*`, `.env`, keys. The control is habit;
  the file is a backstop.

## Step 13 — Reliability review

A scripted environment check turns "mysterious mid-lab failure" into
"10-second pre-flight". The same principle scales up to production
readiness checks and CI preflight jobs.

## Step 14 — Cost review

Everything local. $0. (Docker Desktop is free for individual use.)

## Step 15 — GitHub evidence

Commit: scaffolding, Makefile, scripts, docs baseline, `.gitignore`.
Not committed: nothing generated by tools, no tokens, no kubeconfig.

## Step 16 — Learning log

Fill in today's entry in `docs/learning-log.md` — the Day 1 example entry
in that file shows the exact expected shape (including this break/fix).
Replace it with what actually happened on YOUR machine, especially anything
that failed differently.

## Step 17 — Interview question

*"You type `kubectl get pods` on a fresh laptop and get 'connection refused
localhost:8080'. What's wrong, and why that port?"* — Strong answer: no
kubeconfig/context exists; kubectl falls back to a legacy localhost default;
fix is obtaining a kubeconfig (cloud CLI, kind, or ops handoff), not
debugging the network.

## Step 18 — Done criteria

- [ ] `make tools-check` → 10/10 OK
- [ ] `docker run --rm hello-world` succeeded
- [ ] Repo on GitHub, `main` pushed, working tree clean
- [ ] kubectl failure investigated and understood (not just observed)
- [ ] Learning-log entry written with real output
- [ ] You can sketch the kubectl→kubeconfig→context→credentials→API path from memory
