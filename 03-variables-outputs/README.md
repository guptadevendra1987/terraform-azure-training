# Module 03 — Variables, Locals & Outputs

**Duration:** 3 hours (Part A 1h30 offline ladder · Part B 1h30 Azure labs) · **Level:** Beginner → Intermediate
**Exam objectives:** 4c, 4d, 4g, 4h

> 📋 **Ticket PLAT-103** — Three teams copied your storage code and hard-coded their names. Make it reusable: one configuration, inputs per environment, company naming and tagging, and clear errors when someone passes bad input.

## Learning objectives

- Declare input variables with types, defaults, descriptions, and validation rules
- Supply values with tfvars files, `-var`, environment variables, and auto-loaded files, and know the precedence order
- Use `locals` to remove repetition and build naming and tagging conventions
- Expose outputs, use `sensitive`, and consume outputs from scripts
- Split code into the standard file layout

---

> **How this module works:** **Part A** teaches one idea per tiny folder. Every folder runs **offline in seconds**, with no Azure account and no provider download, using Terraform's built-in `terraform_data` resource. **Part B** then puts everything together on real Azure resources.

---

## Part A — Variables, locals and outputs, one step at a time (1h30)

### A.1 The big picture

```text
                 INPUTS                        YOUR CONFIGURATION                    RESULTS
          ┌──────────────────┐        ┌───────────────────────────────────┐   ┌──────────────────┐
 you  ──▶ │ variable "env"   │  ───▶  │ locals { name = "rg-app-${env}" } │──▶│ output "rg_name" │ ──▶ you, scripts,
 tfvars   │ variable "size"  │        │ resource ... { name = local.name }│   │ output "rg_id"   │     other modules
 -var     └──────────────────┘        └───────────────────────────────────┘   └──────────────────┘
```

| Concept | Restaurant analogy | Who sets it | Use it as | Can the caller change it? |
|---|---|---|---|---|
| **Variable** (input) | The customer's **order**: "medium, extra cheese" | The person or pipeline running Terraform | `var.name` | ✅ Yes, that's the point |
| **Local** | The kitchen's **preparation**: chop, mix, measure | You, inside the code | `local.name` | ❌ No |
| **Output** | The **dish served** | Calculated by Terraform | `terraform output name`, or `module.x.name` from a parent | ❌ (read-only) |

> **Rule of thumb:** if *users* should choose it, make it a **variable**. If you just want to avoid repeating yourself, make it a **local**. If someone *needs to see or use* it afterwards, make it an **output**.

### A.2 Anatomy of a variable block

```hcl
variable "environment" {                 # ← the NAME. Use it as var.environment
  type        = string                   # ← the SHAPE allowed (step 2)
  description = "dev, test or prod."     # ← shown in prompts and docs. Always write one
  default     = "dev"                    # ← used when nobody gives a value. No default = required
  sensitive   = false                    # ← true hides the value on screen (step 7)
  nullable    = false                    # ← false rejects null

  validation {                           # ← CONTENT rules with your own error message (step 4)
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}
```

Only the name is mandatory. Everything inside the braces is optional, but in real projects you should always set `type` and `description`.

### A.3 The ladder: 7 small steps

All in [labs/variables-step-by-step](labs/variables-step-by-step/). For each step:

```bash
cd labs/variables-step-by-step/step01-first-variable
terraform init
terraform apply -auto-approve
# then do the "TRY THIS" section at the bottom of the file
```

| Step | Concept | What you will SEE |
|---|---|---|
| [01 first variable](labs/variables-step-by-step/step01-first-variable/main.tf) | `variable`, `var.x`, `default`, required variables | Terraform **prompts** you (showing your description), `-var` overrides, pipelines fail without a value |
| [02 types](labs/variables-step-by-step/step02-types/main.tf) | `string` `number` `bool` `list` `set` `map` | `[0]` on a list, `["key"]` on a map, duplicates vanish from a set, type errors before anything is created |
| [03 objects](labs/variables-step-by-step/step03-objects/main.tf) | `object({...})`, `map(object)`, `optional()` | Defaults filled in for missing attributes. **Surprise:** unknown attributes are silently dropped |
| [04 validation](labs/variables-step-by-step/step04-validation/main.tf) | `validation`, `contains`, `regex`, ranges, `alltrue`, cross-variable rules | **Your own** error messages; B-series only, except in prod |
| [05 setting values](labs/variables-step-by-step/step05-setting-values/main.tf) | `default`, `TF_VAR_`, `terraform.tfvars`, `*.auto.tfvars`, `-var-file`, `-var` | **One run prints the whole precedence table** |
| [06 locals](labs/variables-step-by-step/step06-locals/) | `locals`, naming and tags built once, standard file layout | Change one variable and every name changes. Locals can't be set from outside |
| [07 outputs and sensitive](labs/variables-step-by-step/step07-outputs-sensitive/main.tf) | `output`, `-raw`, `-json`, `sensitive` | `<sensitive>` on screen, **but the password is in the state file in plain text** |

