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