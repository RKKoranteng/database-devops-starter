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
    - on pull requests, applies the changelog to a throwaway postgres container, rolls it back, applies it again and runs a smoke test
    - manual trigger with a `target` choice : `ephemeral` or `instance`
- readme section on deploying schema changes and adding new ones
- `Lint schema` github actions workflow for changed schema files : 
    - policy checks that fail the PR : changeset without a rollback, `CONCURRENTLY` without `runInTransaction:false`
    - risk checks that set `risk-level` to high, built into the lint script so they work without squawk : dropped tables or columns, column type changes, `SET NOT NULL`, constraints added without `NOT VALID`, unique or primary keys added without `USING INDEX`, `CREATE INDEX` without `CONCURRENTLY`, foreign keys without an index
    - squawk rules as a second layer of risk checks
    - `risk-level` (low or high) job output for later jobs
    - runs as the first job of `Deploy schema`, so nothing is applied until lint passes. runs on its own for changes to the lint code or rules
- lint script, self-test and sample safe, risky and policy-violating changesets (`pipelines/lint/`). the self-test checks that every rule fires on its sample
- `pipelines/lint/disabled-rules.txt` to turn off lint rules
- squawk rule configuration (`.squawk.toml`)
- readme section on linting, and on adding or disabling rules

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