# Validate, plan and apply

How to go from YAML definitions to resources in Azure, safely. Every change goes through the same steps:

```
scripts/check.sh  →  compile  →  terraform init  →  terraform plan  →  read the plan  →  terraform apply
   (no Azure)                         (Azure from here on)
```

Each step catches a different kind of mistake, so the cheap ones run first:

| Step | Catches | Needs Azure? |
|---|---|---|
| `dotnet build` | C# errors in Huggly | No |
| `huggly compile` | Bad YAML, unknown kinds, Scriban template errors | No |
| `terraform init -backend=false` | Broken `terraform {}` block, duplicate `required_providers`, providers that can't be found | No |
| `terraform validate` | Wrong attribute names, missing required fields, wrong types | No |
| `terraform plan` | Wrong subscription, missing permissions, no access to the state storage | Yes |
| `terraform apply` | Names already taken, quota limits, VM sizes not available in the region, Azure Policy denies | Yes |

`validate` only checks that the Terraform is well formed for the azurerm provider, not that Azure will accept it. A storage account name someone else already owns passes `validate` and fails at `apply`.

Commands are for **Git Bash** and run from the repository root (`D:\Hobby\huggly`). The `az` and `terraform` lines work unchanged in cmd and PowerShell if you run them one per line.

> **Before you can plan:** the generated `backend.tf` must be the azurerm backend, and `versions.tf` must list only the providers the output uses. Until those template fixes are merged, only step 1 works.

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

## 2. One-time Azure setup

You only do this once per subscription.

### Sign in

```bash
az login
az account set --subscription <subscription-id>
az account show --query "{name:name, id:id}" -o table
```

Always check the last command before running `plan` or `apply`. It shows which subscription `az` is signed in to.

### Create the state storage

Terraform keeps its state (what it has created) in a storage account. Huggly doesn't create this account, because Terraform needs it before it can run. Create it by hand:

```bash
STATE_RG=rg-huggly-tfstate
STATE_SA=sthugglytfstate$RANDOM     # globally unique, 3-24 lowercase letters and digits
echo $STATE_SA                       # write this name down

az group create --name $STATE_RG --location norwayeast

az storage account create --name $STATE_SA --resource-group $STATE_RG --location norwayeast \
  --sku Standard_LRS --min-tls-version TLS1_2 --allow-blob-public-access false

az storage account blob-service-properties update --account-name $STATE_SA --resource-group $STATE_RG \
  --enable-versioning true
```

Versioning keeps old copies of the state file, so you can recover if it's ever corrupted.

### Give yourself access to the state

The backend signs in with your Azure account (`use_azuread_auth = true`), not a storage key. Your account needs the **Storage Blob Data Contributor** role on the storage account. Being the subscription owner isn't enough, because Owner doesn't include reading blob data.

```bash
ME=$(az ad signed-in-user show --query id -o tsv)
SCOPE=$(az storage account show --name $STATE_SA --resource-group $STATE_RG --query id -o tsv)
MSYS_NO_PATHCONV=1 az role assignment create --role "Storage Blob Data Contributor" --assignee $ME --scope $SCOPE

az storage container create --name tfstate --account-name $STATE_SA --auth-mode login
```

`MSYS_NO_PATHCONV=1` stops Git Bash from turning `/subscriptions/...` into a Windows path. The role can take a few minutes to apply. If creating the container fails with `AuthorizationPermissionMismatch`, wait and try again.

### Point the system at it

In the system YAML, for example `src/huggly-templates/Systems/Conferenti/Conferenti.yaml`, set your real subscription and the state storage under `data:`:

```yaml
data:
  location: norwayeast
  subscription_id: <subscription-id>
  state_resource_group: rg-huggly-tfstate
  state_storage_account: <the STATE_SA name>
```

The container defaults to `tfstate`, and the state subscription defaults to `subscription_id`. Override them with `state_container` and `state_subscription_id` if needed. Each environment gets its own state file, for example `conferenti/dev.tfstate`.

A subscription ID is not a secret, but this repository is public. If you'd rather not publish it, keep the real value in an uncommitted copy of the system folder.

## 3. Plan and apply an environment

Run `scripts/check.sh` first. Then, for one environment:

```bash
dotnet run --project src/Huggly.CLI -- compile --definitions src/huggly-templates/Systems/Conferenti --environment dev --output huggly-outputs

cd huggly-outputs/dev/Conferenti
az account show --query "{name:name, id:id}" -o table
terraform init
terraform plan -out=tfplan
```

`terraform init` here is without `-backend=false`, so it connects to the state storage. `plan -out=tfplan` saves the plan to a file.

### Read the plan

The last line sums it up:

```
Plan: 3 to add, 1 to change, 0 to destroy.
```

Then look through the resources:

| Symbol | Meaning |
|---|---|
| `+` | create |
| `~` | change in place |
| `-` | **destroy** |
| `-/+` | **destroy and recreate** (marked `must be replaced`) |

Stop and find out why before applying if you see:

- anything being destroyed or replaced that you didn't mean to remove. A replaced database or storage account loses its data;
- everything being created again although it's already deployed. The state file wasn't found, so check the `state_*` values and the environment;
- changes you didn't make. Someone changed the resource in the portal, and applying will undo their change.

### Apply

```bash
terraform apply tfplan
```

This applies exactly the plan you just read, without asking again. If you run plain `terraform apply` instead, Terraform makes a new plan, which may differ from the one you read.

Go back to the repository root with `cd ../../..` when you're done.

### Rules

- **Don't compile between plan and apply.** Compiling deletes the whole output folder, including `tfplan` and `.terraform`. If you recompile, run `init` and `plan` again. Deleting the folder is otherwise safe, because the state lives in Azure.
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

The state storage isn't managed by Terraform. When you no longer need any environment, remove it with `az group delete --name rg-huggly-tfstate`. Destroy every environment first, or you lose track of what they created.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Backend initialization required` | You compiled again since the last `init` | Run `terraform init` |
| `AuthorizationPermissionMismatch` or 403 during `init` | No Storage Blob Data Contributor role, or it hasn't applied yet | Assign the role as in step 2, wait a few minutes |
| `subscription ID could not be determined` or a subscription not found | `subscription_id` in the YAML is still the `0000...` placeholder | Set the real subscription ID |
| `AADSTS...` or `token expired` | Your `az login` session expired | `az login` |
| `Error acquiring the state lock` | Another `plan`/`apply` is running, or one crashed | Wait for it. If you're sure nothing else is running, `terraform force-unlock <lock-id>` |
| `StorageAccountAlreadyTaken` or another name conflict | Some names are globally unique across all of Azure | Choose a different name in the YAML |
| `SkuNotAvailable` or a quota error | The VM size isn't offered in the region, or your subscription's limit is reached | Choose another size, or request a quota increase in the portal |
| The plan creates everything again | Terraform can't find the existing state | Check `state_resource_group`, `state_storage_account` and `--environment` |