### A.4 Who wins? The precedence ladder (step 5)

```text
   lowest priority                                                              highest priority
   ┌─────────┐   ┌──────────────┐   ┌──────────────────┐   ┌───────────────┐   ┌─────────────────────────┐
   │ default │ → │ TF_VAR_name  │ → │ terraform.tfvars │ → │ *.auto.tfvars │ → │ -var-file  /  -var      │
   └─────────┘   │ (environment)│   │ (auto-loaded)    │   │ (auto-loaded, │   │ (command line: the LAST │
                 └──────────────┘   └──────────────────┘   │  A→Z order)   │   │  one written wins)      │
                                                           └───────────────┘   └─────────────────────────┘
```

This is the **real output** of step 5 (each variable is set at a different number of levels):

```text
precedence_table = {
  "a" = "from default"                     ← only a default
  "b" = "from terraform.tfvars"            ← default + terraform.tfvars
  "c" = "from team.auto.tfvars"            ← … + team.auto.tfvars
  "d" = "from extra.tfvars (-var-file)"    ← … + -var-file=extra.tfvars
  "e" = "from -var flag"                   ← … + -var="e=..."
  "f" = "from-TF_VAR"                      ← default + environment variable
  "g" = "from terraform.tfvars"            ← environment variable + terraform.tfvars: the FILE wins
}
```

### A.5 Types cheat card (step 2 and step 3)

| Type | Example value | Get one item | Typical use |
|---|---|---|---|
| `string` | `"centralindia"` | — | Names, regions, SKUs |
| `number` | `3` | — | Counts, sizes, ports |
| `bool` | `true` | — | Feature flags |
| `list(string)` | `["a", "b"]` | `var.x[0]` | Ordered items: DNS servers, CIDRs |
| `set(string)` | `["a", "b"]` | (no index; loop over it) | Unique names for `for_each` |
| `map(string)` | `{ dev = "B1" }` | `var.x["dev"]` or `var.x.dev` | Lookup tables per environment |
| `object({...})` | `{ size = "B2s", disk = 64 }` | `var.x.size` | One thing with several settings |
| `map(object({...}))` | `{ web = { size = "B2s" } }` | `var.x["web"].size` | **Many** things with the same settings: the production favourite |

### A.6 Common mistakes and the real error you'll see

Every message below was produced by the ladder steps.

| Mistake | Error | Fix |
|---|---|---|
| No value for a variable without a default, in CI | `No value for required variable` | Give a default, or set it in tfvars / `TF_VAR_` / `-var` |
| Wrong type: `-var="vm_count=two"` | `Invalid value for input variable` … `a number is required` | Pass the right type |
| Missing a required object attribute | `attribute "size" is required` | Provide it, or make it `optional(...)` |
| Typo in an object attribute (`dsik_gb`) | **No error.** It is silently dropped and the default is used | Read the plan, and validate important values |
| Breaking a validation rule | `Invalid value for variable` + **your** `error_message` | Read the message, then fix the value |
| Trying to set a local: `-var="name_prefix=x"` | `Value for undeclared variable` | Locals are internal. Make it a variable if users must choose it |
| Output uses a sensitive value without `sensitive = true` | `Output refers to sensitive values` | Add `sensitive = true` to the output |
| Map key that doesn't exist: `var.sizes["uat"]` | `Invalid index` | `lookup(var.sizes, "uat", "default")` |

### A.7 Standard file layout (introduced in step 6)

