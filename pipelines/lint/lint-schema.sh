#!/usr/bin/env bash
# Lints Liquibase formatted SQL files for risky migration patterns and policy violations.
#
# Usage (from the repo root): bash pipelines/lint/lint-schema.sh <file.sql>...
#
# Policy violations fail the run (exit 1):
#   - a changeset without a rollback (use --rollback empty when none is possible)
#   - CREATE/DROP INDEX CONCURRENTLY in a changeset without runInTransaction:false
# Risky patterns set risk-level=high but don't fail the run:
#   - any Squawk violation: table-locking ALTERs, non-concurrent index builds, dropped columns or tables, ...
#     Rules are configured in .squawk.toml at the repo root.
#   - a foreign key column with no index that starts with that column
#
# Prints risk-level=low|high as the last line, and writes it to $GITHUB_OUTPUT when set.
# SKIP_SQUAWK=1 skips the Squawk checks, for machines without Squawk installed.
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "usage: $0 <file.sql>..." >&2
  exit 2
fi

LINT_DIR="$(dirname "$0")"
SCHEMA_DIR="${SCHEMA_DIR:-schema}"
risk=low
errors=0

# report <error|warning> <file> <line> <message>
report() {
  if [ "${GITHUB_ACTIONS:-}" = true ]; then
    echo "::$1 file=$2,line=$3::$4"
  else
    echo "$1: $2:$3: $4"
  fi
}

# Files searched for an index covering a foreign key: the whole schema plus the files being linted.
mapfile -t index_sources < <(find "$SCHEMA_DIR" -name '*.sql' 2>/dev/null; printf '%s\n' "$@")

# has_index <table> <column>: true if some CREATE INDEX on <table> starts with <column>.
has_index() {
  grep -Eiq "[[:space:]]ON[[:space:]]+(ONLY[[:space:]]+)?([a-z0-9_]+\.)?\"?$1\"?[[:space:]]*(USING[[:space:]]+[a-z]+[[:space:]]*)?\([[:space:]]*\"?$2\"?[[:space:],)]" \
    "${index_sources[@]}"
}

echo "== Policy and foreign key checks"
for file in "$@"; do
  while IFS='|' read -r kind line a b; do
    case "$kind" in
      no-rollback)
        report error "$file" "$line" "Changeset $a has no rollback. Add --rollback <sql>, or --rollback empty if it cannot be undone."
        errors=$((errors + 1)) ;;
      concurrent)
        report error "$file" "$line" "Changeset $a uses CONCURRENTLY, which cannot run inside a transaction. Add runInTransaction:false to its --changeset line."
        errors=$((errors + 1)) ;;
      fk)
        if ! has_index "$a" "$b"; then
          report warning "$file" "$line" "Foreign key column $a.$b has no index starting with $b. Deletes and key updates on the referenced table will scan $a."
          risk=high
        fi ;;
    esac
  done < <(awk -f "$LINT_DIR/changesets.awk" "$file")
done

echo "== Squawk"
if [ "${SKIP_SQUAWK:-0}" = 1 ]; then
  echo "Skipped (SKIP_SQUAWK=1)"
elif ! command -v squawk >/dev/null; then
  echo "squawk not found. Install it with 'npm install --global squawk-cli@1', or set SKIP_SQUAWK=1." >&2
  exit 2
elif ! squawk "$@"; then
  risk=high
fi

if [ "$errors" -gt 0 ]; then
  echo "$errors policy violation(s) found"
fi

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Schema lint"
    echo "- Files: $#"
    echo "- Policy violations: $errors"
    echo "- Risk level: **$risk**"
  } >> "$GITHUB_STEP_SUMMARY"
fi
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "risk-level=$risk" >> "$GITHUB_OUTPUT"
fi
echo "risk-level=$risk"

exit $(( errors > 0 ))
