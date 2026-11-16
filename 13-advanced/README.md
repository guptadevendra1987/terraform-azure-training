# Module 13 — Advanced Topics

**Duration:** 1.5 hours (demo + guided labs) · **Level:** Expert
**Exam objectives:** 2a, 7a, 7c

> Needs Terraform **>= 1.11**.

> 📋 **Ticket PLAT-113** — Microsoft released a feature that azurerm doesn't support yet, the provider has a new major version, and a whole resource group must be imported by Friday.

## Learning objectives

- Use the **AzAPI** provider for preview features, new API versions, and properties azurerm doesn't support
- Keep secrets out of state with **ephemeral resources** and **write-only arguments**
- Use **provider-defined functions** (`provider::azurerm::...`)
- Bulk-import with `for_each` on `import` blocks, and reverse-engineer estates with **aztfexport**
- Know the wider ecosystem: OpenTofu, Terraform Stacks, Terragrunt, and `TF_LOG` debugging

---

## 1. AzAPI provider

| | azurerm | azapi |
|---|---|---|
| Coverage | Curated, typed resources | **Every** ARM resource type and API version, including preview |
| New Azure features | Days to months later | Day 0 |
| Schema | Provider-specific argument names | ARM REST body (`properties = {...}`) |
| Validation | Strong | Schema-validated against ARM specs (azapi v2) |

```hcl
resource "azapi_resource" "vnet" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"   # <resource type>@<api-version>
  name      = "vnet-dg-lab13"
  parent_id = azapi_resource.rg.id
  location  = "centralindia"
  body = {
    properties = {
      addressSpace = { addressPrefixes = ["10.80.0.0/16"] }
    }
  }
  response_export_values = ["properties.resourceGuid"]
}
# azapi_resource.vnet.output.properties.resourceGuid
```

* `azapi_update_resource`: patch a property on a resource managed by azurerm (the escape hatch for "azurerm doesn't support property X yet")
* `azapi_resource_action`: call POST actions (for example, `listKeys`, restart)
* `data "azapi_resource"`: read anything

