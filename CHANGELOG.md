# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Calendar Versioning](https://calver.org/) (YYYY.MM.DD).

## [Unreleased]

### Added
- liquibase changelog (`infra/postgres/`) to create the owner role and application database, safe to rerun
- `Bootstrap database` github actions workflow : 
    - validates the changelog on pull requests against a throwaway postgres container
    - manual trigger with a `target` choice : `ephemeral` (throwaway postgres container) or `instance` (real instance from environment secrets)
- readme section on bootstrapping a database and the secrets it needs
- readme troubleshooting table for missing secrets, connection timeouts, re-runs and masked log output
- liquibase schema changelog (`schema/changelog.yaml`) that applies only the files it lists, in dependency order. one object per schema file, named after the object
- sample schema objects, each with a rollback : 
    - tables : customers, orders
    - indexes : idx_orders_customer_id, idx_orders_status_created_at (built `CONCURRENTLY` so they don't block writes)
    - views : customer_order_summary
    - procedures : place_order
    - triggers : set_updated_at function, trg_customers_updated_at, trg_orders_updated_at (`CREATE OR REPLACE TRIGGER`, rerun on change, postgres 14+)
- `Deploy schema` github actions workflow : 
    - pipeline : lint > test in ephemeral environment > deploy to dev (+ unit tests) > deploy to qa (+ unit tests) > deploy to prod
    - test in ephemeral environment : initialize throwaway postgres, set up liquibase, update change, test rollback, re-apply change, unit tests (`schema/tests`), with a results table in the run summary
    - test rollback fails if any changeset record, table, view, index, sequence, procedure or function is left behind
    - pull requests run lint and the ephemeral test only. merges to main (and manual runs on main) run the whole pipeline
    - dev, qa and prod use github environments, so prod can require an approval. unit tests never run against prod
    - one run per branch at a time, so deploys never overlap
    - `deploy-environment.yml` reusable workflow : the deploy steps shared by dev, qa and prod
    - `pipelines/bin/liquibase` wrapper so workflow steps read as plain liquibase commands
- readme section on deploying schema changes and adding new ones
- `schema/tests/` : sql test cases, one `<object>_test.sql` per object, in the same folders as the schema : 
    - tables : customers (unique email, default timestamps), orders (default status, status and amount checks, foreign key)
    - indexes : idx_orders_customer_id, idx_orders_status_created_at (exist and are valid)
    - views : customer_order_summary (customers with and without orders)
    - procedures : place_order (creates a pending order, rejects a missing customer)
    - triggers : trg_customers_updated_at, trg_orders_updated_at (set updated_at on update)
- `pipelines/test/run-sql-tests.sh` : runs each test file in its own rolled-back transaction, marks the failing line in github and lists every test in the run summary
- readme section on writing tests
- schema lint skips `schema/tests/`
- `Lint schema` github actions workflow for changed schema files : 
    - policy checks that fail the PR : changeset without a rollback, `CONCURRENTLY` without `runInTransaction:false`
    - risk checks that set `risk-level` to high, built into the lint script so they work without squawk : dropped tables or columns, column type changes, `SET NOT NULL`, constraints added without `NOT VALID`, unique or primary keys added without `USING INDEX`, `CREATE INDEX` without `CONCURRENTLY`, foreign keys without an index
    - squawk rules as a second layer of risk checks
    - `risk-level` (low or high) job output for later jobs
    - runs as the first job of `Deploy schema`, so nothing is applied until lint passes. runs on its own for changes to the lint code or rules
- lint script, self-test and sample safe, risky and policy-violating changesets (`pipelines/lint/`). the self-test checks that every rule fires on its sample
- `pipelines/lint/disabled-rules.txt` to turn off lint rules
- `docs/README.md` : step-by-step guide to disabling, adding and changing lint rules, with a worked example
- squawk rule configuration (`.squawk.toml`)
- readme section on linting, and on adding or disabling rules
- `docs/` directory in the readme tree
- ignore personal claude code settings and hooks (`.claude/settings.local.json`, `.claude/hooks/`)

## [2026.10.31]

### Added
- add infrastructure directory
- add readme (intitial repo doc)
- changelog to document notable changes to the repository
- MIT license
- add .gitignore
- add pipeline directory
- add schema specific directories : 
    - indexes
    - procedures
    - sequences
    - tables
    - triggers
    - views

### Changes
- update directory tree in readme
- move schema directories as subdir inside the schema dir
- ignore gh-scripts