#!/usr/bin/env bash
# Lints Liquibase formatted SQL files for risky migration patterns and policy violations.
#
# Usage (from the repo root): bash pipelines/lint/lint-schema.sh <file.sql>...
#
# Policy rules fail the run (exit 1):
#   missing-rollback            changeset without a rollback (use --rollback empty when none is possible)
#   concurrent-in-transaction   CREATE/DROP INDEX CONCURRENTLY without runInTransaction:false
# Risk rules set risk-level=high but don't fail the run:
#   drop-table, drop-column             data loss, and breaks code still using the object
#   change-column-type                  rewrites the table under an exclusive lock
#   set-not-null                        scans the table under an exclusive lock
#   validating-constraint               FOREIGN KEY or CHECK without NOT VALID scans the table under lock
#   unique-constraint-without-index     UNIQUE or PRIMARY KEY builds its index under an exclusive lock
#   blocking-index                      CREATE INDEX without CONCURRENTLY blocks writes while it builds
#   foreign-key-without-index           foreign key column with no index starting with that column
#   any Squawk violation (rules configured in .squawk.toml at the repo root)
#
# Rules listed in pipelines/lint/disabled-rules.txt are skipped.
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

disabled_rules="$(sed -e 's/#.*//' -e 's/[[:space:]]//g' -e '/^$/d' "$LINT_DIR/disabled-rules.txt" 2>/dev/null || true)"

is_disabled() {
  grep -qx "$1" <<< "$disabled_rules"
}

# report <error|warning> <rule> <file> <line> <message>
report() {
  if [ "${GITHUB_ACTIONS:-}" = true ]; then
    echo "::$1 file=$3,line=$4,title=$2::$5"
  else
    echo "$1: $3:$4: [$2] $5"
  fi
}

# Files searched for an index covering a foreign key: the whole schema plus the files being linted.
mapfile -t index_sources < <(find "$SCHEMA_DIR" -name '*.sql' 2>/dev/null; printf '%s\n' "$@")

# has_index <table> <column>: true if some CREATE INDEX on <table> starts with <column>.
has_index() {
  grep -Eiq "[[:space:]]ON[[:space:]]+(ONLY[[:space:]]+)?([a-z0-9_]+\.)?\"?$1\"?[[:space:]]*(USING[[:space:]]+[a-z]+[[:space:]]*)?\([[:space:]]*\"?$2\"?[[:space:],)]" \
    "${index_sources[@]}"
}

echo "== Policy and risk checks"
for file in "$@"; do
  while IFS='|' read -r rule line a b; do
    if [ "$rule" = fk ]; then
      has_index "$a" "$b" && continue
      rule=foreign-key-without-index
    fi
    is_disabled "$rule" && continue

    case "$rule" in
      missing-rollback)
        report error "$rule" "$file" "$line" "Changeset $a has no rollback. Add --rollback <sql>, or --rollback empty if it cannot be undone."
        errors=$((errors + 1)); continue ;;
      concurrent-in-transaction)
        report error "$rule" "$file" "$line" "Changeset $a uses CONCURRENTLY, which cannot run inside a transaction. Add runInTransaction:false to its --changeset line."
        errors=$((errors + 1)); continue ;;
      foreign-key-without-index)
        msg="Foreign key column $a.$b has no index starting with $b. Deletes and key updates on the referenced table will scan $a." ;;
      drop-table)
        msg="Drops table $a. Its data is lost, and code still using it breaks." ;;
      drop-column)
        msg="Drops a column from $a. Its data is lost, and code still using it breaks. Stop using the column in a release before dropping it." ;;
      change-column-type)
        msg="Changes a column type on $a, which usually rewrites the table under an exclusive lock. Consider a new column, backfill, then swap." ;;
      set-not-null)
        msg="SET NOT NULL on $a scans the table under an exclusive lock. Add a CHECK (col IS NOT NULL) NOT VALID constraint and validate it first." ;;
      validating-constraint)
        msg="Adds a FOREIGN KEY or CHECK on $a that is validated under lock. Add it NOT VALID, then VALIDATE CONSTRAINT in a separate changeset." ;;
      unique-constraint-without-index)
        msg="Adds a UNIQUE or PRIMARY KEY on $a, which builds its index under an exclusive lock. Create a unique index CONCURRENTLY, then ADD CONSTRAINT ... USING INDEX." ;;
      blocking-index)
        msg="CREATE INDEX on $a blocks writes while it builds. Use CREATE INDEX CONCURRENTLY with runInTransaction:false." ;;
      *)
        msg="Finding from changesets.awk with no message in lint-schema.sh." ;;
    esac
    report warning "$rule" "$file" "$line" "$msg"
    risk=high
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
