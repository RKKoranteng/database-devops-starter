# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Calendar Versioning](https://calver.org/) (YYYY.MM.DD).

## [Unreleased]

### Added
- liquibase changelog (`infra/postgres/`) to create the owner role and application database, safe to rerun
- `Bootstrap database` github actions workflow : 
    - validates the changelog on pull requests against a throwaway postgres container
    - runs the changelog against a target instance on manual trigger
- readme section on bootstrapping a database and the secrets it needs

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