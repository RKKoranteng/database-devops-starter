# database-devops-starter

A starter template for DBA teams who want to ship database changes the same way developers ship code: small, frequent, tested and automated. It provides pipelines to validate, deploy, roll back and measure database changes with DORA metrics, so DBAs can move from gatekeepers to enablers who help developers deliver faster and keep the user experience great.

## Repository structure

```
database-devops-starter/
├── infra/            # Infrastructure specific code
├── pipelines/        # Pipelines for validating, deploying and rolling back changes
├── schema/           # Schema definitions (tables, indexes, triggers, etc)
├── .gitignore        # Files and folders Git should ignore
├── CHANGELOG.md      # Release history and notes
├── LICENSE           # MIT License
└── README.md         # Project overview (this file)
```