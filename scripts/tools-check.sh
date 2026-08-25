#!/usr/bin/env bash
# tools-check.sh — verify the workstation toolchain.
# Checks that each tool exists AND can execute (an installed-but-broken
# binary should fail here, not on Day 4).
set -uo pipefail

PASS=0
FAIL=0

check() {
  local name="$1"; shift
  if output=$("$@" 2>&1 | head -n 1); then
    printf "  %-10s OK    %s\n" "$name" "$output"
    PASS=$((PASS + 1))
  else
    printf "  %-10s FAIL  (command: %s)\n" "$name" "$*"
    FAIL=$((FAIL + 1))
  fi
}

echo "== Senior DevOps Platform Lab: tool check =="
check "Docker"  docker version --format '{{.Client.Version}}'
check "kubectl" kubectl version --client -o yaml
check "Helm"    helm version --short
check "kind"    kind version
check "Git"     git --version
check "Python"  python3 --version
check "Node"    node --version
check "npm"     npm --version
check "Make"    make --version
check "gh"      gh --version

echo
if ! docker info >/dev/null 2>&1; then
  echo "  WARNING: docker CLI exists but the daemon is not responding."
  echo "           Start Docker Desktop, then re-run: make tools-check"
  FAIL=$((FAIL + 1))
fi

echo "== $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ] || exit 1
