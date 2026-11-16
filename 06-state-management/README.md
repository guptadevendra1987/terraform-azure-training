# Module 06 — State Management

**Duration:** 4 hours (1h theory · 3h labs) · **Level:** Intermediate → Advanced
**Exam objectives:** 2d, 6a–6d, 7a, 7b

> 📋 **Ticket PLAT-106** — Two engineers applied at the same time last week and corrupted a state file. Also, 12 Portal-created resources must come under Terraform without downtime. Fix state for good.

## Learning objectives

- Explain what state stores, why Terraform needs it, and why it is sensitive
- Configure the `azurerm` backend with Entra ID authentication, locking, and versioning
- Migrate local state to remote state, and between backends
- Do safe state surgery with `state list/show/mv/rm` and the declarative `moved` and `removed` blocks
- Import existing Azure resources with `import` blocks and `-generate-config-out`
- Share outputs between stacks with `terraform_remote_state`, and recover from a corrupted state file

---

## 1. Concepts

### 1.1 What is in state?

```json
{
  "version": 4,
  "terraform_version": "1.17.2",
  "serial": 12,                          ← increments on every write
  "lineage": "2c1f…",                    ← unique ID of this state's "family"
  "resources": [{
    "mode": "managed",
    "type": "azurerm_resource_group",
    "name": "main",
    "instances": [{ "attributes": { "id": "/subscriptions/…/resourceGroups/rg-dg", "name": "rg-dg", … } }]
  }]
}
```

State gives Terraform:

1. **Mapping**: config address ↔ real Azure resource ID
2. **Metadata**: dependencies (for destroy ordering) and the provider that owns each resource
3. **Performance**: cached attributes
4. **Ownership**: Terraform only manages what is in state. Anything else is invisible to it.

### 1.2 Why local state fails in teams

| Problem | Remote backend solution |
|---|---|
| Only on one laptop. Lost laptop means lost state | Durable storage with versioning |
| Two people apply at once and corrupt state | **Locking** (an Azure blob lease) |
| Secrets in plain text on laptops | RBAC + encryption at rest + private endpoint |
| CI can't access it | Shared, centrally authenticated |

### 1.3 The azurerm backend

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-dg-tfstate"
    storage_account_name = "stdgtfstateab12c"
    container_name       = "tfstate"
    key                  = "lab06/network.tfstate"   # blob name: one per stack/environment
    use_azuread_auth     = true                      # Entra ID RBAC instead of storage keys
  }
}
```

* Backend blocks **cannot use variables**. Use **partial configuration** instead: `terraform init -backend-config=backend.hcl`.
* Locking is automatic, through a blob lease.
* Required role: **Storage Blob Data Contributor** on the storage account or container.

### 1.4 State hardening checklist (production)

- [ ] A dedicated subscription or resource group for state, with a `CanNotDelete` resource lock
- [ ] `allow_shared_key_access = false`, `use_azuread_auth = true`
- [ ] Blob versioning + soft delete (7–30 days)
- [ ] Private endpoint or firewall that allows only CI runners
- [ ] One state file per stack and environment (keeps the blast radius small)
- [ ] Nobody edits state by hand. Use CLI commands or `moved`/`import`/`removed` blocks

### 1.5 State commands at a glance

| Command | Use |
|---|---|
| `terraform state list` | List addresses |
| `terraform state show <addr>` | Show attributes |
| `terraform state mv <from> <to>` | Rename or move (prefer `moved {}` blocks) |
| `terraform state rm <addr>` | Stop managing without deleting (prefer `removed {}` blocks) |
| `terraform state pull > backup.tfstate` | Download state |
| `terraform state push backup.tfstate` | Upload state (dangerous) |
| `terraform force-unlock <LOCK_ID>` | Release a stuck lock |
| `terraform plan -refresh-only` | Show drift between state and reality |
| `terraform apply -refresh-only` | Accept the drift into state |

### 1.6 Declarative refactoring blocks (preferred over CLI surgery)

```hcl
# Rename/move a resource without destroying it
moved {
  from = azurerm_storage_account.main
  to   = azurerm_storage_account.logs
}

