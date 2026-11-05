#!/usr/bin/env bash
# Runs every .sql file under schema/tests as a test case, against the database in the
# PG* environment variables (PGHOST, PGDATABASE, PGUSER, PGPASSWORD).
#
# Each file runs in its own transaction, which is rolled back afterwards, so tests can't
# affect each other. A file fails if any statement in it errors; use RAISE EXCEPTION for
# a failed check.
#
# Usage (from the repo root): bash pipelines/test/run-sql-tests.sh [tests dir]
set -uo pipefail

TESTS_DIR="${1:-schema/tests}"
mapfile -t files < <(find "$TESTS_DIR" -name '*.sql' 2>/dev/null | sort)
if [ ${#files[@]} -eq 0 ]; then
  echo "No test files found in $TESTS_DIR"
  exit 0
fi

passed=0
failed=0
rows=""
for file in "${files[@]}"; do
  if output="$(psql -X -q -v ON_ERROR_STOP=1 -c 'BEGIN' -f "$file" -c 'ROLLBACK' 2>&1)"; then
    echo "ok:   $file"
    passed=$((passed + 1))
    rows+="| \`$file\` | passed |"$'\n'
  else
    failed=$((failed + 1))
    rows+="| \`$file\` | **failed** |"$'\n'
    # psql reports errors as "psql:<file>:<line>: ERROR:  <message>"
    line="$(sed -n 's/^psql:.*:\([0-9][0-9]*\): ERROR: .*/\1/p' <<< "$output" | head -n 1)"
    message="$(sed -n 's/^psql:.*:[0-9][0-9]*: ERROR: *//p' <<< "$output" | head -n 1)"
    if [ "${GITHUB_ACTIONS:-}" = true ]; then
      echo "::error file=$file,line=${line:-1},title=SQL test failed::${message:-see the step log}"
    fi
    echo "FAIL: $file"
    sed 's/^/    /' <<< "$output"
  fi
done

echo "$passed passed, $failed failed"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### SQL tests: $passed passed, $failed failed"
    echo "| Test | Result |"
    echo "|---|---|"
    printf '%s' "$rows"
  } >> "$GITHUB_STEP_SUMMARY"
fi

[ "$failed" -eq 0 ]
