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
- liquibase schema changelog (`schema/changelog.yaml`) that applies each schema folder in dependency order
- sample schema objects, each with a rollback : 
    - tables : customers, orders
    - indexes : orders by customer, orders by status and created date
    - views : customer_order_summary
    - procedures : place_order
    - triggers : set_updated_at on customers and orders
- `Deploy schema` github actions workflow : 
    - on pull requests, applies the changelog to a throwaway postgres container, rolls it back, applies it again and runs a smoke test
    - manual trigger with a `target` choice : `ephemeral` or `instance`
- readme section on deploying schema changes and adding new ones

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