# Bring an existing resource under management
import {
  to = azurerm_resource_group.legacy
  id = "/subscriptions/<sub>/resourceGroups/rg-legacy"
}

# Stop managing a resource but keep it in Azure (Terraform >= 1.7)
removed {
  from = azurerm_storage_account.old
  lifecycle {
    destroy = false
  }
}
```

These blocks are **reviewed in a PR and shown in the plan**, unlike CLI commands that change state immediately.

---

## 2. Lab 6.1 — Bootstrap a remote backend and migrate state

**Reference solution:** [labs/lab06-remote-backend](labs/lab06-remote-backend/)

### Step 1 — Create the backend storage (one time)

```powershell
.\00-lab-setup\scripts\bootstrap-backend.ps1 -Student dg
```

```bash
./00-lab-setup/scripts/bootstrap-backend.sh dg
```

Note the printed values.

> **Chicken-and-egg discussion:** who creates the state storage? Usually a one-off script (like this one), or a tiny "bootstrap" Terraform stack with local state that is then migrated into itself.

### Step 2 — Start with local state

Create `~/tf-labs/lab06` with a resource group and a storage account (copy Lab 03). Run `terraform apply`. Confirm `terraform.tfstate` exists locally.

### Step 3 — Add a backend with partial configuration

`backend.tf`:

```hcl
terraform {
  backend "azurerm" {
    key = "lab06/app.tfstate"
  }
}
```

`backend.hcl` (git-ignored, or committed per environment because it holds no secrets):

```hcl
resource_group_name  = "rg-dg-tfstate"
storage_account_name = "stdgtfstateXXXXX"
container_name       = "tfstate"
use_azuread_auth     = true
```

### Step 4 — Migrate

```bash
terraform init -backend-config=backend.hcl -migrate-state
# Do you want to copy existing state to the new backend? yes
```

Verify:

```bash
az storage blob list --account-name stdgtfstateXXXXX -c tfstate --auth-mode login -o table
terraform state list            # now read from Azure
mv terraform.tfstate terraform.tfstate.local-backup   # local copy is no longer used
terraform plan                  # No changes
```

### Step 5 — See locking in action

Open **two terminals** in the same folder.

* Terminal 1: `terraform apply` (**don't** answer the prompt yet; the lock is now held)
* Terminal 2: `terraform plan`

```text
Error: Error acquiring the state lock
Lock Info:
  ID:        6f1c…
  Path:      tfstate/lab06/app.tfstate
  Operation: OperationTypeApply
  Who:       DESKTOP\dg
```

Answer `no` in terminal 1. Look at the blob's **Lease state** in the Portal while the lock is held.

**Stuck lock** (for example, after a CI job was killed): `terraform force-unlock <ID>`. Only use it after confirming that nobody else is running.

---

## 3. Lab 6.2 — Refactor safely with `moved` and `removed` (45 min)

**Reference solution:** [labs/lab06-refactoring](labs/lab06-refactoring/)

### Step 1 — Rename a resource

Rename `azurerm_storage_account.main` to `azurerm_storage_account.app` in your code. Run `terraform plan`. **Terraform wants to destroy and re-create it.** In production, that means data loss.

Add:

```hcl
moved {
  from = azurerm_storage_account.main
  to   = azurerm_storage_account.app
}
```

Plan again:

```text
  # azurerm_storage_account.main has moved to azurerm_storage_account.app
Plan: 0 to add, 0 to change, 0 to destroy.
```

Apply it. Keep `moved` blocks for a while, because other environments still need to run them, and remove them in a later release.

### Step 2 — Convert a single resource to `for_each`

```hcl
resource "azurerm_storage_container" "this" {
  for_each              = toset(["data"])
  name                  = each.key
  storage_account_id    = azurerm_storage_account.app.id
  container_access_type = "private"
}

moved {
  from = azurerm_storage_container.first
  to   = azurerm_storage_container.this["data"]
}

