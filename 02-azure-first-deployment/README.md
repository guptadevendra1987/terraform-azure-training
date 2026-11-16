# Module 02 — Your First Azure Deployment

**Duration:** 3 hours · **Level:** Beginner
**Exam objectives:** 2a, 2b, 2c, 2d, 3a–3g

> 📋 **Ticket PLAT-102** — The data team needs a secure storage account for daily exports, plus a disaster-recovery copy in South India. Deliver it with Terraform, authenticated without passwords in code.

> 🖼️ **Visual guide:** open [visual-guide.html](visual-guide.html) in your browser. It has diagrams of everything in Part A (identities, service principals, roles, scopes) and the step-by-step build of Lab 2.1. Trainers can project it while explaining.

## Learning objectives

By the end of this module you can:

- Explain how Terraform gets **permission** to create things in Azure (who it is, and what it's allowed to do)
- Choose a login method: your own account, a **service principal**, a managed identity, or OIDC
- Pick the **right role at the right scope** for the identity that runs Terraform
- Build a deployment **one resource at a time**: resource group → storage account → container
- Read a plan (`+` create, `~` update, `-/+` replace) and know when something will be destroyed
- Run Terraform as a least-privilege service principal, and prove which identity it used

## How this module is organised

| Part | Time | What you do |
|---|---|---|
| **Part A** — How Terraform gets into Azure | 30 min | Concepts and diagrams. No code yet |
| **Lab 2.1** — Build it one resource at a time | 75 min | Your own login. RG, then storage, then container. Update, replace, drift |
| **Lab 2.2** — Run Terraform as a service principal | 45 min | Create an SPN with least privilege, use it, hit its limits, clean up |
| **Lab 2.3** — Several providers in one configuration | 30 min | A DR region with a provider alias, plus Entra ID |

---

## Part A — How does Terraform get permission to create things in Azure?

### A.1 Azure asks two questions

Every time Terraform calls Azure, Azure checks two things:

| Question | Technical name | Answered by | Office-building analogy |
|---|---|---|---|
| **Who are you?** | Authentication | An **identity** in Microsoft Entra ID (a user, service principal or managed identity) | Your **ID badge** at reception |
| **What may you do, and where?** | Authorization | A **role assignment** = a **role** (what) on a **scope** (where) | Your access card is programmed for **certain floors** |

```text
  terraform apply
        │
        │ 1. "Here are my credentials"            ┌──────────────────────┐
        ├────────────────────────────────────────▶│  Microsoft Entra ID  │  "Yes, you are sp-tf-training-dg.
        │ 2. access token (valid ~1 hour)         │  (the identity system)│   Here is a token."
        │◀────────────────────────────────────────┤                      │
        │                                          └──────────────────────┘
        │ 3. "Create storage account X" + token   ┌──────────────────────┐
        ├────────────────────────────────────────▶│ Azure Resource Manager│  Checks role assignments:
        │                                          │       (ARM)          │  "Contributor on rg-dg-lab02?
        │ 4. created ✔  or  AuthorizationFailed ✘  │                      │   Yes, allowed."
        │◀────────────────────────────────────────┤                      │
                                                   └──────────────────────┘
```

Terraform itself never "has" permissions. It borrows the permissions of whatever identity it logs in as.

### A.2 The four ways Terraform can log in to Azure

| # | Method | Who Terraform is | Use it for | What you set | In this course |
|---|---|---|---|---|---|
| 1 | **Azure CLI** (`az login`) | **You**, with your own permissions | Learning and personal sandboxes | `ARM_SUBSCRIPTION_ID` | Modules 02–11 |
| 2 | **Service principal + client secret** | An app identity (a "robot account") | Older CI/CD tools. Understand it, then avoid it | `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID` | **Lab 2.2** |
| 3 | **Managed identity** | An identity Azure gives to a VM, container or agent | Self-hosted runners inside Azure | `ARM_USE_MSI=true` (+ `ARM_CLIENT_ID` for user-assigned) | Module 08 |
| 4 | **OIDC / workload identity federation** | A service principal, but **without any secret** | GitHub Actions, Azure DevOps, HCP Terraform | `ARM_USE_OIDC=true`, `ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID` | Modules 12, 15 |

**How does the provider choose?** If service principal credentials (method 2), OIDC (4) or managed identity (3) are configured through `ARM_*` environment variables or the provider block, the provider uses them. **If nothing else is configured, it falls back to your Azure CLI login.** That is why a forgotten `ARM_CLIENT_SECRET` in your terminal can make Terraform run as a robot without you noticing. Lab 2.1 adds a `whoami.tf` output so you can always check.

> **Golden rule:** never write a secret in a `.tf` file. Credentials come from environment variables, or better, from methods that have no secret at all (3 and 4).

### A.3 What exactly is a service principal?

When you create a service principal with `az ad sp create-for-rbac`, Azure creates **three things**:

```text
 ┌────────────────────────────────┐        ┌────────────────────────────────┐
 │ App registration               │ 1 ── 1 │ Service principal              │
 │ (the "definition")             │───────▶│ (the "account" in YOUR tenant) │
 │                                │        │                                │
 │ appId / client ID  ◀── ARM_CLIENT_ID    │ object ID ◀── used in role     │
 │ client secret      ◀── ARM_CLIENT_SECRET│              assignments       │
 │ (or certificate, or federated   │        └───────────────┬────────────────┘
 │  credential for OIDC)           │                        │
 └────────────────────────────────┘                        │ 3. Role assignment
                                                            ▼
                                        role: Contributor   on   scope: /subscriptions/…/resourceGroups/rg-dg-lab02
```

| Value | Looks like | Environment variable | Secret? |
|---|---|---|---|
| Tenant ID | `72f988bf-…` (your organisation's Entra ID) | `ARM_TENANT_ID` | No |
| Subscription ID | `a1b2c3d4-…` (the billing container to deploy into) | `ARM_SUBSCRIPTION_ID` | No |
| Client ID (appId) | `0a1b2c3d-…` (the service principal's username) | `ARM_CLIENT_ID` | No |
| Client secret | `Xy8Q~…` (the service principal's password) | `ARM_CLIENT_SECRET` | **Yes**. Shown once, expires (default 1 year) |

### A.4 Roles and scopes: give the smallest key that opens the right door

**Scope** is *where* a role applies. Permissions flow **down** the hierarchy:

```text
 Management group  (many subscriptions, e.g. "Contoso-Prod")
   └── Subscription  (a billing and permission boundary)
         └── Resource group  (e.g. rg-dg-lab02)        ◀── Lab 2.2 gives the SPN Contributor HERE
               └── Resource  (e.g. a storage account)
 A role at a higher level is inherited by everything below it.
```

**Common roles** (built into Azure):

| Role | Can do | Can it grant access to others? | Use for Terraform when… |
|---|---|---|---|
| **Reader** | Read everything | No | Plans only, drift detection, reading data sources |
| **Contributor** | Create, change, delete resources | **No** | **Most deployments** (the usual choice) |
| **User Access Administrator** | Manage role assignments only | Yes | Your code creates `azurerm_role_assignment` resources (Modules 08, 10) |
| **Role Based Access Control Administrator** | Manage role assignments, and can be **restricted by conditions** (for example "only Reader roles") | Yes, limited | The safer production alternative to User Access Administrator |
| **Owner** | Everything, including granting access | Yes | **Avoid for automation.** Too powerful if leaked |
| **Storage Blob Data Contributor** | Read and write blobs (data plane) | No | Terraform remote state with Entra auth (Module 06) |
| **Key Vault Secrets Officer** | Read and write Key Vault secrets (data plane) | No | Terraform writes secrets (Module 10) |

> **Management plane vs data plane:** Contributor lets you *create* a storage account or Key Vault (management plane), but **not** read blobs or secrets inside it (data plane). Data access needs data roles such as *Storage Blob Data Contributor*. This surprises almost everyone the first time.

**Which permissions does each part of this course need?**

| Course part | Role(s) for the identity that runs Terraform | Scope |
|---|---|---|
| Modules 02–05, 07–09, 11 | Contributor | Subscription (or a resource group) |
| Module 06 (remote state) | + Storage Blob Data Contributor | The state storage account |
| Module 08 / 10 (managed identities, Key Vault RBAC) | + User Access Administrator **or** Role Based Access Control Administrator; + Key Vault Secrets Officer | Subscription / the Key Vault |
| Module 10 / 12 / 15 (Entra groups, app registrations) | Entra ID permission to create groups and app registrations (default for users in most tenants, otherwise *Groups Administrator* / *Application Developer*) | Tenant |
| Lab 2.2 (this module) | **Reader** on the subscription + **Contributor** on `rg-<you>-lab02` | As stated |

**Least-privilege checklist for any Terraform identity:**

- [ ] The **smallest scope** that works (resource group before subscription before management group)
- [ ] **Contributor**, not Owner. Add role-assignment rights only if the code creates role assignments
- [ ] **One identity per environment** (dev cannot touch prod)
- [ ] **No secret** if possible (OIDC or managed identity). If a secret is unavoidable: short expiry, stored in a secret store, rotated

### A.5 Who can create a service principal?

To run `az ad sp create-for-rbac --role … --scopes …` you need **two** different permissions:

1. **Entra ID:** permission to create app registrations. Normal users have it unless your administrator turned it off. Otherwise you need the *Application Developer* Entra role.
2. **Azure:** permission to assign roles on the scope: **Owner**, **User Access Administrator** or **Role Based Access Control Administrator**.

> In many companies only the platform or identity team creates service principals. Students without these rights can watch Lab 2.2 as a trainer demo, or the trainer can create one per student in advance with the same scripts.

---

## Lab 2.1 — Build it one resource at a time (your own login)

**Reference solution:** [labs/lab02-storage-account](labs/lab02-storage-account/) (the final result of all steps)

You will add **one resource per step**, and run `plan` each time to see exactly what Terraform will do.

```text
Step 3: resource group        Step 4: + storage account     Step 5: + container
┌─────────────────┐           ┌─────────────────┐           ┌─────────────────┐
│ rg-dg-lab02     │    ──▶    │ rg-dg-lab02     │    ──▶    │ rg-dg-lab02     │
│                 │           │  └ stdglab02xxx │           │  └ stdglab02xxx │
│                 │           │                 │           │     └ data      │
└─────────────────┘           └─────────────────┘           └─────────────────┘
 Plan: 1 to add                Plan: 2 to add                Plan: 1 to add
```

> Replace `dg` with **your initials** everywhere in this lab. Module 03 shows how to turn it into a variable.

### Step 1 — Log in and create the folder

```bash
az login                                   # opens your browser
az account show -o table                   # check you're in the TRAINING subscription
mkdir -p ~/tf-labs/lab02 && cd ~/tf-labs/lab02
```

Tell Terraform which subscription to use (azurerm version 4 requires it):

```powershell
# PowerShell
$env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)
```

```bash
# bash / zsh
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

### Step 2 — `providers.tf`: tell Terraform which plugins to use

```hcl
terraform {
  required_version = ">= 1.9"          # which Terraform CLI versions may run this code

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"    # where to download the Azure plugin
      version = "~> 4.0"               # any 4.x version (not 5.0)
    }
    random = {
      source  = "hashicorp/random"     # a helper plugin that generates random values
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}                          # required, even when empty
  # No credentials here. The provider uses your az login (Part A.2).
}
```

```bash
terraform init      # downloads the two plugins into .terraform/ and writes .terraform.lock.hcl
```

### Step 3 — Your first resource: just a resource group

Create `main.tf` with **only** this:

```hcl
resource "azurerm_resource_group" "main" {
#        └─ resource TYPE ─────┘  └ NAME (your label inside Terraform)
  name     = "rg-dg-lab02"          # the name Azure will show
  location = "centralindia"

  tags = {
    course = "tf-azure-training"
    owner  = "dg"
  }
}
```

```bash
terraform plan
```

Read the plan before anything else:

```text
  # azurerm_resource_group.main will be created
  + resource "azurerm_resource_group" "main" {
      + id       = (known after apply)      ← Azure decides this when it creates it
      + location = "centralindia"
      + name     = "rg-dg-lab02"
      ...
Plan: 1 to add, 0 to change, 0 to destroy.
```

```bash
terraform apply          # type yes
terraform state list     # azurerm_resource_group.main  ← Terraform now "remembers" it
```

Open the Azure Portal and find **rg-dg-lab02**. Look at its **Tags**. You just created cloud infrastructure from a text file.

### Step 4 — Add a storage account

Storage account names must be **globally unique** (`<name>.blob.core.windows.net`), 3–24 characters, lowercase letters and numbers only. If you and a classmate both pick `stdglab02`, one of you fails. So we add a random suffix. Append to `main.tf`:

```hcl
# Generates 6 random characters once, and remembers them in state
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_account" "main" {
  name                     = "stdglab02${random_string.suffix.result}"   # e.g. stdglab02k3x9pq
  resource_group_name      = azurerm_resource_group.main.name             # ← a REFERENCE
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"            # cheapest: 3 copies in one datacentre
  min_tls_version          = "TLS1_2"         # security baseline

  allow_nested_items_to_be_public = false     # no anonymous public blobs

  blob_properties {                           # a nested block: settings for the blob service
    versioning_enabled = true                 # keep previous versions of files
    delete_retention_policy {
      days = 7                                # deleted files can be recovered for 7 days
    }
  }

  tags = azurerm_resource_group.main.tags     # reuse the RG's tags
}
```

**References create the order.** `azurerm_resource_group.main.name` means "the `name` of the resource group called `main`". Because the storage account refers to the resource group, Terraform knows it must create the resource group **first**. You never write the order yourself.

```bash
terraform plan        # Plan: 2 to add (random_string + storage account). The RG is unchanged
terraform apply
```

### Step 5 — Add a container, and use a saved plan

Append:

```hcl
resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}
```

This time, **save the plan to a file and apply exactly that file**, the way pipelines do:

```bash
terraform plan -out=tfplan      # review it: Plan: 1 to add
terraform apply tfplan          # no question asked: it applies exactly what you reviewed
```

> Why bother? Between a plain `plan` and a later `apply`, the code or Azure could change. A saved plan guarantees that what you approved is what happens.

### Step 6 — Outputs, and "who am I?"

Create `outputs.tf`:

```hcl
output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "storage_account_name" {
  value = azurerm_storage_account.main.name
}

output "blob_endpoint" {
  value = azurerm_storage_account.main.primary_blob_endpoint
}
```

And `whoami.tf` (copy it from the [reference solution](labs/lab02-storage-account/whoami.tf)): it asks the provider which identity it logged in with.

```bash
terraform apply
terraform output terraform_identity
```

```text
{
  "client_id" = "04b07795-8ddb-461a-bbee-02f9e1bf7b46"   ← the Azure CLI's own app ID = "logged in as a USER via az login"
  "object_id" = "<your user's object ID>"
  ...
}
```

Keep this file. In Lab 2.2 the same output will show the service principal instead.

### Step 7 — Check it in Azure

```bash
az group show -n rg-dg-lab02 -o table
az storage account list -g rg-dg-lab02 -o table
az storage container list --account-name $(terraform output -raw storage_account_name) --auth-mode login -o table
```

The last command may fail with an authorisation error. Read Part A.4's *management plane vs data plane* note: you are Contributor (management plane), but listing containers with `--auth-mode login` needs a data role. Try `--auth-mode key` instead, which uses the account key that Contributor *can* read.

### Step 8 — Change something: update in place (`~`)

Add `env = "dev"` to the resource group's tags and run `terraform plan`:

```text
  ~ resource "azurerm_resource_group" "main" {
      ~ tags = {
          + "env"    = "dev"
            # (2 unchanged elements hidden)
        }
    }
  # azurerm_storage_account.main will be updated in-place   ← it copies the RG's tags
Plan: 0 to add, 2 to change, 0 to destroy.
```

`~` means **updated in place**: the resource stays, only the setting changes. Apply it.

### Step 9 — Some changes destroy things: replace (`-/+`). Read only, do not apply!

Change the resource group's `location` to `"southindia"` and run `terraform plan`:

```text
-/+ resource "azurerm_resource_group" "main" {
      ~ location = "centralindia" -> "southindia" # forces replacement
...
Plan: 3 to add, 0 to change, 3 to destroy.
```

A resource group can't move region, so Terraform must **delete it and create a new one**, and everything inside it too. In production that means **data loss**. Always search a plan for `forces replacement` and `destroy`. **Change it back to `centralindia`**, and plan again to confirm `No changes`.

### Step 10 — Someone changed it in the Portal: drift

```bash
az group update -n rg-dg-lab02 --set tags.manual=true    # a colleague "fixes" something by hand
terraform plan -refresh-only      # shows ONLY what changed outside Terraform
terraform plan                    # Terraform wants to REMOVE the manual tag
```

The code is the source of truth. A manual change is either added to the code (keep it) or overwritten by `apply` (undo it). Run `terraform apply` to undo it.

> ⚠️ **Do not destroy yet.** Lab 2.2 uses these resources.

---

## Lab 2.2 — Run Terraform as a service principal, with least privilege

**Scripts:** [labs/lab02-service-principal](labs/lab02-service-principal/)

Pipelines can't type `az login` in a browser. They need their own identity. You will create one with **exactly** the rights it needs, use it, and watch it get refused outside its scope.

```text
sp-tf-training-dg
 ├── Reader       on /subscriptions/<sub>                 → can read, check providers, run plan
 └── Contributor  on /subscriptions/<sub>/resourceGroups/rg-dg-lab02 → can change ONLY this group
```

### Step 1 — Create the service principal

From the course repository folder (you need the permissions from Part A.5):

```powershell
.\02-azure-first-deployment\labs\lab02-service-principal\create-spn.ps1 -Student dg
```

```bash
./02-azure-first-deployment/labs/lab02-service-principal/create-spn.sh dg
```

<details><summary>What the script runs (the same commands, by hand)</summary>

```bash
SUB_ID=$(az account show --query id -o tsv)

# Creates the app registration + service principal + client secret, and gives Contributor on ONE resource group
az ad sp create-for-rbac --name sp-tf-training-dg \
  --role Contributor \
  --scopes /subscriptions/$SUB_ID/resourceGroups/rg-dg-lab02 \
  --years 1

# Output (shown ONCE, so copy it now):
# {
#   "appId":       "0a1b2c3d-...",    → ARM_CLIENT_ID
#   "displayName": "sp-tf-training-dg",
#   "password":    "Xy8Q~...",        → ARM_CLIENT_SECRET
#   "tenant":      "72f988bf-..."     → ARM_TENANT_ID
# }

# Adds Reader on the whole subscription
az role assignment create --assignee <appId> --role Reader --scope /subscriptions/$SUB_ID
```
</details>

Check the result in the Portal: **Resource group rg-dg-lab02 → Access control (IAM) → Role assignments**. You'll see `sp-tf-training-dg` with **Contributor**. On the subscription's IAM page it has **Reader**.

### Step 2 — Give Terraform the service principal's credentials

Paste the four lines the script printed into **the terminal where you run Terraform**:

```powershell
$env:ARM_CLIENT_ID       = "<appId>"
$env:ARM_CLIENT_SECRET   = "<password>"
$env:ARM_TENANT_ID       = "<tenant>"
$env:ARM_SUBSCRIPTION_ID = "<subscription id>"
```

These live only in this terminal window. Close it and they're gone. **Never** put them in a `.tf` or `.tfvars` file.

### Step 3 — Prove Terraform is no longer using your login

```bash
az logout                       # you are now logged out of the Azure CLI
cd ~/tf-labs/lab02
terraform plan                  # still works! No resource changes, only "Changes to Outputs":
                                #   terraform_identity.client_id  04b07795-… → <the SPN's appId>
terraform apply                 # records the new output value
terraform output terraform_identity
```

```text
{
  "client_id" = "0a1b2c3d-..."      ← now the SERVICE PRINCIPAL's appId
  "object_id" = "<the SPN's object ID>"
}
```

### Step 4 — An allowed change works

Add a tag `deployed_by = "spn"` to the resource group and `terraform apply`. It succeeds: the SPN is Contributor on this resource group.

### Step 5 — Something outside its scope fails (on purpose)

Copy [scope-test.tf.example](labs/lab02-service-principal/scope-test.tf.example) into your lab folder as `scope-test.tf`, and apply:

```text
Error: creating Resource Group "rg-dg-outside": ... AuthorizationFailed: The client '0a1b2c3d-...'
does not have authorization to perform action 'Microsoft.Resources/subscriptions/resourcegroups/write'
over scope '/subscriptions/.../resourceGroups/rg-dg-outside'
```

**Read the error.** It tells you **who** (the client ID), **what** action was refused, and **where** (the scope). That's the template for every permission error you'll ever debug. Delete `scope-test.tf`.

> **What if the error mentions resource provider registration?** By default the azurerm provider checks (and if needed registers) Azure resource providers at **subscription** level. A Reader-only identity can check but not register. If a provider is unregistered, either an admin registers it once (`az provider register -n Microsoft.Storage`), or you add `resource_provider_registrations = "none"` to the `provider "azurerm"` block for limited identities.

### Step 6 — Switch back to yourself, and clean up

```powershell
Remove-Item Env:ARM_CLIENT_ID, Env:ARM_CLIENT_SECRET, Env:ARM_TENANT_ID
az login
```

```bash
unset ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_TENANT_ID
az login
```

```bash
terraform output terraform_identity     # client_id back to 04b07795-… (you)
terraform destroy                       # delete the lab resources, as yourself
```

Then delete the service principal (role assignments first, then the app):

```powershell
.\02-azure-first-deployment\labs\lab02-service-principal\delete-spn.ps1 -Student dg
```

```bash
./02-azure-first-deployment/labs/lab02-service-principal/delete-spn.sh dg
```

### Service principal facts to remember

| Topic | What to know |
|---|---|
| **Secret expiry** | Default 1 year. An expired secret means every pipeline fails with `AADSTS7000222`. Rotate with `az ad sp credential reset --id <appId>` |
| **Certificate instead of secret** | `az ad sp create-for-rbac --create-cert …`, then `ARM_CLIENT_CERTIFICATE_PATH`. Harder to leak by copy-paste |
| **No secret at all** | OIDC federation (Module 12) or managed identity. The modern default |
| **Where secrets live** | A pipeline secret store or Key Vault, never Git, never chat messages |
| **Who owns it** | Give each SPN an owner and a description, or nobody will know what it's for in a year |

---

## Lab 2.3 — Several providers in one configuration (30 min)

**Exam objective 2c** · **Reference solution:** [labs/lab02-multi-provider](labs/lab02-multi-provider/)

Real configurations almost always use several providers. This lab uses four:

| Provider | Talks to | Used for |
|---|---|---|
| `azurerm` (default) | Azure Resource Manager | Primary region resources |
| `azurerm` **alias `dr`** | Azure Resource Manager (another region, or another subscription) | Disaster-recovery copies |
| `azuread` | Microsoft Graph (Entra ID) | Look up the signed-in user |
| `random` | No API (runs locally) | Unique name suffixes |

### Key syntax

```hcl
provider "azurerm" {            # DEFAULT configuration (no alias)
  features {}
}

provider "azurerm" {            # ADDITIONAL configuration of the same provider
  alias = "dr"
  features {}
  # subscription_id = var.dr_subscription_id   ← production: DR in its own subscription
}

resource "azurerm_resource_group" "dr" {
  provider = azurerm.dr         # <PROVIDER NAME>.<ALIAS>  (no quotes)
  name     = "rg-dg-app-dr"
  location = "southindia"
}
```

### Steps

```bash
cd ~/tf-labs/lab02-multi && cp <course>/02-azure-first-deployment/labs/lab02-multi-provider/main.tf .
terraform init                  # downloads THREE providers. Read the output
terraform providers             # shows the provider tree
terraform apply -var="student=dg"
az group list --query "[?tags.owner=='dg'].{name:name, location:location}" -o table
```

### Questions to discuss

1. Remove `provider = azurerm.dr` from `azurerm_resource_group.dr` and plan. What changes? (The resource now uses the default provider, but `location` still says southindia. Aliases matter most when they point to **different subscriptions or credentials**.)
2. Look at `.terraform.lock.hcl`. How many providers are locked? Which versions?
3. What happens if you reference `azurerm.dr` without declaring that alias? (`Provider configuration not present`.)

Clean up: `terraform destroy -var="student=dg"`

---

## Troubleshooting: login and permission errors

| Error message (part of it) | What it means | Fix |
|---|---|---|
| `subscription ID could not be determined` | azurerm version 4 needs to know the subscription | Set `ARM_SUBSCRIPTION_ID` (Step 1) |
| `Please run 'az login' to setup account` | No credentials configured and no CLI login | `az login`, or set the `ARM_*` variables |
| `AuthorizationFailed ... does not have authorization to perform action 'X' over scope 'Y'` | The identity is known but has no role allowing action X at scope Y | Give the identity a role that includes X at scope Y (or a higher scope) |
| `AADSTS7000215: Invalid client secret provided` | Wrong secret (often copied with a missing character, or the client ID is wrong) | Reset the secret: `az ad sp credential reset --id <appId>` |
| `AADSTS7000222: The provided client secret keys ... are expired` | The secret expired | Rotate it, or move to OIDC |
| `AADSTS700016: Application with identifier ... was not found` | Wrong `ARM_CLIENT_ID` or wrong `ARM_TENANT_ID` | Check both values |
| `The subscription is not registered to use namespace 'Microsoft.Storage'` | The resource provider isn't registered in this subscription | `az provider register -n Microsoft.Storage` (needs subscription-level rights) |
| `StorageAccountAlreadyTaken` | Someone, somewhere, already uses that name | Keep the random suffix |
| `403 ... This request is not authorized to perform this operation` on blobs | Management-plane role but no data-plane role | Add *Storage Blob Data Contributor*, or use `--auth-mode key` |
| Terraform used the wrong identity | Leftover `ARM_CLIENT_*` variables in the terminal | Check `terraform output terraform_identity`, then clear the variables |

---

## Challenge (optional, 15 min)

**Reference solution:** [labs/lab02-challenge-solution](labs/lab02-challenge-solution/)

1. Add a second container named `logs`, and a **lifecycle management policy** (`azurerm_storage_management_policy`) that deletes blobs in `logs/` after 30 days.
2. Upload a local file with `azurerm_storage_blob` (`source = "index.html"`). Change the file's contents and plan. What does Terraform detect, and why? (Hint: `content_md5`.)

---

## 🏭 In production

* **Pin every provider** with `~>` and commit `.terraform.lock.hcl`. Upgrade providers in a dedicated pull request, never as a side effect of another change.
* **One provider alias per subscription** is the standard landing-zone pattern: `azurerm.connectivity`, `azurerm.management`, `azurerm.identity`.
* **Never run `apply` without a saved plan** in shared environments. Laptops are for sandboxes only.
* **Name things for humans and scripts:** a predictable name such as `st<app><env><region>` lets the support team find resources at 3 a.m.

## 🎓 Exam corner (objectives 2a–2d, 3a–3g)

1. **True or false:** `terraform init` must be re-run after adding a new provider. → **True.**
2. Which file records the exact provider versions and checksums selected by `init`? → `.terraform.lock.hcl`.
3. How do you tell a resource to use a non-default provider configuration? → The `provider = <name>.<alias>` meta-argument.
4. **Choose two:** which commands make changes to real infrastructure? `plan`, `apply`, `validate`, `destroy`, `fmt` → **apply, destroy.**
5. Which command upgrades providers to the newest versions allowed by the constraints? → `terraform init -upgrade`.
6. **True or false:** `terraform plan` refreshes state by default. → **True** (disable it with `-refresh=false`).

## Knowledge check

1. Which two questions does Azure ask on every request, and what answers each one?
2. What three objects does `az ad sp create-for-rbac` create?
3. Your pipeline's service principal must create VMs and assign a managed identity a role on a Key Vault. Which roles does it need?
4. Why should Terraform's identity never be **Owner**?
5. You are Contributor on a storage account but can't list its blobs with `--auth-mode login`. Why?
6. How do you check which identity Terraform actually used?
7. Why does a storage account need a random suffix?
8. What is the difference between `terraform plan -out=tfplan && terraform apply tfplan` and `terraform apply`?

<details><summary>Answers</summary>

1. "Who are you?" (authentication, answered by an identity in Entra ID) and "What may you do, where?" (authorization, answered by role assignments: a role on a scope).
2. An app registration (with the client ID and secret), a service principal in your tenant, and a role assignment (when you pass `--role` and `--scopes`).
3. **Contributor** (to create VMs) plus **User Access Administrator** or **Role Based Access Control Administrator** (to create role assignments), at the smallest scope that covers both.
4. Owner can grant itself and others any access. A leaked Owner credential is a full takeover. Contributor plus narrowly scoped role-assignment rights is enough.
5. Contributor is a **management plane** role. Reading blob data needs a **data plane** role such as Storage Blob Data Reader/Contributor (or key-based access).
6. Output the `azurerm_client_config` data source (`whoami.tf`): `client_id` and `object_id` show the identity.
7. Storage account names are global DNS names (`<name>.blob.core.windows.net`) and must be unique worldwide.
8. A saved plan is applied exactly as reviewed. Plain `apply` creates a fresh plan, which may differ if the code or the infrastructure changed in the meantime.
</details>
