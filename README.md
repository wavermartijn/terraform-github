# GitHub Repository Management with OpenTofu

Manage GitHub repositories through YAML definitions and OpenTofu.

## Requirements

- [OpenTofu](https://opentofu.org/) >= 1.6.0
- GitHub personal access token with at least `repo` and `read:org` scopes

## Authentication

Export your GitHub token before running OpenTofu commands:

```powershell
$env:GITHUB_TOKEN = "ghp_..."
```

Or in bash:

```bash
export GITHUB_TOKEN="ghp_..."
```

The owner defaults to `wavermartijn` and can be changed via `var.github_owner` or the `-var` flag.

## Usage

1. Initialize OpenTofu:

   ```bash
   tofu init
   ```

2. Add a repository definition under `repos/` (see `repos/my-app-repo.yaml`).

3. Review the planned changes:

   ```bash
   tofu plan
   ```

4. Apply the configuration:

   ```bash
   tofu apply
   ```

## Repository YAML Schema

Each file in `repos/` must end with `.yaml`. The file name (without extension) is used as both the repository name and the OpenTofu map key.

```yaml
description: Example application repository managed by OpenTofu.
visibility: internal              # public | private | internal (internal requires an organization)
default_branch: main              # also accepts default-branch: main
auto_init: true                    # initializes the repo so the default branch exists
homepage_url: https://example.com
has_issues: true
has_projects: false
has_wiki: false
has_discussions: false
allow_merge_commit: true
allow_squash_merge: true
allow_rebase_merge: false
allow_auto_merge: false
delete_branch_on_merge: true
is_template: false
archived: false
topics:
  - opentofu
  - github
vulnerability_alerts: true
allowed_users:
  wavermartijn:
    owner: true                 # marks the user as owner; grants admin permission
    permission: admin
```

### Notes on `allowed_users`

- The repository owner (`var.github_owner`) is never added as a collaborator because they already own the repository.
- `owner: true` is treated as a marker; the actual GitHub permission used is the value of `permission` (default `push`).
- Valid `permission` values: `pull`, `triage`, `push`, `maintain`, `admin`.
- To use a repository template, add a `template` block:

  ```yaml
  template:
    owner: wavermartijn
    repository: template-repo
  ```

## Importing an Existing Repository

Use the provided script to import a repository that already exists on GitHub into the OpenTofu state.

### PowerShell (Windows)

```powershell
.\scripts\import_repo.ps1
```

### Bash (Linux / macOS / WSL / Git Bash)

```bash
bash scripts/import_repo.sh
```

The script prompts for the repository name and the GitHub owner (defaulting to `wavermartijn`), then imports:

- `github_repository.repos["<repo-name>"]`
- `github_branch_default.default["<repo-name>"]`
- `github_repository_vulnerability_alerts.alerts["<repo-name>"]`

The import ID is the repository name only (e.g., `my-app-repo`), because the GitHub provider owner is configured in `providers.tf`.

After importing, run `tofu plan` to ensure the remote configuration matches your YAML definition.

## Project Structure

```
.
├── main.tf              # Loads YAML files and creates GitHub resources
├── providers.tf         # GitHub provider and required version
├── variables.tf         # Input variables
├── outputs.tf           # Outputs for managed repositories
├── repos/               # Repository YAML definitions
│   └── my-app-repo.yaml
├── scripts/             # Helper scripts
│   ├── import_repo.ps1
│   └── import_repo.sh
└── README.md
```
