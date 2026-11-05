# database-devops-starter

A starter template for DBA teams who want to ship database changes the same way developers ship code: small, frequent, tested and automated. It provides pipelines to validate, deploy, roll back and measure database changes with DORA metrics, so DBAs can move from gatekeepers to enablers who help developers deliver faster and keep the user experience great.

## Repository structure

```
database-devops-starter/
├── .github/
│   └── workflows/    # GitHub Actions workflows
├── docs/             # Guides, such as how to add or disable lint rules
├── infra/            # Infrastructure specific code
│   └── postgres/     # Liquibase changelog that creates the owner role and database
├── pipelines/        # Pipelines for validating, deploying and rolling back changes
│   ├── bin/          # liquibase wrapper used by the workflow steps
│   ├── lint/         # Schema lint script, its tests and sample changesets
│   └── test/         # Runner for the SQL test cases in schema/tests
├── schema/           # Schema definitions (tables, indexes, triggers, etc)
│   ├── changelog.yaml    # Liquibase master changelog listing which files run, in order
│   ├── sequences/
│   ├── tables/
│   ├── indexes/
│   ├── views/
│   ├── procedures/
│   ├── triggers/
│   └── tests/        # Test cases, one *_test.sql per object, in the same folders as above
├── .gitignore        # Files and folders Git should ignore
├── .squawk.toml      # Squawk lint rule configuration
├── CHANGELOG.md      # Release history and notes
├── LICENSE           # MIT License
└── README.md         # Project overview (this file)
```

## Deploying schema changes

The [Deploy schema](.github/workflows/deploy-schema.yml) workflow uses Liquibase to apply [schema/changelog.yaml](schema/changelog.yaml) to the application database. Only the files listed in the changelog run, top to bottom, so other SQL files in `schema/` are ignored. Liquibase records each applied changeset in its `DATABASECHANGELOG` table and skips it on later runs, so each deploy only applies new changes.

Every change goes through the same pipeline. Each stage waits for the one before it and is skipped if it fails, so nothing reaches a real database until the change has passed lint and been tested on a throwaway one:

```
Lint ──► Test in ephemeral environment ──► Deploy to dev ──► Deploy to qa ──► Deploy to prod
           1. Initialize ephemeral test       1. Show pending     1. Show pending     1. Show pending
              environment                        changes             changes             changes
           2. Set up Liquibase                2. Update change    2. Update change    2. Update change
           3. Update change                   3. Unit tests       3. Unit tests
           4. Test rollback                      (schema/tests)      (schema/tests)
           5. Re-apply change
           6. Unit tests (schema/tests)
```

| Trigger | What runs |
|---|---|
| Pull request touching `schema/` or the pipeline | Lint and Test in ephemeral environment. Nothing is deployed from a PR |
| Merge (push) to `main` | The whole pipeline: lint, test, then dev → qa → prod |
| Manual run (Actions → Deploy schema → Run workflow) | On `main`: the whole pipeline. On any other branch: lint and test only |

