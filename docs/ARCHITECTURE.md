# Architecture

How Huggly turns YAML definitions into Terraform. Read this first after a break.

```
YAML files ──Load──▶ DefinitionRegistry ──Resolve──▶ SystemContext per system
                                                          │
                          for each landing zone (dev, test, prod)
                                                          ▼
                                   BuildModel ──▶ ScriptObject (the template model)
                                                          │
                                   TemplateLoader renders each .scriban template
                                                          ▼
                                   huggly-outputs/<environment>/<system>/*.tf
```

## 1. Definitions (YAML)

Every YAML document has a `kind:`. Systems live in [src/huggly-templates/Systems/](../src/huggly-templates/Systems/), one folder per system.

| Kind | Required fields | Example |
|---|---|---|
| `System` | `name:`, optional `data:` and `landing-zone:` | [Conferenti.yaml](../src/huggly-templates/Systems/Conferenti/Conferenti.yaml) |
| `AppServicePlan` | `system:`, `name:` | [AppServicePlans.yaml](../src/huggly-templates/Systems/Conferenti/AppServicePlans.yaml) |
| `AppService` | `system:`, `name:`, `servicePlan:` | [ConferentiApp.yaml](../src/huggly-templates/Systems/Conferenti/ConferentiApp.yaml) |

The allowed kinds are the [`DefinitionKind`](../src/Huggly.Core/Models/DefinitionKind.cs) enum. `AksCluster` is in the enum but not wired in yet, so it fails with `not supported yet`.

**A resource belongs to a system through `system:`**, which must equal the system's `name:` exactly (case-sensitive).

**`landing-zone:` keys are the environments.** A system with `dev`, `test` and `prod` compiles to three output folders. A system without `landing-zone:` compiles to one environment called `default`. Passing an `--environment` that isn't a landing-zone key compiles nothing.

## 2. Loading: [DefinitionRegistry](../src/Huggly.Core/Services/DefinitionRegistry.cs)

[CompileCommand](../src/Huggly.CLI/Commands/CompileCommand.cs) reads every `*.yaml` under `--definitions` (recursively) and passes each file to the registry in two passes:

1. **`Load(yaml, source)`**: reads the `kind:` of each document through [`DocumentEnvelope`](../src/Huggly.Core/Entities/Definitions/DocumentEnvelope.cs). Systems are stored right away in `Systems[name]`. Everything else is kept for later, because the system it points to may be in a file that hasn't been read yet.
2. **`Resolve()`**: attaches each resource to its system's [`SystemContext`](../src/Huggly.Core/Models/SystemContext.cs) (`AppServicePlans`, `AppServices`).

Errors stop the compile and name the file: an unknown `system:`, a kind with no handler, a misspelled `kind:`, or a document with no `kind:`.

## 3. Landing zones: overrides per environment

- **System `data:`**: [`ResolveAll`](../src/Huggly.Core/Entities/Definitions/Extensions/SystemDefinitionExtensions.cs) merges the system's `data:` with each landing zone's `data:`. The landing zone wins on the same key.
- **App Service `appSettings:`**: [`ResolveFor`](../src/Huggly.Core/Entities/Definitions/Extensions/LandingZoneExtensions.cs) merges the app's `appSettings` with the landing zone's. Other App Service fields and App Service Plans have no per-environment overrides yet.

## 4. The model: `BuildModel` in [CompileCommand](../src/Huggly.CLI/Commands/CompileCommand.cs)

For each system and environment, `BuildModel` creates the Scriban `ScriptObject` that templates read:

| Model key | From |
|---|---|
| `system_name` | The system's `name:` |
| `environment` | The landing-zone key |
| Every key under `data:` | The merged `data:`, **key unchanged**, so YAML keys must be snake_case |
| `state_backend` | `data:`, default `local`. Checked by `ValidateStateBackend` ([ADR 0001](decisions/0001-terraform-state-backend.md)) |
| `app_service_plans`, `app_services` | The lists from `SystemContext`, with environment overrides applied |

C# objects in the lists keep their properties, renamed to snake_case by the `MemberRenamer` (`HealthCheckPath` → `health_check_path`). See [Naming rules](README.md#naming-rules).

