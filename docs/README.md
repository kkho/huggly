# Huggly setup and commands

This guide gets a Windows machine ready to build Huggly, compile the sample system into Terraform, and run a local Kubernetes cluster. All commands are for **PowerShell** and run from the repository root (`D:\Hobby\huggly`) unless a step says otherwise.

> **Commands are written for PowerShell.** Some use `;` and `$env:`, which cmd doesn't understand. In cmd, `kind create cluster --name x; kubectl get nodes` fails with `unknown command "kubectl"`. The local cluster steps also have a [cmd version](#using-cmd-instead-of-powershell).

## 1. Install the tools

| Tool | Needed for | Install |
|---|---|---|
| .NET 10 SDK | building and running the Huggly CLI | `winget install Microsoft.DotNet.SDK.10` |
| Terraform 1.5+ | validating generated output, local cluster | `winget install Hashicorp.Terraform` |
| kind | local Kubernetes cluster | `winget install Kubernetes.kind` |
| kubectl | talking to the cluster | `winget install Kubernetes.kubectl` |
| Podman **or** Docker Desktop | running the kind cluster | `winget install RedHat.Podman` or `winget install Docker.DockerDesktop` |
| Helm | optional, for inspecting charts by hand | `winget install Helm.Helm` |
| Azure CLI + kubelogin | only for deploying to real Azure | `winget install Microsoft.AzureCLI`, then `az aks install-cli` |

Open a new terminal after installing so the tools are on your `PATH`. Check them with:

```powershell
dotnet --version; terraform version; kind version; kubectl version --client
```

## 2. Prepare the container engine

kind runs each Kubernetes node as a container, so the engine must be running before you create a cluster.

**Podman** must run in rootful mode for kind:

```powershell
# first time only
podman machine init --rootful        # new machine
# or, for an existing machine:
podman machine stop; podman machine set --rootful

# every time you restart your PC
podman machine start
docker ps        # should print a (possibly empty) table, not an error
```

**Docker Desktop:** start the app, then run `docker context use desktop-linux`.

## 3. Build and compile Huggly

```powershell
dotnet build Huggly.CLI.slnx

dotnet run --project src/Huggly.CLI -- compile --definitions src/huggly-templates/Systems/Conferenti --environment dev --output huggly-outputs
```

The Terraform files are written to `huggly-outputs/<environment>/<system>/`, for example `huggly-outputs/dev/Conferenti/`. The folder is deleted and recreated on every compile.

| Option | Meaning | Default |
|---|---|---|
| `--definitions` | folder searched recursively for `*.yaml` definitions | `definitions` |
| `--environment` | landing zone to compile (`dev`, `test`, `prod`) | `dev` |
| `--output` | root folder for generated Terraform | `output` |

The defaults for `--definitions` and `--output` don't match this repository's folders, so always pass both.

### Check the generated Terraform

```powershell
cd huggly-outputs/dev/Conferenti
terraform init -backend=false
terraform validate
```

`-backend=false` skips the state backend, so you can validate without Azure or Terraform Cloud credentials.