# A separate container that we will hand over to another team in Step 3
resource "azurerm_storage_container" "logs" {
  name                  = "logs"
  storage_account_id    = azurerm_storage_account.app.id
  container_access_type = "private"
}
```

Plan: `first` moves to `this["data"]` (0 changes) and `logs` is added. Apply.

### Step 3 — Stop managing a resource but keep it in Azure

Scenario: the `logs` container is handed over to another team. Delete the `azurerm_storage_container.logs` block and add:

```hcl
removed {
  from = azurerm_storage_container.logs

  lifecycle {
    destroy = false
  }
}
```

Plan shows `will no longer be managed by Terraform`. Apply, then confirm the container still exists in Azure.

> **Gotcha:** `removed` works on whole resources only. `from = azurerm_storage_container.this["logs"]` fails with *"Resource instance keys not allowed"*. To forget a single `for_each`/`count` instance, use `terraform state rm 'azurerm_storage_container.this["logs"]'`.

### Step 4 — CLI equivalents (know them for interviews and emergencies)

```bash
terraform state pull > before.tfstate                        # ALWAYS back up first
terraform state mv 'azurerm_storage_container.this["data"]' 'azurerm_storage_container.primary'
terraform state rm 'azurerm_storage_container.primary'
terraform import 'azurerm_storage_container.this["data"]' <container-resource-id>   # put it back
```

---

## 4. Lab 6.3 — Import "click-ops" resources (45 min)

**Reference solution:** [labs/lab06-import](labs/lab06-import/)

### Step 1 — Simulate legacy Portal resources

```bash
az group create -n rg-dg-legacy -l centralindia --tags course=tf-azure-training owner=dg
az network vnet create -g rg-dg-legacy -n vnet-legacy --address-prefixes 10.50.0.0/16 \
  --subnet-name default --subnet-prefixes 10.50.1.0/24
az network nsg create -g rg-dg-legacy -n nsg-legacy
az network nsg rule create -g rg-dg-legacy --nsg-name nsg-legacy -n allow-https \
  --priority 100 --destination-port-ranges 443 --access Allow --protocol Tcp
```

### Step 2 — Write `import` blocks only

`imports.tf`:

```hcl
locals {
  sub = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
}
data "azurerm_client_config" "current" {}

import {
  to = azurerm_resource_group.legacy
  id = "${local.sub}/resourceGroups/rg-dg-legacy"
}

import {
  to = azurerm_virtual_network.legacy
  id = "${local.sub}/resourceGroups/rg-dg-legacy/providers/Microsoft.Network/virtualNetworks/vnet-legacy"
}

import {
  to = azurerm_subnet.default
  id = "${local.sub}/resourceGroups/rg-dg-legacy/providers/Microsoft.Network/virtualNetworks/vnet-legacy/subnets/default"
}

import {
  to = azurerm_network_security_group.legacy
  id = "${local.sub}/resourceGroups/rg-dg-legacy/providers/Microsoft.Network/networkSecurityGroups/nsg-legacy"
}
```

> Import IDs can't depend on resources, but they **can** use data sources and locals (Terraform ≥ 1.6).

### Step 3 — Let Terraform write the code

```bash
terraform init
terraform plan -generate-config-out=generated.tf
```

Open `generated.tf`. It contains every attribute, including defaults and read-only noise.

### Step 4 — Clean up the generated code (the real skill)

* Remove attributes that just repeat defaults (`flow_timeout_in_minutes = 0`, empty lists, `null`)
* Replace hard-coded values with references (`resource_group_name = azurerm_resource_group.legacy.name`)
* Decide inline vs separate: the NSG came with an inline `security_rule`. Keep it inline **or** convert it, but don't mix
* The VNet may contain an inline `subnet` block **and** you imported `azurerm_subnet`. Remove the inline one

Iterate until:

```bash
terraform plan
# Plan: 4 to import, 0 to add, 0 to change, 0 to destroy.
terraform apply
```

After the apply, the import blocks can be deleted (or kept as documentation).

### Step 5 — Bulk alternative

For whole resource groups, `aztfexport` generates both the import blocks and the code (Module 13):

```bash
aztfexport resource-group --non-interactive --hcl-only rg-dg-legacy
```

---

## 5. Lab 6.4 — Share data between stacks with `terraform_remote_state` (30 min)

**Reference solution:** [labs/lab06-remote-state-consumer](labs/lab06-remote-state-consumer/)

Stack A (network, state key `lab06/network.tfstate`) exposes outputs. Stack B reads them:

```hcl
data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-dg-tfstate"
    storage_account_name = "stdgtfstateXXXXX"
    container_name       = "tfstate"
    key                  = "lab06/network.tfstate"
    use_azuread_auth     = true
  }
}

