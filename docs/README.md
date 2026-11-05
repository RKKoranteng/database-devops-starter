# Schema lint rules

How to disable, add and change the rules that the [Lint schema](../.github/workflows/lint-schema.yml) workflow checks. For what each rule flags and why, see [Linting schema changes](../README.md#linting-schema-changes) in the main README.

There are two sets of rules:

| Rules | Where they live | How to turn one off |
|---|---|---|
| This repo's rules (`missing-rollback`, `drop-column`, ...) | [changesets.awk](../pipelines/lint/changesets.awk) and [lint-schema.sh](../pipelines/lint/lint-schema.sh) | [disabled-rules.txt](../pipelines/lint/disabled-rules.txt) |
| [Squawk](https://squawkhq.com/docs/rules) rules | The Squawk tool | [.squawk.toml](../.squawk.toml) |

Every finding is labelled with its rule name, like `[drop-column]` for this repo's rules or `warning[ban-drop-column]` for Squawk's. Use that name to turn the rule off.

## Files

| File | Role |
|---|---|
| [changesets.awk](../pipelines/lint/changesets.awk) | Reads one SQL file and prints a line for each match, e.g. `drop-column\|11\|orders` (rule, line, table) |
| [lint-schema.sh](../pipelines/lint/lint-schema.sh) | Runs `changesets.awk` on each file, turns each finding into an error or warning with a message, runs Squawk, and sets the risk level |
| [disabled-rules.txt](../pipelines/lint/disabled-rules.txt) | This repo's rules to skip |
| [test-lint.sh](../pipelines/lint/test-lint.sh) | Self-test: runs the linter on the samples and checks each expected rule fires |
| [samples/](../pipelines/lint/samples/) | `safe.sql` (must be low), `risky.sql` (must be high), `policy_violation.sql` (must fail) |

## Disabling a rule

Disabling a rule turns it off for every file. Write down why, so the next person knows whether it's still needed.

### One of this repo's rules

Add the rule name to [disabled-rules.txt](../pipelines/lint/disabled-rules.txt), one per line, with a `#` comment:

```
blocking-index   # all our tables are small enough to index without CONCURRENTLY
```

Then remove that rule from the list in [test-lint.sh](../pipelines/lint/test-lint.sh). Otherwise the self-test fails, because the disabled rule no longer fires on its sample.

Think twice before disabling a policy rule (`missing-rollback`, `concurrent-in-transaction`). It lets those changes through without failing the PR. Get team agreement first.

### A Squawk rule

Add the rule name, from Squawk's output or its [rule list](https://squawkhq.com/docs/rules), to `excluded_rules` in [.squawk.toml](../.squawk.toml):

```toml
excluded_rules = [
    "prefer-robust-stmts",  # existing: this repo avoids IF NOT EXISTS on purpose
    "renaming-column",      # why you're turning it off
]
```

## Adding a rule

Worked example: a `rename-column` risk rule, because renaming a column breaks code still using the old name.

**1. Detect it in [changesets.awk](../pipelines/lint/changesets.awk).** Statement rules go in `check_statement`, which gets each whole SQL statement as `s`: lowercase, with its lines joined by spaces. Below the other `ALTER TABLE` checks, `t` is the table name. Print `rule|line|table`:

```awk
    if (s ~ /rename[ \t]+column/)
        print "rename-column|" line "|" t
```

Match on lowercase text, and use `[ \t]+` between words so extra spaces or line breaks don't hide a match. The script must run on both gawk and mawk, so stick to `~`, `match()`, `sub()` and `gsub()`. Avoid gawk-only features like the three-argument `match()`.

Rules about a whole changeset rather than one statement (like `missing-rollback`) are set in the main pattern blocks and printed from `end_changeset`.

**2. Give it a message in [lint-schema.sh](../pipelines/lint/lint-schema.sh).** Add a `case` entry next to the other risk rules. `$a` is the table name from step 1:

```bash
      rename-column)
        msg="Renames a column on $a, which breaks code still using the old name. Add the new column, move code over, then drop the old one." ;;
```

That makes it a **risk** rule: a warning that sets the risk level to high. To make it a **policy** rule that fails the PR instead, follow the `missing-rollback` entry: call `report error`, add 1 to `errors`, then `continue`.

**3. Add a sample.** Add a changeset that triggers the rule to [samples/risky.sql](../pipelines/lint/samples/risky.sql), or to [samples/policy_violation.sql](../pipelines/lint/samples/policy_violation.sql) for a policy rule. Every sample changeset needs a rollback, or it also triggers `missing-rollback`:

```sql
--changeset sample:risky-rename-column
ALTER TABLE customers RENAME COLUMN full_name TO name;
--rollback ALTER TABLE customers RENAME COLUMN name TO full_name;
```

**4. Make the self-test expect it.** Add the rule name to the list after `risky.sql` (or `policy_violation.sql`) in [test-lint.sh](../pipelines/lint/test-lint.sh):

```bash
expect "$SAMPLES/risky.sql" 0 high \
  drop-table drop-column ... foreign-key-without-index rename-column
```

**5. Run the tests** from the repo root:

```bash
SKIP_SQUAWK=1 bash pipelines/lint/test-lint.sh
```

All three samples should print `ok`. Then check the rule doesn't fire on safe statements that look similar: put a few in a scratch `.sql` file and run `SKIP_SQUAWK=1 bash pipelines/lint/lint-schema.sh <file>`. It should print `risk-level=low`. For `rename-column`, that's statements like `ALTER TABLE t RENAME CONSTRAINT ...`.

**6. Document it.** Add a row to the risk rules (or policy rules) table in the main [README](../README.md#linting-schema-changes), and a line to [CHANGELOG.md](../CHANGELOG.md).

## Changing a rule

Edit its check in `changesets.awk` or its message in `lint-schema.sh`, then run the self-test. If a rule flags something it shouldn't, add that statement to [samples/safe.sql](../pipelines/lint/samples/safe.sql), so the self-test fails if the false alarm ever comes back.
