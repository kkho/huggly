# 1. Terraform state backend

Date: 2026-11-01
Status: Accepted

## Context

Terraform keeps a state file that records what it has created. On every `plan` it compares the code with that state to work out what to add, change or destroy. If the state is lost, Terraform forgets what it created: it tries to create everything again, and the existing resources have to be cleaned up by hand.

Huggly deletes and recreates `huggly-outputs/<environment>/<system>/` on every compile ([CompileCommand.cs](../../src/Huggly.CLI/Commands/CompileCommand.cs)). Terraform's default is to keep the state in the folder it runs in, so with no backend configured the state would be deleted by the next compile. Every generated system therefore needs a backend that stores the state somewhere a compile never touches.

Right now Huggly has one user, deploying from one PC. Later, other people should be able to use it for their own systems, and CI may run `plan` and `apply`.

## Options

| Option | Where the state lives | Pros | Cons |
|---|---|---|---|
| No backend | The output folder | Nothing to set up | Deleted on every compile. Not usable |
| Local file outside the output folder | `huggly-outputs/.tfstate/<system>/<environment>.tfstate` | No accounts or setup | Only on one PC, no locking, CI can't use it |
| Terraform Cloud (`cloud` block) | app.terraform.io, one workspace per system and environment | Shared, locked, works from CI | Needs an account, an organization and an API token |
| Azure Storage (`azurerm` backend) | A storage account in Azure | Shared, locked, works from CI | We would create and run the storage account, RBAC and versioning ourselves. Not chosen: we want Terraform (HCP Terraform) to manage the state for us |

## Decision

Support both the local file and Terraform Cloud, chosen with the `state_backend` key under `data:` in the system YAML:

- `local` (the default when `state_backend` is missing): `backend "local"` with the path `../../.tfstate/<system>/<environment>.tfstate`, relative to the output folder. This resolves to `huggly-outputs/.tfstate/`, which compile never deletes.
- `remote`: a `cloud` block using `terraform_cloud_organization` and `terraform_cloud_workspace`. The workspace is set per landing zone and must be unique per system and environment, for example `conferenti-prod`. Two environments or systems with the same workspace would share, and overwrite, one state.

Because `data:` can be overridden per landing zone, a system can keep dev local and send prod to Terraform Cloud.

Use local for development and debugging now. Move a system to Terraform Cloud when other people use Huggly for their systems, or when CI should deploy.

## Consequences

- Development needs no accounts or credentials.
- **Local state exists only on one PC.** Deleting the whole `huggly-outputs/` folder, or losing the PC, loses the state. `.tfstate/` must never be committed: it is covered by `huggly-outputs/*` and `*.tfstate` in `.gitignore`.
- Local state has no locking. Don't run two `plan` or `apply` commands for the same system and environment at the same time.
- CI only validates the backend a system actually uses (`terraform init -backend=false` skips the backend). Until a system uses `remote`, the Terraform Cloud branch of the template is only checked by reading its output.
- A misspelled value such as `state_backend: remte` falls back to local without an error. A missing `terraform_cloud_workspace` renders an empty workspace name.
- The sample system Conferenti uses `remote` for test and prod to show that both branches generate. Its organization and workspaces don't exist in HCP Terraform, so only dev can be planned and applied until they are created.
- Moving a system from local to Terraform Cloud later means migrating its existing state (`terraform init -migrate-state`), not just changing the YAML.
- [DEPLOY.md](../DEPLOY.md) describes the azurerm setup and must be updated to match this decision.