```text
lab/
├── providers.tf          # terraform {} + provider {}
├── variables.tf          # inputs
├── locals.tf             # calculations: names, tags
├── main.tf               # resources
├── outputs.tf            # results
├── terraform.tfvars      # values (auto-loaded; git-ignored when it holds secrets)
└── env/
    ├── dev.tfvars        # -var-file=env/dev.tfvars
    └── prod.tfvars
```

Terraform loads **every** `.tf` file in the folder as one configuration. File names are only for humans.

---

## Part B — Put it all together on Azure (1h30)

Everything from Part A in one real deployment: typed and validated inputs, object variables with optional attributes, locals for naming and tags, per-environment tfvars files, and sensitive outputs.

### Lab 3.1 — Parameterise the storage deployment

**Reference solution:** [labs/lab03-variables](labs/lab03-variables/)

Start by copying your Lab 02 code into `~/tf-labs/lab03`, then refactor it.

#### Step 1 — `variables.tf`

```hcl
variable "student" {
  type        = string
  description = "Your initials (2-6 lowercase letters/digits). Used in names and tags."

  validation {
    condition     = can(regex("^[a-z0-9]{2,6}$", var.student))
    error_message = "student must be 2-6 lowercase letters or digits."
  }
}

variable "workload" {
  type        = string
  description = "Short workload name used in resource names."
  default     = "app"
}

variable "environment" {
  type        = string
  description = "Deployment environment."
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "location" {
  type        = string
  description = "Azure region."
  default     = "centralindia"
}

variable "storage" {
  description = "Storage account settings."
  type = object({
    tier             = optional(string, "Standard")
    replication_type = optional(string, "LRS")
    containers       = optional(list(string), ["data"])
    retention_days   = optional(number, 7)
  })
  default = {}

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "RAGRS", "GZRS", "RAGZRS"], var.storage.replication_type)
    error_message = "storage.replication_type is not a valid Azure replication type."
  }

  validation {
    condition     = var.storage.retention_days >= 1 && var.storage.retention_days <= 365
    error_message = "storage.retention_days must be between 1 and 365."
  }
}

variable "extra_tags" {
  type        = map(string)
  description = "Additional tags merged onto every resource."
  default     = {}
}
```

#### Step 2 — `locals.tf`

```hcl
locals {
  # Naming convention: <type>-<student>-<workload>-<env>
  name_suffix = "${var.student}-${var.workload}-${var.environment}"

  # Storage names: no dashes, at most 24 characters
  storage_name = substr(lower("st${var.student}${var.workload}${var.environment}${random_string.suffix.result}"), 0, 24)

  common_tags = merge(var.extra_tags, {
    course      = "tf-azure-training"
    owner       = var.student
    environment = var.environment
    managed_by  = "terraform"
  })

  is_production = var.environment == "prod"
}
```

#### Step 3 — `main.tf`

```hcl
resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_suffix}"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_storage_account" "main" {
  name                     = local.storage_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = var.storage.tier
  # Production always gets zone-redundant storage, whatever the input says
  account_replication_type = local.is_production ? "ZRS" : var.storage.replication_type
  min_tls_version          = "TLS1_2"

  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = var.storage.retention_days
    }
  }

  tags = local.common_tags
}
```

We will create one container per list item in Module 05 with `for_each`. For now, create a single container for `var.storage.containers[0]`.

#### Step 4 — `outputs.tf`

```hcl
output "resource_group_name" {
  description = "Name of the resource group."
  value       = azurerm_resource_group.main.name
}

output "storage_account" {
  description = "Storage account details."
  value = {
    name     = azurerm_storage_account.main.name
    id       = azurerm_storage_account.main.id
    endpoint = azurerm_storage_account.main.primary_blob_endpoint
  }
}

output "storage_primary_key" {
  description = "Primary access key (sensitive)."
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}
```

#### Step 5 — Variable files

`terraform.tfvars` (auto-loaded):

```hcl
student = "dg"
```

`env/dev.tfvars`:

```hcl
environment = "dev"
storage = {
  containers     = ["data", "logs"]
  retention_days = 7
}
extra_tags = {
  cost_center = "training-001"
}
```

`env/prod.tfvars`:

```hcl
environment = "prod"
storage = {
  replication_type = "GRS"   # locals override this to ZRS for prod. Discuss!
  retention_days   = 30
}
```