To check every environment at once, run `scripts/check.sh` in Git Bash. See [Validate, plan and apply](DEPLOY.md#1-run-the-check-no-azure-needed). The same script runs in GitHub Actions ([`.github/workflows/check.yml`](../.github/workflows/check.yml)) on every pull request and push to `main`, with Terraform pinned to the version in that file. When you upgrade Terraform locally, update the pin too.

## 4. Run a local Kubernetes cluster

[`src/Huggly.Core/Templates/Files/local-k8s/main.tf`](../src/Huggly.Core/Templates/Files/local-k8s/main.tf) is a hand-written Terraform configuration that creates a kind cluster named `huggly-local` (one control-plane node, one worker) and installs Argo CD with Helm. Huggly doesn't generate this file. It's a local stand-in for AKS while you work on the templates.

Optional smoke test, to confirm kind works with your engine:

```powershell
kind create cluster --name smoke
kubectl get nodes
kind delete cluster --name smoke
```

Create the cluster:

```powershell
cd src/Huggly.Core/Templates/Files/local-k8s
terraform init
terraform apply
```

Connect and check that both nodes are `Ready`:

```powershell
$env:KUBECONFIG = terraform output -raw kubeconfig_path
kubectl get nodes
```

Open Argo CD:

```powershell
terraform output -raw argocd_admin_password
kubectl -n argocd port-forward svc/argocd-server 8081:80
```

Then browse to http://localhost:8081 and sign in as `admin` with that password. Port 8081 is used because the cluster already maps port 8080 on your PC to the cluster's node port 30080.

Tear it down:

```powershell
terraform destroy
```

`terraform init` creates `.terraform.lock.hcl` in this folder. Commit it so everyone uses the same provider versions. `.terraform/`, `*.tfstate` and the `huggly-local-config` kubeconfig (it holds cluster-admin credentials) are already in `.gitignore`.

### Using cmd instead of PowerShell

The same steps in cmd. Only setting `KUBECONFIG` looks different:

```bat
podman machine start
docker ps

cd /d D:\Hobby\huggly\src\Huggly.Core\Templates\Files\local-k8s
terraform init
terraform apply

for /f "delims=" %i in ('terraform output -raw kubeconfig_path') do set "KUBECONFIG=%i"
kubectl get nodes

terraform output -raw argocd_admin_password
kubectl -n argocd port-forward svc/argocd-server 8081:80
```

- Run one command per line, or join them with `&&`. `;` doesn't separate commands in cmd.
- `set KUBECONFIG` only lasts for that cmd window. Run the `for /f` line again in each new window.
- Inside a `.bat` file, write `%%i` instead of `%i`.

### Deploy something with Argo CD

Once the cluster is running, follow the [Argo CD hello example](../examples/kubernetes/deploy/local/README.md) to deploy a namespace and pods from this repository with Argo CD.

### After restarting your PC

kind clusters don't come back after the container engine restarts; their containers stay stopped. Start the engine, then recreate the cluster:

```powershell
podman machine start
cd src/Huggly.Core/Templates/Files/local-k8s
terraform destroy
terraform apply
```

## 5. Deploying to Azure (later)

See [Validate, plan and apply](DEPLOY.md) for the one-time Azure setup (sign-in, state storage, permissions) and how to plan, apply and tear down an environment.

Huggly can't generate AKS yet: the `KubernetesCluster` kind isn't wired into the compiler. Once it is, connect to a deployed cluster with `az aks get-credentials`.

## Naming rules

**In `.scriban` templates, every variable is snake_case.** Where a name comes from decides how you write it in YAML:

| Value comes from | In YAML | In the template | Why |
|---|---|---|---|
| Added by the compiler (`BuildModel` in [CompileCommand.cs](../src/Huggly.CLI/Commands/CompileCommand.cs)) | n/a | `system_name`, `environment` | Set as snake_case model keys |
| Keys under `data:` in a system YAML | `subscription_id: ...` | `{{ subscription_id }}` | Passed through **unchanged**, so the YAML key must already be snake_case |
| Properties of typed kinds (AppService, AppServicePlan, ...) | `healthCheckPath: /health` | `{{ app.site_config.health_check_path }}` | YAML maps to a C# property through `[YamlMember(Alias = ...)]`, and the `MemberRenamer` in [TemplateLoader.cs](../src/Huggly.Core/Services/TemplateLoader.cs) turns C# property names into snake_case |

A name that doesn't exist renders as an **empty string**, with no error. To find names that break the rule:

```bash
grep -rnE "\{\{[^}]*[A-Z]" src/Huggly.Core/Templates/Files/System src/Huggly.Core/Templates/Files/Common src/Huggly.Core/Templates/Files/Modules
```

It should print nothing. The templates in `Templates/Files/Kubernetes/` are old, use PascalCase and are never rendered. Don't copy from them.

## Known issues

- **The state backend isn't ready for deploying.** `Common/backend.tf.scriban` renders a `local` backend for dev, which stores the state inside the output folder that every compile deletes, and a Terraform Cloud `remote` backend for test and prod with an empty organization and workspace. Validation isn't affected (`-backend=false`), but don't run `terraform apply` until the backend has been chosen and fixed. [DEPLOY.md](DEPLOY.md) describes the azurerm option.
- **`Common/versions.tf.scriban` lists 11 providers**, but the generated output only uses azurerm. `terraform init` downloads them all, which makes it slow.
- **Mistakes in definitions are silently ignored.** A resource whose `system:` doesn't match a system's `name:`, or whose `kind` the compiler doesn't handle, is dropped without an error. Only App Service Plans and App Services are compiled today.
- **Missing template variables render empty** instead of failing the compile. Terraform reports them later as odd syntax errors. See [Troubleshooting](#troubleshooting).

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `unknown command "kubectl" for "kind create cluster"` | Running in cmd, where `;` doesn't separate commands | Switch to PowerShell, or run each command on its own line |
| `failed to connect to the docker API at npipe:////./pipe/docker_engine` | Container engine not running | `podman machine start` (or start Docker Desktop), then `docker ps` |
| `kubectl` says `connection refused` on `127.0.0.1:<port>` | Cluster container stopped after a restart | Recreate the cluster as shown in [After restarting your PC](#after-restarting-your-pc) |
| Podman shows `Currently starting` but never finishes | Machine stuck | `podman machine stop`, then `podman machine start` |
| Compile writes nothing for a new resource YAML | Only App Service Plans and App Services are wired into the compiler today, or `system:` doesn't match the system's `name:` | Check the `system:` spelling. Other kinds are expected to be missing until generic resource kinds are implemented |
| Terraform reports `..`, `""` or `name =` with nothing after it, e.g. `azurerm_resource_group..name` | A template variable rendered empty: the name is misspelled, not snake_case, or missing from the YAML `data:` | Find the `{{ }}` at that spot in the `.scriban` file and check the name against the [naming rules](#naming-rules). To see every available name, set a breakpoint on `return model;` in `BuildModel` and inspect `model` |
