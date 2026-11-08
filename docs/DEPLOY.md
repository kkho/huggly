# Validate, plan and apply

How to go from YAML definitions to resources in Azure, safely. Every change goes through the same steps:

```
scripts/check.sh  →  compile  →  terraform init  →  terraform plan  →  read the plan  →  terraform apply
   (no Azure)                         (Azure from here on)
```

Each step catches a different kind of mistake, so the cheap ones run first:

| Step                            | Catches                                                                                            | Needs Azure? |
| ------------------------------- | -------------------------------------------------------------------------------------------------- | ------------ |
| `dotnet build`                  | C# errors in Huggly                                                                                | No           |
| `huggly compile`                | Bad YAML, unknown kinds, Scriban template errors                                                   | No           |
| `terraform init -backend=false` | Broken `terraform {}` block, duplicate `required_providers`, providers that can't be found         | No           |
| `terraform validate`            | Wrong attribute names, missing required fields, wrong types                                        | No           |
| `terraform plan`                | Wrong subscription, missing permissions, no access to the state (HCP Terraform login or workspace) | Yes          |
| `terraform apply`               | Names already taken, quota limits, VM sizes not available in the region, Azure Policy denies       | Yes          |

`validate` only checks that the Terraform is well formed for the azurerm provider, not that Azure will accept it. A storage account name someone else already owns passes `validate` and fails at `apply`.

Commands are for **Git Bash** and run from the repository root (`D:\Hobby\huggly`). The `az` and `terraform` lines work unchanged in cmd and PowerShell if you run them one per line.

> **Which environments can be planned:** only those whose state backend exists. Conferenti's `dev` uses `local` state and can be planned as soon as you've signed in to Azure. Its `test` and `prod` use `remote` with a demo organization and workspaces that don't exist in HCP Terraform, so `terraform init` fails for them until you create them as in [step 2](#remote-hcp-terraform).

## 1. Run the check (no Azure needed)

```bash
scripts/check.sh               # checks Conferenti
scripts/check.sh <System>      # checks another system in src/huggly-templates/Systems/
```

The script builds Huggly, then for `dev`, `test` and `prod` it compiles the system and runs `terraform init -backend=false` and `terraform validate` on the output. It stops at the first failure:

```
CHECK FAILED - terraform validate (prod)
```

The name in brackets tells you which step and environment failed, and the error above it says why. On success it ends with `All environments compile and validate.`

Run it after every template or YAML change, before you commit.

It must run in Git Bash. From cmd or PowerShell, run `"C:\Program Files\Git\bin\bash.exe" scripts/check.sh`. Plain `bash` may start WSL instead, where `dotnet` isn't installed.

## 2. One-time setup

### Sign in to Azure

```bash
az login
az account set --subscription <subscription-id>
az account show --query "{name:name, id:id}" -o table
```

Always check the last command before running `plan` or `apply`. It shows which subscription `az` is signed in to.

### Point the system at your subscription

In the system YAML, for example `src/huggly-templates/Systems/Conferenti/Conferenti.yaml`, set your real subscription under `data:`:

```yaml
data:
  location: norwayeast
  subscription_id: <subscription-id>
```

A subscription ID is not a secret, but this repository is public. If you'd rather not publish it, keep the real value in an uncommitted copy of the system folder.

### Choose where the state lives

Terraform keeps its state (what it has created) in a file. If the state is lost, Terraform forgets what it created and tries to create everything again. Each system chooses where its state lives with `state_backend` under `data:`. Like any `data:` key, it can be overridden per landing zone, so `dev` can stay local while `prod` uses HCP Terraform. [ADR 0001](decisions/0001-terraform-state-backend.md) explains why these two options were chosen.

| `state_backend`     | Where the state lives                                    | Setup                                                |
| ------------------- | -------------------------------------------------------- | ---------------------------------------------------- |
| `local` (default)   | `huggly-outputs/.tfstate/<system>/<environment>.tfstate` | None                                                 |
| `remote`            | An HCP Terraform workspace on app.terraform.io           | Account, organization, workspaces, `terraform login` |

#### Local

Nothing to set up. The generated `backend.tf` points two folders up from the output folder, for example `huggly-outputs/.tfstate/conferenti/dev.tfstate`. Compile only deletes `huggly-outputs/<environment>/<system>/`, so the state survives every compile.

- **The state only exists on this PC.** Deleting the whole `huggly-outputs/` folder, or losing the PC, loses it. If the resources matter, copy `huggly-outputs/.tfstate/` somewhere safe.
- **There is no locking.** Don't run two `plan` or `apply` commands for the same system and environment at the same time.
- It is never committed: `huggly-outputs/*` and `*.tfstate` are in `.gitignore`.

#### Remote (HCP Terraform)

Once:

1. Sign up at https://app.terraform.io and create an organization.
2. Sign in from your PC. This opens a browser and saves an API token in `%APPDATA%\terraform.d\credentials.tfrc.json`:

   ```bash
   terraform login
   ```

For each system and environment that should use remote state:

1. In HCP Terraform, create a workspace with the **CLI-driven workflow**. The name must be unique per system and environment, for example `conferenti-prod`. Two environments or systems that share a workspace overwrite each other's state.
2. In the workspace, open **Settings → General → Execution Mode** and choose **Local**. The default, Remote, runs `plan` on HCP Terraform's servers, which don't have your `az login`, and fails with Azure sign-in errors. With Local, Terraform runs on your PC and only the state is stored in HCP Terraform.
3. Set the backend in the system YAML:

   ```yaml
   data:
     terraform_cloud_organization: <your organization>
   landing-zone:
     prod:
       data:
         state_backend: remote
         terraform_cloud_workspace: conferenti-prod
   ```

