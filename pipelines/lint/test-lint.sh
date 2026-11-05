#!/usr/bin/env bash
# Checks the linter against the samples in pipelines/lint/samples:
#   safe.sql              passes, risk-level=low
#   risky.sql             passes, risk-level=high, and every risk rule fires
#   policy_violation.sql  fails, and both policy rules fire
#
# Usage (from the repo root): bash pipelines/lint/test-lint.sh
set -uo pipefail

LINT=pipelines/lint/lint-schema.sh
SAMPLES=pipelines/lint/samples
failed=0

# expect <file> <exit code> <risk level or -> [rule]...
expect() {
  local file=$1 want_status=$2 want_risk=$3 output status risk rule problems=""
  shift 3
  # Unset the GitHub variables so sample findings don't show up as PR annotations or step outputs.
  output="$(GITHUB_ACTIONS= GITHUB_OUTPUT= GITHUB_STEP_SUMMARY= bash "$LINT" "$file" 2>&1)"
  status=$?
  risk="$(echo "$output" | tail -n 1)"

  [ "$status" -eq "$want_status" ] || problems+=" exit $status (want $want_status);"
  [ "$want_risk" = - ] || [ "$risk" = "risk-level=$want_risk" ] || problems+=" $risk (want $want_risk);"
  for rule in "$@"; do
    grep -qF "[$rule]" <<< "$output" || problems+=" no [$rule] finding;"
  done

  if [ -n "$problems" ]; then
    echo "FAIL: $file:$problems"
    echo "$output" | sed 's/^/    /'
    failed=1
  else
    echo "ok:   $file"
  fi
}

expect "$SAMPLES/safe.sql" 0 low
expect "$SAMPLES/risky.sql" 0 high \
  drop-table drop-column change-column-type set-not-null validating-constraint \
  unique-constraint-without-index blocking-index foreign-key-without-index
expect "$SAMPLES/policy_violation.sql" 1 - \
  missing-rollback concurrent-in-transaction

exit "$failed"
