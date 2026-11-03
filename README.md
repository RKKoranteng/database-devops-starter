# database-devops-starter

A starter template for DBA teams who want to ship database changes the same way developers ship code: small, frequent, tested and automated. It provides pipelines to validate, deploy, roll back and measure database changes with DORA metrics, so DBAs can move from gatekeepers to enablers who help developers deliver faster and keep the user experience great.

## Repository structure

```
database-devops-starter/
├── .github/
│   └── workflows/    # GitHub Actions workflows
├── infra/            # Infrastructure specific code
│   └── postgres/     # Liquibase changelog that creates the owner role and database
├── pipelines/        # Pipelines for validating, deploying and rolling back changes
├── schema/           # Schema definitions (tables, indexes, triggers, etc)
│   ├── changelog.yaml    # Liquibase master changelog listing which files run, in order
│   ├── sequences/
│   ├── tables/
│   ├── indexes/
│   ├── views/
│   ├── procedures/
│   └── triggers/
├── .gitignore        # Files and folders Git should ignore
├── CHANGELOG.md      # Release history and notes
├── LICENSE           # MIT License
└── README.md         # Project overview (this file)
```

## Deploying schema changes

The [Deploy schema](.github/workflows/deploy-schema.yml) workflow uses Liquibase to apply [schema/changelog.yaml](schema/changelog.yaml) to the application database. Only the files listed in the changelog run, top to bottom, so other SQL files in `schema/` are ignored. Liquibase records each applied changeset in its `DATABASECHANGELOG` table and skips it on later runs, so each deploy only applies new changes.

| Trigger | What it does |
|---|---|
| Pull request touching `schema/` | Applies the changelog to a throwaway Postgres 16 container, rolls every change back, applies it again, then runs a smoke test against the sample objects |
| Manual run with target `ephemeral` (default) | Same as a pull request. No secrets needed |
| Manual run with target `instance` | Shows pending changes, then applies them to the instance for the chosen GitHub environment, connecting as the owner role |

`instance` runs need `DB_HOST` and `DB_OWNER_PASSWORD` (plus `DB_PORT` if not 5432) in the environment, and the database must already exist, so run [Bootstrap database](#bootstrapping-a-database) first.

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
4. Tables and indexes: never edit or drop and recreate them. Change them with a new changeset (`ALTER TABLE`, `CREATE INDEX`), so data is kept.
5. Views, procedures, functions and triggers: use `CREATE OR REPLACE` with `runOnChange:true`, then edit the file in place for later changes (`CREATE OR REPLACE TRIGGER` needs Postgres 14+). Add a `DROP ... IF EXISTS` before the `CREATE` in the same changeset only when `OR REPLACE` can't do the change: when you remove, rename or reorder a view's columns, or change a procedure's or function's parameters, which would otherwise create a second version alongside the old one.
6. Add `splitStatements:false` to any changeset with a plpgsql body, so Liquibase doesn't split it at the semicolons.
7. Never edit a changeset that has already run unless it is `runOnChange`. Add a new changeset instead, or Liquibase fails with a checksum error.

### Objects that already exist

Liquibase only knows about changes it applied itself. If an object was created some other way (by hand, or before you adopted Liquibase), its `CREATE` will fail. Either run `liquibase changelog-sync` once against that database to mark the changelog as already applied, or guard the changeset with a precondition:

```sql
--changeset you:create-table-legacy
--preconditions onFail:MARK_RAN
--precondition-sql-check expectedResult:0 SELECT count(*) FROM pg_tables WHERE schemaname = 'public' AND tablename = 'legacy'
CREATE TABLE legacy (...);
```

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
| `Connect timed out` | GitHub-hosted runners can't reach the instance (local machine, VM or private network, or a firewall blocking port 5432). Use target `ephemeral` to test the changelog, or point `DB_HOST` at an instance reachable from the internet |
| A fix to the workflow has no effect | **Re-run jobs** reuses the workflow file from the original run. Push the fix and start a new run from Run workflow |
| Log shows `jdbc:***ql://***` | GitHub masks secret values wherever they appear. If a secret is `postgres`, it is also masked inside `postgresql`. This is harmless |