Debugging tip: put a breakpoint on `return model;` in `BuildModel` to see every value the templates get. [.vscode/launch.json](../.vscode/launch.json) has ready-made launch configurations.

## 5. Rendering: [TemplateLoader](../src/Huggly.Core/Services/TemplateLoader.cs)

Templates are `.scriban` files under [src/Huggly.Core/Templates/Files/](../src/Huggly.Core/Templates/Files/), embedded into the DLL by [Huggly.Core.csproj](../src/Huggly.Core/Huggly.Core.csproj). `RenderSystemTemplateAsync` renders, in order:

| Folder | Rendered | Output |
|---|---|---|
| `System/` | Always | `main.tf` (provider, resource group) |
| `Common/` | Always | `backend.tf`, `versions.tf` |
| `Modules/compute/` | Only if the model has a non-empty list with the template's name (`app_services.tf.scriban` → `app_services`) | `app_services.tf`, ... |

The output file name is the template name without `.scriban`. The output folder `huggly-outputs/<environment>/<system>/` is **deleted and recreated** on every compile. Local Terraform state lives outside it, in `huggly-outputs/.tfstate/`.

Templates run with **StrictVariables**: a variable that isn't in the model fails the compile with the template, line and name. Parse errors name the template too.

Not rendered: `Templates/Files/Kubernetes/` and `Scripts/` (old PascalCase drafts kept for AKS and Argo CD work), the other `Modules/` folders (no kind uses them yet), `Templates/Modules/*.tf`, and `local-k8s/` (a hand-written kind cluster, see [README](README.md#4-run-a-local-kubernetes-cluster)).

## 6. Checking and CI

[scripts/check.sh](../scripts/check.sh) builds, then compiles a system for `dev`, `test` and `prod` and runs `terraform init -backend=false` and `terraform validate` on each. [.github/workflows/check.yml](../.github/workflows/check.yml) runs it on every pull request and push to `main`. Deploying is described in [DEPLOY.md](DEPLOY.md).

## How to add a new kind

Example: `StorageAccount`.

1. **Enum:** add `StorageAccount` to [`DefinitionKind`](../src/Huggly.Core/Models/DefinitionKind.cs).
2. **Definition class:** add a record under [Entities/Definitions/](../src/Huggly.Core/Entities/Definitions/) with `[YamlMember(Alias = "camelCase")]` properties, `Name`, and `LandingZones` if it should have overrides.
3. **Context:** add a list to [`SystemContext`](../src/Huggly.Core/Models/SystemContext.cs), for example `StorageAccounts`.
4. **Registry:** add a `case` in `AttachToSystem` in [DefinitionRegistry](../src/Huggly.Core/Services/DefinitionRegistry.cs).
5. **Model:** add the list in `BuildModel`, with the snake_case key that matches the template name (`storage_accounts`). Apply overrides here if the kind has them.
6. **Template:** write or fix `Modules/<area>/storage_accounts.tf.scriban`, with snake_case names only.
7. **Render:** if the template's folder isn't rendered yet, add its prefix in `RenderSystemTemplateAsync`.
8. **Providers:** if the template needs a new provider, add it to [versions.tf.scriban](../src/Huggly.Core/Templates/Files/Common/versions.tf.scriban).
9. **Sample:** add a YAML to Conferenti so `scripts/check.sh` and CI cover it.

## Folder map

| Path | What |
|---|---|
| `src/Huggly.CLI/` | Command-line entry point ([Program.cs](../src/Huggly.CLI/Program.cs)) and commands. Only `compile` does anything; `run` and `test` are placeholders |
| `src/Huggly.Core/` | Definitions, registry, template loader, embedded templates |
| `src/huggly-templates/Systems/` | Sample system definitions (Conferenti) |
| `src/huggly-web/` | Next.js web app, not connected to the CLI yet |
| `huggly-outputs/` | Generated Terraform and local state. Not committed |
| `docs/decisions/` | Architecture decision records (ADRs) |
| `examples/` | Argo CD hello example for the local cluster |
