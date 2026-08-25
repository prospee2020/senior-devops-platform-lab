# Learning Log

Rules for this log:

1. Record **real** failures, including embarrassing ones (Docker not
   running, wrong context, typos in YAML). Those are the entries interviewers
   believe.
2. Every failure gets: Symptom → Hypothesis → Evidence → Root cause → Fix →
   Validation → Prevention.
3. Write the entry the same day. Memory lies by tomorrow.

Template for each day:

```markdown
## YYYY-MM-DD — Day N: Topic

### What I learned

### What I built

### Commands used

### Validation evidence

### Failure introduced / observed

### Investigation

### Root cause

### Fix

### Security impact

### Reliability impact

### Cost impact

### Git commit

### Interview takeaway
```

---

## 2026-08-24 — Day 1: Workstation Setup  (EXAMPLE ENTRY — replace with your own)

### What I learned

I learned that installing kubectl does not mean a Kubernetes cluster is
available. kubectl is only the client. The complete path is:

```text
kubectl
  ↓
kubeconfig  (~/.kube/config)
  ↓
context  (cluster + user + namespace triple)
  ↓
credentials
  ↓
Kubernetes API server
```

If any layer is missing, the failure appears at the kubectl layer even
though kubectl itself is fine.

### What I built

Configured the development workstation (Docker Desktop, kubectl, Helm, kind,
Git, Python, Node, Make, gh) and initialized the GitHub repository.

### Commands used

```bash
brew install kubectl helm kind gh node python make git
./scripts/tools-check.sh
gh repo create senior-devops-platform-lab --public
```

### Validation evidence

```text
./scripts/tools-check.sh
  Docker     OK    28.x
  kubectl    OK    clientVersion v1.36.x
  Helm       OK    v4.1.x
  kind       OK    kind v0.32.x
  Git        OK    git version 2.x
  Python     OK    Python 3.13.x
  Node       OK    v24.x
  npm        OK    11.x
  Make       OK    GNU Make 3.81
  gh         OK    gh version 2.x
== 10 passed, 0 failed ==
```

### Failure introduced / observed

`kubectl cluster-info` failed:
`The connection to the server localhost:8080 was refused`.

### Investigation

- Symptom: connection refused to localhost:8080.
- Hypothesis 1: kubectl broken → `kubectl version --client` works, so no.
- Hypothesis 2: no kubeconfig/context → `kubectl config current-context`
  returns "current-context is not set". Confirmed.

### Root cause

kubectl was installed correctly, but no Kubernetes API server existed yet
and no context was configured. localhost:8080 is kubectl's last-resort
default when it has no kubeconfig.

### Fix

No fix required. The cluster is created on Day 2 with kind, which also
writes the kubeconfig context `kind-platform-lab`.

### Security impact

No secrets or credentials were committed. Verified `.gitignore` blocks
kubeconfig files before the first commit.

### Reliability impact

Tool validation is automated (`make tools-check`), so environment drift is
caught in seconds instead of mid-lab.

### Cost impact

All work local. AWS cost: $0.

### Git commit

`chore: workstation verified, repo initialized, tools-check automated`

### Interview takeaway

Troubleshoot in layers (client → config → network → server) instead of
assuming the tool you typed is the broken part.
