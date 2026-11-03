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
├── .gitignore        # Files and folders Git should ignore
├── CHANGELOG.md      # Release history and notes
├── LICENSE           # MIT License
└── README.md         # Project overview (this file)
```

## Bootstrapping a database

The [Bootstrap database](.github/workflows/bootstrap-database.yml) workflow uses Liquibase to create a login role and an application database owned by that role. It connects to the instance's `postgres` maintenance database and runs [infra/postgres/changelog.yaml](infra/postgres/changelog.yaml). Both changes are skipped if the role or database already exists, so the workflow is safe to rerun.

| Trigger | What it does |
|---|---|
| Pull request touching `infra/postgres/` | Runs the changelog twice against a throwaway Postgres 16 container and checks that the role owns the database |
| Manual run (Actions → Bootstrap database → Run workflow) | Runs the changelog against the instance for the chosen GitHub environment |

### Setup for manual runs

Create a GitHub environment (e.g. `dev`) under Settings → Environments and add these secrets:

| Secret | Purpose |
|---|---|
| `DB_HOST` | Hostname of the Postgres instance |
| `DB_PORT` | Port (optional, defaults to `5432`) |
| `DB_ADMIN_USER` | Existing role Liquibase connects as; needs `CREATEROLE` and `CREATEDB` (or superuser) |
| `DB_ADMIN_PASSWORD` | Password for `DB_ADMIN_USER` |
| `DB_OWNER_PASSWORD` | Password given to the new owner role |

The database name and owner role are workflow inputs and default to `app_db` and `app_user`.

### Notes

- The instance must be reachable from the runner. For a private instance, use a self-hosted runner.
- Liquibase creates its `DATABASECHANGELOG` tracking tables in the `postgres` database.
- Changing `DB_OWNER_PASSWORD` after the first run changes the role changeset's checksum. Rotate the password with `ALTER ROLE` outside this workflow.
- The changesets have no rollback, so the pipeline never drops a database.