resource "azurerm_network_interface" "app" {
  # ...
  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.terraform_remote_state.network.outputs.subnet_ids["app"]
    private_ip_address_allocation = "Dynamic"
  }
}
```

**Trade-offs:**

| `terraform_remote_state` | Data source (`azurerm_subnet`) |
|---|---|
| Consumer needs read access to the **entire** state file, including secrets | Needs only Reader on the resource |
| Coupled to the producer's output names | Coupled to Azure resource names |
| Fast and simple | Works even when the producer isn't Terraform |

> **Expert recommendation:** prefer data sources (or a naming convention) across team boundaries, and use remote state within one team.

---

## 6. Lab 6.5 — Disaster recovery: restore a previous state version (20 min)

1. `terraform state pull > good.tfstate`
2. Simulate corruption: `terraform state rm azurerm_resource_group.main` (state now "forgets" the RG)
3. `terraform plan` → Terraform wants to *create* the RG, and the apply would fail with "already exists"
4. Recover with one of these options:
   * **Option A:** `terraform import azurerm_resource_group.main /subscriptions/.../resourceGroups/...`
   * **Option B:** Portal → storage account → container → blob → **Versions** → *Make current version* on the previous version
   * **Option C:** `terraform state push good.tfstate`. This fails if the serial is lower, and `-force` overrides that, so be very careful
5. `terraform plan` → No changes

---

## 7. Clean up

```bash
terraform destroy -var-file=...      # each lab folder
az group delete -n rg-dg-legacy --yes
# Keep rg-<student>-tfstate: it is used until Day 5
```

---


## 🏭 In production

* **One state per stack per environment,** in a dedicated, locked-down subscription or resource group with versioning, soft delete and a `CanNotDelete` lock.
* **Nobody runs `state push` or `force-unlock` without an incident ticket.** Prefer `moved`/`removed`/`import` blocks: they are reviewed in PRs.
* **Back up before surgery:** `terraform state pull > backup-<date>.tfstate`, stored securely.
* **Imports are projects, not commands.** Budget time for cleaning the generated code and reaching "0 to change".


## 🎓 Exam corner

1. Where does the local backend store state? → `terraform.tfstate` in the working directory (plus `terraform.tfstate.backup`).
2. **True or false:** Every backend supports state locking. → **False.**
3. Which command releases a stuck lock? → `terraform force-unlock LOCK_ID`.
4. What shows drift without proposing changes to infrastructure? → `terraform plan -refresh-only`.
5. **Choose two:** declarative refactoring blocks: `moved` / `removed` / `rename` / `taint` → **moved, removed.**
6. Which command lists every resource address in state? → `terraform state list`.

## 8. Knowledge check

1. What happens if two engineers apply at the same time with a remote backend? And with local state?
2. Why can't you use `var.environment` inside a backend block? What is the workaround?
3. `moved` block or `terraform state mv`: which should a team prefer, and why?
4. What does `removed { lifecycle { destroy = false } }` do?
5. You ran `terraform plan -generate-config-out=x.tf`, and the plan shows `~ update in-place` after the import. Is that OK?
6. Name two risks of `terraform_remote_state`.

<details><summary>Answers</summary>

1. Remote: the second one waits or fails on the lock. Local: there is no shared lock, so both write divergent state files and conflicts or duplicate resources follow.
2. Backends are configured before variables are evaluated. Use partial config with `-backend-config` files or flags, or `TF_CLI_ARGS_init`.
3. `moved` blocks: they are version-controlled, reviewed, visible in the plan, and automatically applied to every environment and module consumer.
4. It removes the resource from state without destroying it in Azure.
5. Investigate first. It often means your cleaned-up code differs from reality, for example a default you removed was not actually the default. Aim for zero changes after an import, unless the change is intended.
6. The consumer can read the producer's entire state, including secrets, and it creates tight coupling to the producer's output names.
</details>
