#!/usr/bin/env bash
# Checks the linter against the samples in pipelines/lint/samples:
#   safe.sql              passes, risk-level=low
#   risky.sql             passes, risk-level=high
#   policy_violation.sql  fails
#
# Usage (from the repo root): bash pipelines/lint/test-lint.sh
set -uo pipefail

LINT=pipelines/lint/lint-schema.sh
SAMPLES=pipelines/lint/samples
failed=0

# expect <file> <exit code> [risk level]
expect() {
  local output status risk
  # Unset the GitHub variables so sample findings don't show up as PR annotations or step outputs.
  output="$(GITHUB_ACTIONS= GITHUB_OUTPUT= GITHUB_STEP_SUMMARY= bash "$LINT" "$1" 2>&1)"
  status=$?
  risk="$(echo "$output" | tail -n 1)"
  if [ "$status" -ne "$2" ] || { [ -n "${3:-}" ] && [ "$risk" != "risk-level=$3" ]; }; then
    echo "FAIL: $1 (want exit $2${3:+, risk-level=$3}; got exit $status, $risk)"
    echo "$output" | sed 's/^/    /'
    failed=1
  else
    echo "ok:   $1 (exit $status${3:+, $risk})"
  fi
}

expect "$SAMPLES/safe.sql" 0 low
expect "$SAMPLES/risky.sql" 0 high
expect "$SAMPLES/policy_violation.sql" 1

exit "$failed"