Production is not tested with `schema/tests`, because the tests insert data (it is rolled back, but production shouldn't see test writes at all). Only one Deploy schema run per branch happens at a time, so deploys never overlap.

### What each stage proves

| Stage / step | What it proves | Fails when |
|---|---|---|
| Lint | Every changeset has a rollback and follows policy; risky patterns are flagged | A policy rule is broken |
| 1. Initialize ephemeral test environment | A throwaway Postgres 16 is up. It's deleted when the job ends | Postgres doesn't start |
| 3. Update change | Every changeset applies to an empty database | Any changeset errors |
| 4. Test rollback | Every `--rollback` runs, and together they undo everything | A rollback errors, or a table, view, index, sequence, procedure or function is left behind |
| 5. Re-apply change | The changelog can be re-applied cleanly after a rollback | A changeset errors, or the number applied differs from step 3 |
| 6. Unit tests | Every object behaves as its test cases expect (see [Writing tests](#writing-tests)) | Any test file errors. The failing line is marked in the file, and the run summary lists every test |
| Deploy to dev / qa / prod | Shows the changesets that are about to run, then applies only those | A secret is missing, the database can't be reached, or a changeset errors |
| Unit tests on dev / qa | The deployed objects behave as expected in that environment. Each test file is rolled back | Any test file errors |

The ephemeral job's run summary has a table with each step's result and the lint risk level.

The steps call [pipelines/bin/liquibase](pipelines/bin/liquibase), a small wrapper that runs Liquibase in Docker with the connection settings from the job, so each step reads as a plain command such as `liquibase update`. Deploys to dev, qa and prod all use the same steps, from [deploy-environment.yml](.github/workflows/deploy-environment.yml).

### Setting up dev, qa and prod

Create three GitHub environments under Settings → Environments, named `dev`, `qa` and `prod`. For each one:

1. Run [Bootstrap database](#bootstrapping-a-database) against it, so the database and owner role exist.
2. Add these **environment secrets**:

   | Secret | Purpose |
   |---|---|
   | `DB_HOST` | Hostname of that environment's Postgres instance |
   | `DB_PORT` | Port (optional, defaults to `5432`) |
   | `DB_OWNER_PASSWORD` | Password of the owner role Liquibase connects as |

3. Optionally add **environment variables** `DB_NAME` and `DB_USER`, if they aren't `app_db` and `app_user`.

For `prod`, also tick **Required reviewers** and add the people who approve production changes. The pipeline then pauses before Deploy to prod until one of them approves it in the run page. You can do the same for `qa`.

Each instance must be reachable from GitHub's runners. For a database on a private network, use a self-hosted runner. Until an environment is set up, its deploy fails at *Check secrets are set*, and the stages after it are skipped.

### Sample objects

The repo ships with a small customers and orders schema to show each object type:

| Folder | Object |
|---|---|
| `tables/` | `customers`, `orders` |
| `indexes/` | `idx_orders_customer_id`, `idx_orders_status_created_at` |
| `views/` | `customer_order_summary` |
| `procedures/` | `place_order(customer_id, total_amount)` |
| `triggers/` | `set_updated_at()` trigger function, `trg_customers_updated_at`, `trg_orders_updated_at` |

Replace them with your own objects once the pipeline works for you.

### Adding a change

1. Name the file after the object it creates, one object per file, e.g. `schema/tables/payments.sql` or `schema/indexes/idx_payments_order_id.sql`. Later changes to that object (e.g. an `ALTER TABLE`) go in the same file as a new changeset below the existing ones. If such a change depends on an object listed later in the changelog, put it in a new file listed after that object instead, because a file's changesets run at that file's position in the changelog. Never rename or move a file after it has been applied: Liquibase identifies changesets partly by file path and would try to run them again.
2. Add an `include` for it to [schema/changelog.yaml](schema/changelog.yaml), after anything it depends on. A file that isn't listed never runs.
3. Write it as [Liquibase formatted SQL](https://docs.liquibase.com/concepts/changelogs/sql-format.html), starting with `--liquibase formatted sql`. Give every changeset a unique `author:id` and a `--rollback`.
4. Tables and indexes: never edit or drop and recreate them. Change them with a new changeset (`ALTER TABLE`, `CREATE INDEX`), so data is kept. Create and drop indexes `CONCURRENTLY`, with `runInTransaction:false` on the changeset, so they don't block writes.
5. Views, procedures, functions and triggers: use `CREATE OR REPLACE` with `runOnChange:true`, then edit the file in place for later changes (`CREATE OR REPLACE TRIGGER` needs Postgres 14+). Add a `DROP ... IF EXISTS` before the `CREATE` in the same changeset only when `OR REPLACE` can't do the change: when you remove, rename or reorder a view's columns, or change a procedure's or function's parameters, which would otherwise create a second version alongside the old one.
6. Add `splitStatements:false` to any changeset with a plpgsql body, so Liquibase doesn't split it at the semicolons.
7. Never edit a changeset that has already run unless it is `runOnChange`. Add a new changeset instead, or Liquibase fails with a checksum error.
8. Add or update a test case for the object in `schema/tests/` (see [Writing tests](#writing-tests)).

### Writing tests

Test cases live in [schema/tests/](schema/tests/), in the same folders as the objects they test, one file per object named `<object>_test.sql`. For example, `schema/procedures/place_order.sql` is tested by `schema/tests/procedures/place_order_test.sql`.

Deploy schema runs every `.sql` file under `schema/tests/` with [pipelines/test/run-sql-tests.sh](pipelines/test/run-sql-tests.sh): on the ephemeral database after the schema has been applied, rolled back and applied again, and on dev and qa after each deploy. They never run against prod. There's nothing to register: a new file is picked up automatically. Test files aren't Liquibase changesets, so don't list them in `changelog.yaml`. They aren't linted either.

How a test file works:

- **Plain SQL.** Each file runs in its own transaction, which is rolled back afterwards, so tests can't see each other's data and don't need to clean up.
- **A test fails when any statement errors.** Use `RAISE EXCEPTION` in a `DO` block for a failed check.
- **Make test data unique** (e.g. emails like `test.<object>@example.com`), so a test doesn't depend on other rows.
- **Don't use `COMMIT` or `ROLLBACK`.** The runner handles the transaction.

A check that something works:

```sql
CALL place_order(cid, 42.50);
IF NOT EXISTS (SELECT 1 FROM orders WHERE customer_id = cid AND status = 'pending') THEN
    RAISE EXCEPTION 'place_order did not create a pending order';
END IF;
```

A check that something is rejected. Catch the expected error in an inner block; any other error, or no error, fails the test:

```sql
BEGIN
    INSERT INTO orders (customer_id, status, total_amount) VALUES (cid, 'lost', 10);
    RAISE EXCEPTION 'an invalid status was accepted';
EXCEPTION WHEN check_violation THEN
    NULL;  -- expected
END;
```

Both snippets go inside a `DO $$ ... END $$;` block. See the [sample tests](schema/tests/) for complete files.

`now()` stays the same for the whole transaction. To test something time-based, such as a trigger that sets `updated_at`, insert the row with an old timestamp first, then check that it changed (see [trg_orders_updated_at_test.sql](schema/tests/triggers/trg_orders_updated_at_test.sql)).

To run the tests against your own database, set `PGHOST`, `PGDATABASE`, `PGUSER` and `PGPASSWORD`, then run `bash pipelines/test/run-sql-tests.sh` from the repo root. Each file's changes are rolled back, but use a disposable database anyway.

### Objects that already exist

Liquibase only knows about changes it applied itself. If an object was created some other way (by hand, or before you adopted Liquibase), its `CREATE` will fail. Either run `liquibase changelog-sync` once against that database to mark the changelog as already applied, or guard the changeset with a precondition:

```sql
--changeset you:create-table-legacy
--preconditions onFail:MARK_RAN
--precondition-sql-check expectedResult:0 SELECT count(*) FROM pg_tables WHERE schemaname = 'public' AND tablename = 'legacy'
CREATE TABLE legacy (...);
```

## Linting schema changes

The [Lint schema](.github/workflows/lint-schema.yml) workflow checks schema SQL files. It runs:

- as the first job of every [Deploy schema](#deploying-schema-changes) run, checking the files a pull request adds or changes, or every file on a manual deploy
- on its own for pull requests that change the lint code or rules (`pipelines/lint/`, `.squawk.toml`)
- manually from Actions → Lint schema → Run workflow, checking every file

[pipelines/lint/lint-schema.sh](pipelines/lint/lint-schema.sh) has its own rules, and also runs [Squawk](https://squawkhq.com/docs/rules), a Postgres migration linter, as a second layer.

**Policy rules** fail the PR:

| Rule | Flags |
|---|---|
| `missing-rollback` | A changeset without a `--rollback`. Use `--rollback empty` when a change can't be undone |
| `concurrent-in-transaction` | `CREATE`/`DROP INDEX CONCURRENTLY` in a changeset without `runInTransaction:false` |

**Risk rules** set the job's `risk-level` output to `high` but don't fail the PR:

| Rule | Flags | Why it's risky |
|---|---|---|
| `drop-table` | `DROP TABLE` | Data loss; breaks code still using the table |
| `drop-column` | `ALTER TABLE ... DROP [COLUMN]` | Data loss; breaks code still using the column |
| `change-column-type` | `ALTER COLUMN ... TYPE` | Usually rewrites the table under an exclusive lock |
| `set-not-null` | `ALTER COLUMN ... SET NOT NULL` | Scans the table under an exclusive lock |
| `validating-constraint` | `ADD FOREIGN KEY` or `CHECK` without `NOT VALID` | Scans the table under lock to validate |
| `unique-constraint-without-index` | `ADD UNIQUE` or `PRIMARY KEY` without `USING INDEX` | Builds the index under an exclusive lock |
| `blocking-index` | `CREATE INDEX` without `CONCURRENTLY` | Blocks writes while the index builds. Not flagged for a table created in the same changeset |
| `foreign-key-without-index` | A foreign key column with no index starting with it | Deletes and key updates on the referenced table scan this table |
| Squawk rules | See the [Squawk rule list](https://squawkhq.com/docs/rules) | Overlaps the rules above and adds more, such as renames and new columns with volatile defaults |

Changesets with `splitStatements:false` (procedures, functions and other plpgsql bodies) are not checked for risk rules, because their statements are code that runs later, not schema changes.

With no findings, `risk-level` is `low`. Jobs in Deploy schema, or any workflow that calls Lint schema, can read it as `needs.lint.outputs.risk-level`, for example to require DBA review only for high-risk changes. The run summary shows the risk level and the number of policy violations.

### Running it locally

```bash
npm install --global squawk-cli@1
bash pipelines/lint/lint-schema.sh schema/tables/orders.sql
```

Without Squawk installed, `SKIP_SQUAWK=1 bash pipelines/lint/lint-schema.sh <files>` runs only this repo's own rules. Each finding is labelled with its rule name, e.g. `[drop-column]`.

### Adding or disabling rules

Step-by-step instructions, with a worked example, are in [docs/README.md](docs/README.md). In short:

- **Turn off one of this repo's rules:** add its name to [pipelines/lint/disabled-rules.txt](pipelines/lint/disabled-rules.txt) with a comment saying why, and remove it from the expected list in `test-lint.sh`.
- **Turn off a Squawk rule:** add its name to `excluded_rules` in [.squawk.toml](.squawk.toml) with a comment saying why. `prefer-robust-stmts` is already off, because this repo deliberately avoids `IF NOT EXISTS` (see [Objects that already exist](#objects-that-already-exist)).
- **Add a rule:** detect it in `changesets.awk`, give it a message in `lint-schema.sh`, add a sample changeset that triggers it, and add it to the expected list in `test-lint.sh`.
- **Test:** `SKIP_SQUAWK=1 bash pipelines/lint/test-lint.sh`. The workflow runs the same self-test before every lint, so a rule that stops firing fails the PR.

## Bootstrapping a database

The [Bootstrap database](.github/workflows/bootstrap-database.yml) workflow uses Liquibase to create a login role and an application database owned by that role. It connects to the instance's `postgres` maintenance database and runs [infra/postgres/changelog.yaml](infra/postgres/changelog.yaml). Both changes are skipped if the role or database already exists, so the workflow is safe to rerun.

| Trigger | What it does |
|---|---|
| Pull request touching `infra/postgres/` | Runs the changelog twice against a throwaway Postgres 16 container and checks that the role owns the database |
| Manual run with target `ephemeral` (default) | Same as a pull request, using the database and owner names you enter. No secrets needed |
| Manual run with target `instance` | Runs the changelog against the instance for the chosen GitHub environment |

Manual runs start from Actions → Bootstrap database → Run workflow.

### Setup for `instance` runs

Create a GitHub environment (e.g. `dev`) under Settings → Environments and add these secrets:

| Secret | Purpose |
|---|---|
| `DB_HOST` | Hostname of the Postgres instance |
| `DB_PORT` | Port (optional, defaults to `5432`) |
| `DB_ADMIN_USER` | Existing role Liquibase connects as; needs `CREATEROLE` and `CREATEDB` (or superuser) |
| `DB_ADMIN_PASSWORD` | Password for `DB_ADMIN_USER` |
| `DB_OWNER_PASSWORD` | Password given to the new owner role |

Add them as **environment secrets**, not environment variables; the workflow reads `secrets.*`.

Or, with the [GitHub CLI](https://cli.github.com/) installed (`winget install GitHub.cli`, then `gh auth login`):

```bash
gh secret set DB_HOST --env dev
gh secret set DB_ADMIN_USER --env dev
gh secret set DB_ADMIN_PASSWORD --env dev
gh secret set DB_OWNER_PASSWORD --env dev
```

Each command prompts for the value, so it doesn't end up in your shell history.

The database name and owner role are workflow inputs and default to `app_db` and `app_user`.

### Notes

- The instance must be reachable from the runner. For a private instance, use a self-hosted runner.
- Liquibase creates its `DATABASECHANGELOG` tracking tables in the `postgres` database.
- Changing `DB_OWNER_PASSWORD` after the first run changes the role changeset's checksum. Rotate the password with `ALTER ROLE` outside this workflow.
- The changesets have no rollback, so the pipeline never drops a database.

### Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `Secret DB_HOST is not set in environment 'dev'` | The secrets are missing, saved as variables, or saved under a different environment name. Add them as environment secrets to the environment you select |
| `Connect timed out` | GitHub-hosted runners can't reach the instance (local machine, VM or private network, or a firewall blocking port 5432). To test a changelog without a reachable database, use target `ephemeral` for Bootstrap database, or open a PR for Deploy schema. Otherwise point `DB_HOST` at an instance reachable from the internet, or use a self-hosted runner |
| A fix to the workflow has no effect | **Re-run jobs** reuses the workflow file from the original run. Push the fix and start a new run from Run workflow |
| Log shows `jdbc:***ql://***` | GitHub masks secret values wherever they appear. If a secret is `postgres`, it is also masked inside `postgresql`. This is harmless |
