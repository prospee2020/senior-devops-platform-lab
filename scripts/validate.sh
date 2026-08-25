#!/usr/bin/env bash
# validate.sh — static validation of everything in the repository.
# This is the same discipline CI will enforce from Week 2 onward.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
ERRORS=0

echo "== 1. YAML syntax =="
while IFS= read -r f; do
  if python3 - "$f" <<'EOF'
import sys, yaml
with open(sys.argv[1]) as fh:
    list(yaml.safe_load_all(fh))
EOF
  then
    echo "  OK    $f"
  else
    echo "  FAIL  $f"
    ERRORS=$((ERRORS + 1))
  fi
done < <(find k8s kind argocd helm otel .github -name '*.yaml' -o -name '*.yml' 2>/dev/null)

echo "== 2. Python syntax =="
while IFS= read -r f; do
  if python3 -m py_compile "$f" 2>/dev/null; then
    echo "  OK    $f"
  else
    echo "  FAIL  $f"
    ERRORS=$((ERRORS + 1))
  fi
done < <(find app -name '*.py')

echo "== 3. Shell syntax =="
while IFS= read -r f; do
  if bash -n "$f"; then
    echo "  OK    $f"
  else
    echo "  FAIL  $f"
    ERRORS=$((ERRORS + 1))
  fi
done < <(find scripts -name '*.sh')

echo "== 4. Kustomize build (requires kubectl) =="
if command -v kubectl >/dev/null 2>&1; then
  for dir in k8s/base k8s/overlays/dev; do
    if kubectl kustomize "$dir" >/dev/null; then
      echo "  OK    $dir"
    else
      echo "  FAIL  $dir"
      ERRORS=$((ERRORS + 1))
    fi
  done
else
  echo "  SKIP  kubectl not installed — kustomize builds not validated"
fi

echo "== 5. Required structure =="
for p in app/main.py app/Dockerfile k8s/base/kustomization.yaml \
         k8s/overlays/dev/kustomization.yaml docs/learning-log.md Makefile; do
  if [ -e "$p" ]; then
    echo "  OK    $p"
  else
    echo "  MISSING $p"
    ERRORS=$((ERRORS + 1))
  fi
done

echo
if [ "$ERRORS" -eq 0 ]; then
  echo "== validation passed (static checks only — runtime behavior is proven by deploying) =="
else
  echo "== validation FAILED: $ERRORS error(s) =="
  exit 1
fi