#### Step 6 — Run with different inputs

```bash
terraform init
terraform plan -var-file=env/dev.tfvars
terraform plan -var-file=env/prod.tfvars       # notice: replication = ZRS, name ends in "prod"
terraform apply -var-file=env/dev.tfvars
```

#### Step 7 — Experiment with precedence

```bash
export TF_VAR_environment=test                                # PowerShell: $env:TF_VAR_environment="test"
terraform plan                                                 # uses "test"
terraform plan -var-file=env/dev.tfvars                        # dev wins (the -var-file is higher)
terraform plan -var-file=env/dev.tfvars -var="environment=prod" # prod wins (the last -var)
unset TF_VAR_environment
```

#### Step 8 — Trigger the validations

```bash
terraform plan -var="student=DevendraG"           # fails the regex
terraform plan -var='storage={replication_type="XYZ"}'
terraform plan -var='storage={retention_days=900}'
```

Read the error messages. Clear errors are a gift to the next engineer.

#### Step 9 — Work with outputs

```bash
terraform output
terraform output storage_primary_key               # shows the value (you asked for it explicitly)
terraform output -json storage_account
SA=$(terraform output -json storage_account | jq -r .name)
az storage account show -n $SA --query sku
```

#### Step 10 — Clean up

```bash
terraform destroy -var-file=env/dev.tfvars
```

---

### Lab 3.2 — `terraform console` playground (15 min)

`terraform console` is a REPL for testing expressions against your config and state.

```bash
terraform console -var-file=env/dev.tfvars
> var.storage
> var.storage.containers[1]
> local.common_tags
> upper(var.student)
> "rg-${var.student}"
> length(var.storage.containers)
> merge({a=1}, {b=2}, {a=3})
> exit
```

---

## Challenges

1. Add a variable `allowed_ip_ranges` (`list(string)`) with a validation that every element is a valid CIDR. Hint: `alltrue([for ip in var.allowed_ip_ranges : can(cidrhost(ip, 0))])`. Use it in the storage account's `network_rules`.
2. Make `location` accept only Indian regions (`centralindia`, `southindia`, `westindia`) **unless** `environment = "dev"`. (Terraform ≥ 1.9 allows a validation to reference other variables.)
3. Add an output that shows the full portal URL of the resource group: `https://portal.azure.com/#@/resource${azurerm_resource_group.main.id}`.

---


## 🏭 In production

* **Validation is documentation that runs.** A clear `error_message` saves the next team a support ticket.
* **No secrets in tfvars in Git.** Pipelines inject them as `TF_VAR_*` from a secret store, or better, the resource never needs one (managed identity).
* **Mandatory tags are merged last** (`merge(var.extra_tags, local.mandatory_tags)`) so nobody can override `owner` or `cost_center`.
* **Outputs are an API.** Other stacks and pipelines depend on them, so renaming an output is a breaking change.


## 🎓 Exam corner

1. Which has higher precedence: `terraform.tfvars` or `-var` on the command line? → `-var`.
2. **True or false:** `*.auto.tfvars` files are loaded automatically. → **True.**
3. A map variable `region_cidrs` — which is valid: `var.region_cidrs["us-east-1"]` or `var.region_cidrs[0]`? → The key lookup. Maps have no index.
4. What does `nullable = false` prevent? → Passing `null` as the variable value.
5. **Choose two:** where can a `validation` condition be declared? variable block / output block / resource lifecycle (as pre/postcondition) / provider block → **variable block, resource lifecycle** (outputs support `precondition` too).

## Knowledge check

1. You pass `-var-file=a.tfvars -var-file=b.tfvars`, and both set `environment`. Which value wins?
2. What is the difference between a variable and a local?
3. Does `sensitive = true` encrypt the value in state?
4. What does `optional(number, 64)` mean in an object type?
5. How do you supply a variable in CI without a file?

<details><summary>Answers</summary>

1. `b.tfvars`. Later arguments override earlier ones.
2. Variables are inputs set by the caller. Locals are internal computed values that the caller cannot override.
3. No. It only redacts the value in CLI output. State still holds it in plain text.
4. The attribute may be omitted, and it then defaults to 64.
5. `TF_VAR_<name>` environment variables, or `-var` flags. Pipeline secrets map to `TF_VAR_*` variables.
</details>