**Find the type and API version:** in the Portal, open the resource, then **JSON View**, or check the [ARM template reference](https://learn.microsoft.com/azure/templates/).

---

## 2. Ephemeral values and write-only arguments

| Feature | Terraform | What it does |
|---|---|---|
| `ephemeral` variables and outputs | 1.10 | Values available during the run, **never persisted** to plan or state |
| `ephemeral "<type>"` resources | 1.10 | Values generated or fetched each run (`random_password`, `azurerm_key_vault_secret`) |
| Write-only arguments (`*_wo`) | 1.11 | Accept ephemeral values; sent to the API, **never stored**. Paired with a `*_wo_version` to trigger updates |

```hcl
ephemeral "random_password" "db" {
  length = 24
}

resource "azurerm_key_vault_secret" "db" {
  name             = "db-password"
  key_vault_id     = azurerm_key_vault.lab.id
  value_wo         = ephemeral.random_password.db.result
  value_wo_version = var.secret_version     # bump 1 → 2 to rotate
}
```

Other write-only arguments in azurerm 4.x include `administrator_login_password_wo` (MSSQL, PostgreSQL, and MySQL flexible servers). Check each resource's docs.

---

## 3. Provider-defined functions (Terraform >= 1.8)

```hcl
locals {
  parts = provider::azurerm::parse_resource_id("/subscriptions/.../resourceGroups/rg-x/providers/Microsoft.Network/virtualNetworks/vnet-x")
}
# parts.resource_group_name, parts.resource_name, parts.resource_type, parts.subscription_id ...
```

Also: `provider::azurerm::normalise_resource_id(...)`. Try them in `terraform console`.

---

## 4. Lab 13.1 — Guided lab (25 min)

**Reference solution:** [labs/lab13-advanced](labs/lab13-advanced/)

1. Deploy the stack: `terraform init && terraform apply -var="student=dg"`
2. Inspect: `terraform output`. The subnet names come from the **ARM API response** through `response_export_values`.
3. **Prove the secret is not in state:**

   ```bash
   terraform state pull | grep -i -A3 '"value_wo"'      # null
   terraform state pull | grep -c "db-password"         # name only, no value
   az keyvault secret show --vault-name <kv> -n db-password --query value -o tsv   # the value exists in Azure
   ```

   Compare this with Module 10, where the password was readable in state.
4. **Rotate:** `terraform apply -var="student=dg" -var="secret_version=2"`. A new secret version is created.
5. `terraform console` → `provider::azurerm::parse_resource_id(azapi_resource.vnet.id)`
6. Clean up: `terraform destroy -var="student=dg"`

---

## 5. Lab 13.2 — Bulk import and aztfexport (15 min)

**Reference solution:** [labs/lab13-bulk-import](labs/lab13-bulk-import/)

### `for_each` on import blocks

```hcl
import {
  for_each = toset(["web", "app", "data"])
  to       = azurerm_resource_group.legacy[each.key]
  id       = "${data.azurerm_subscription.current.id}/resourceGroups/rg-dg-legacy-${each.key}"
}
```

```bash
for n in web app data; do az group create -n rg-dg-legacy-$n -l centralindia --tags course=tf-azure-training owner=dg; done
terraform init && terraform plan        # Plan: 3 to import, 0 to add, 0 to change
terraform apply
```

### aztfexport: reverse-engineer a whole resource group

```bash
mkdir export && cd export
aztfexport resource-group --non-interactive rg-dg-legacy-web
# Produces main.tf, provider.tf, import.tf (or state), and aztfexportResourceMapping.json
aztfexport query --non-interactive "resourceGroup =~ 'rg-dg-legacy' and type =~ 'microsoft.network/'"   # Azure Resource Graph query
```

Treat the output as a **starting point**: refactor it into modules, variables, and naming conventions (the Module 06 import lab skills).

---

## 5b. Lab 13.3 — Production drill: provider major upgrade, azurerm 4 → 5 (25 min)

**Reference solution:** [labs/lab13-provider-upgrade](labs/lab13-provider-upgrade/) (`before-v4/` and `after-v5/`)

This course pins `azurerm ~> 4.0` on purpose. **azurerm 5.x is already released**, and in a real company *someone* has to do the upgrade. Today that's you.

### Step 1 — Feel the pain

```bash
cd labs/lab13-provider-upgrade/before-v4
terraform init && terraform validate         # Success on 4.x
# Change the constraint to "~> 5.0"
terraform init -upgrade
terraform validate
```

These are the real errors from azurerm 5.x:

```text
Error: Unsupported argument     on main.tf line 33, in resource "azurerm_subnet" "data":                       service_endpoints
Error: Missing required argument   in resource "azurerm_storage_blob" "index":                                 storage_container_id
Error: Unsupported argument     in resource "azurerm_storage_blob" "index":                                    storage_account_name, storage_container_name
Error: Missing required argument   in resource "azurerm_private_dns_zone_virtual_network_link" "app":          private_dns_zone_id
Error: Unsupported argument     in resource "azurerm_private_dns_zone_virtual_network_link" "app":             resource_group_name, private_dns_zone_name
Warning: Argument is deprecated  in resource "azurerm_storage_account" "app":                                  public_network_access_enabled
```

### Step 2 — Fix each one, using the provider upgrade guide and the resource docs

| Resource | 4.x | 5.x |
|---|---|---|
| `azurerm_subnet` | `service_endpoints = ["Microsoft.Storage"]` | `service_endpoint { service = "Microsoft.Storage" }` blocks (use `dynamic`) |
| `azurerm_storage_blob` | `storage_account_name` + `storage_container_name` | `storage_container_id` |
| `azurerm_private_dns_zone_virtual_network_link` | `resource_group_name` + `private_dns_zone_name` | `private_dns_zone_id` |
| `azurerm_storage_account` | `public_network_access_enabled = false` | `public_network_access = "Disabled"` |

Compare with `after-v5/main.tf` when you're done.

### Step 3 — The production upgrade runbook

1. Read the **upgrade guide and CHANGELOG** for every major version you cross. Never skip reading.
2. Create a branch. Bump the constraint, then run `terraform init -upgrade` and commit `.terraform.lock.hcl`.
3. Fix errors, then fix **deprecation warnings** (these become errors in the next major version).
4. `terraform plan` in **every** environment. **The goal is "No changes."** If a resource shows replace, stop and investigate (`moved` blocks, `ignore_changes`, or a provider bug).
5. Upgrade shared **modules** first, release a new major module version, then upgrade consumers.
6. Roll out dev → test → prod through the pipeline, one stack at a time.

> Exam objective 2a: `terraform init -upgrade` ignores the lock file and selects the newest versions allowed by the constraints.

---

## 6. Expert toolbox (discussion, 10 min)

| Topic | Key points |
|---|---|
| **Debugging** | `TF_LOG=DEBUG terraform plan 2> debug.log`; `TF_LOG_PROVIDER=TRACE` for API calls; check `x-ms-correlation-request-id` in Azure Activity Log |
| **Performance** | Split large states into stacks; `-parallelism=20`; `-refresh=false` for quick iteration (never in CI applies); `-target` only for emergencies |
| **OpenTofu** | Open-source fork (MPL) after the BSL licence change; largely compatible; adds native **state encryption** |
| **Terraform Stacks** | HCP Terraform feature: orchestrate many components and deployments (environments, regions) as one unit |
| **Terragrunt** | DRY backends and inputs, dependency graph between stacks, `run-all` |
| **Upgrades** | Read provider CHANGELOG and upgrade guides; `terraform init -upgrade` in a branch; plan every environment; watch for deprecation warnings |
| **Crash recovery** | State locked after a crash → `force-unlock`; partial apply → re-plan (Terraform records what succeeded) |

---


### Verbose logging in detail (exam objective 7c)

| Variable | Values / meaning |
|---|---|
| `TF_LOG` | `TRACE` (most detail) · `DEBUG` · `INFO` · `WARN` · `ERROR` · `JSON` (TRACE as JSON). Unset = off |
| `TF_LOG_CORE` | Log level for Terraform Core only |
| `TF_LOG_PROVIDER` | Log level for providers only (the HTTP calls to Azure) |
| `TF_LOG_PATH` | Write the log to a file (requires `TF_LOG` to be set) |

```bash
export TF_LOG=DEBUG TF_LOG_PATH=./terraform-debug.log      # PowerShell: $env:TF_LOG="DEBUG"; $env:TF_LOG_PATH="./terraform-debug.log"
terraform plan
unset TF_LOG TF_LOG_PATH
```

**When to use it:** provider errors with unclear messages, authentication problems, slow plans, and bug reports to HashiCorp or Microsoft. **Never** attach TRACE logs to public issues without redacting them, because they contain tokens and resource details. If Terraform itself crashes, it writes `crash.log` automatically.

## 🎓 Exam corner (objectives 2a, 7a, 7c)

1. Which `TF_LOG` level is the most verbose? → `TRACE`.
2. **True or false:** setting only `TF_LOG_PATH` enables logging. → **False** (`TF_LOG` must also be set).
3. Which command upgrades providers past the versions recorded in the lock file (within the constraints)? → `terraform init -upgrade`.
4. **Choose two:** valid ways to import existing infrastructure are the `import` block / `terraform import` command / `terraform refresh` / `terraform apply -replace` → **`import` block, `terraform import`.**
5. What does `terraform plan -generate-config-out=file.tf` do? → It writes HCL for resources that `import` blocks reference but that have no configuration yet.

## 7. Knowledge check

1. When would you choose `azapi_update_resource` over `azapi_resource`?
2. How do write-only arguments differ from `sensitive = true`?
3. Why does a write-only argument need a companion `_wo_version` argument?
4. What does `aztfexport` produce, and what still needs a human?

<details><summary>Answers</summary>

1. When the resource is created and managed elsewhere (often by azurerm) and you only need to set properties that azurerm doesn't expose.
2. Write-only values are never stored in the plan or state. Sensitive values are stored in state and only redacted in output.
3. Terraform cannot compare a value it never stored, so it needs a stored version marker to know when to send a new value.
4. HCL, plus import blocks or state, for the existing resources. A human still needs to refactor into modules and variables, remove defaults and noise, and apply naming conventions.
</details>
