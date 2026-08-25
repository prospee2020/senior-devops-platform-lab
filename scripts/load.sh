#!/usr/bin/env bash
# load.sh — small synthetic load for the dev deployment.
# Prereq in another terminal:  make port-forward
# Usage: ./scripts/load.sh [requests] [base_url]
set -uo pipefail

REQUESTS="${1:-50}"
BASE="${2:-http://localhost:8080}"

ok=0; err=0
for i in $(seq 1 "$REQUESTS"); do
  # Every 10th request simulates a failure; every 5th adds 200ms latency.
  args=""
  [ $((i % 5)) -eq 0 ] && args="delay_ms=200"
  [ $((i % 10)) -eq 0 ] && args="fail=true"
  code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/work?$args")
  if [ "$code" = "200" ]; then ok=$((ok+1)); else err=$((err+1)); fi
done

echo "sent=$REQUESTS ok=$ok err=$err"
echo "Now check the metrics the app recorded:"
echo "  curl -s $BASE/metrics | grep app_requests_total"