#### Move a system from local to remote

Changing the YAML alone isn't enough. Terraform would start with an empty workspace, and the next plan would try to create everything again. Move the existing state as well:

1. Create the workspace as above.
2. Change `state_backend` and `terraform_cloud_workspace` in the YAML.
3. Compile, then in the output folder:

   ```bash
   terraform init -migrate-state
   ```

   Answer `yes` when Terraform asks to copy the existing state to the new backend.

4. Run `terraform plan`. It should say `No changes`. Then delete the old local file in `huggly-outputs/.tfstate/`.

## 3. Plan and apply an environment

Run `scripts/check.sh` first. Then, for one environment:

```bash
dotnet run --project src/Huggly.CLI -- compile --definitions src/huggly-templates/Systems/Conferenti --environment dev --output huggly-outputs

cd huggly-outputs/dev/Conferenti
az account show --query "{name:name, id:id}" -o table
terraform init
terraform plan -out=tfplan
```

`terraform init` here is without `-backend=false`, so it sets up the backend: the local state file, or the HCP Terraform workspace. `plan -out=tfplan` saves the plan to a file.

### Read the plan

The last line sums it up:

```
Plan: 3 to add, 1 to change, 0 to destroy.
```

Then look through the resources:

| Symbol | Meaning                                              |
| ------ | ---------------------------------------------------- |
| `+`    | create                                               |
| `~`    | change in place                                      |
| `-`    | **destroy**                                          |
| `-/+`  | **destroy and recreate** (marked `must be replaced`) |

Stop and find out why before applying if you see:

- anything being destroyed or replaced that you didn't mean to remove. A replaced database or storage account loses its data;
- everything being created again although it's already deployed. The state wasn't found, so check `state_backend`, the workspace name and `--environment`;
- changes you didn't make. Someone changed the resource in the portal, and applying will undo their change.

### Apply

```bash
terraform apply tfplan
```

This applies exactly the plan you just read, without asking again. If you run plain `terraform apply` instead, Terraform makes a new plan, which may differ from the one you read.

Go back to the repository root with `cd ../../..` when you're done.

### Rules

- **Don't compile between plan and apply.** Compiling deletes the whole output folder, including `tfplan` and `.terraform`. If you recompile, run `init` and `plan` again. Local state survives, because it's in `huggly-outputs/.tfstate/`, outside the folder compile deletes.
- **Never delete the whole `huggly-outputs/` folder** while a system with `local` state has resources in Azure. That deletes the state too.
- **Never edit the generated files.** Fix the template or the YAML, and compile again.
- **Go `dev` → `test` → `prod`**, and apply `prod` only from committed changes that have already been applied to `test`.

## 4. Tear down an environment

```bash
dotnet run --project src/Huggly.CLI -- compile --definitions src/huggly-templates/Systems/Conferenti --environment dev --output huggly-outputs
cd huggly-outputs/dev/Conferenti
terraform init
terraform plan -destroy -out=tfplan
terraform apply tfplan
```

Read the plan first, as above. Check that the environment in the path is the one you mean.

Once the environment is destroyed, its state records nothing and can be removed:

- **local:** delete `huggly-outputs/.tfstate/<system>/<environment>.tfstate` and its `.backup` file.
- **remote:** delete the workspace in HCP Terraform (**Settings → Destruction and Deletion**).

Always destroy first. Deleting the state of an environment that still has resources means Terraform loses track of them, and you have to remove them by hand in the portal.

## Troubleshooting

| Symptom                                                               | Cause                                                                                                  | Fix                                                                                                                                                       |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Backend initialization required`                                     | You compiled again since the last `init`                                                               | Run `terraform init`                                                                                                                                      |
| `Backend configuration changed`                                       | `state_backend` or the workspace changed since the last `init`                                         | To keep the state, `terraform init -migrate-state` (see [Move a system from local to remote](#move-a-system-from-local-to-remote))                        |
| `Required token could not be found`                                   | `remote` state, but you haven't signed in to HCP Terraform                                             | `terraform login`                                                                                                                                         |
| An organization or workspace error during `init`                      | The organization or workspace doesn't exist, or your token can't access it                             | Create them as in [step 2](#remote-hcp-terraform) and check the names in the YAML. Conferenti's `test` and `prod` point to a demo organization on purpose |
| `plan` runs in HCP Terraform and fails on Azure credentials           | The workspace's execution mode is Remote                                                               | Set **Execution Mode** to **Local** in the workspace settings                                                                                             |
| `subscription ID could not be determined` or a subscription not found | `subscription_id` in the YAML is still the `0000...` placeholder                                       | Set the real subscription ID                                                                                                                              |
| `AADSTS...` or `token expired`                                        | Your `az login` session expired                                                                        | `az login`                                                                                                                                                |
| `Error acquiring the state lock`                                      | Another `plan`/`apply` is running on the same HCP Terraform workspace, or one crashed. Local state has no lock | Wait for it. If you're sure nothing else is running, `terraform force-unlock <lock-id>`                                                           |
| `StorageAccountAlreadyTaken` or another name conflict                 | Some names are globally unique across all of Azure                                                     | Choose a different name in the YAML                                                                                                                       |
| `SkuNotAvailable` or a quota error                                    | The VM size isn't offered in the region, or your subscription's limit is reached                       | Choose another size, or request a quota increase in the portal                                                                                            |
| The plan creates everything again                                     | Terraform can't find the existing state                                                                | Check `state_backend`, the workspace name and `--environment`. For `local`, check that `huggly-outputs/.tfstate/` still exists                            |
