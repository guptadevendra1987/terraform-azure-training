# Module 01 — Infrastructure as Code & Terraform Fundamentals

**Duration:** 2 hours (45 min theory · 75 min labs) · **Level:** Beginner
**Exam objectives:** 1a, 1b, 1c, 2b, 2d, 3a–3c, 3g

> 📋 **Ticket PLAT-101** — Welcome to Contoso Retail India! Our infrastructure was built by hand in the Portal and nobody can rebuild it. Prove to the team that Terraform can create, change and destroy infrastructure predictably, with no cloud cost yet.

## Learning objectives

- Explain IaC and why declarative tools beat click-ops and ad-hoc scripts
- Place Terraform alongside ARM, Bicep, Pulumi, and Ansible
- Describe Terraform's architecture: Core, providers, state, and the dependency graph
- Run the core workflow `init → validate → plan → apply → destroy` with confidence
- Read and write basic HCL: blocks, arguments, expressions, and comments

---

## 1. Concepts

### 1.1 Why Infrastructure as Code?

| Problem with manual (Portal) changes | How IaC solves it |
|---|---|
| "Works in dev, breaks in prod": environments drift apart | The same code deploys every environment |
| No audit trail of who changed what | Git history and pull-request reviews |
| Slow, error-prone rebuilds | Repeatable `apply` in minutes |
| Knowledge lives in one engineer's head | The code *is* the documentation |
| Hard to estimate the impact of a change | `terraform plan` shows the change before it happens |

### 1.2 Declarative vs imperative

```text
Imperative (az CLI script)               Declarative (Terraform)
---------------------------              ------------------------
az group create -n rg1 ...               resource "azurerm_resource_group" "rg" {
az network vnet create ...                 name     = "rg1"
# Run it twice → "already exists" error    location = "centralindia"
                                         }
                                         # Run it 100 times → no changes. Idempotent.
```

You describe **what** you want (the desired state). Terraform works out **how** to get there.

### 1.3 Terraform compared with other tools

| Tool | Scope | Language | State | Notes |
|---|---|---|---|---|
| **Terraform / OpenTofu** | Multi-cloud plus SaaS (GitHub, Datadog, Entra ID…) | HCL | State file | Largest provider ecosystem |
| ARM templates | Azure only | JSON | Azure itself | Verbose |
| Bicep | Azure only | Bicep DSL | Azure itself | Good DSL, Azure-only, day-0 support for new features |
| Pulumi | Multi-cloud | TS/Python/Go/C# | State file | General-purpose languages |
| Ansible | Config management | YAML | None (mostly) | Better for configuring *inside* VMs |

> **Trainer talking point:** most enterprises combine tools: **Terraform** provisions the infrastructure, **Ansible/cloud-init** configures the OS, and **Helm/GitOps** deploys apps on Kubernetes.

### 1.4 How Terraform works

```text
 ┌──────────────┐     ┌───────────────────┐     ┌───────────────────────┐
 │  *.tf files  │ ──▶ │  Terraform Core   │ ──▶ │  Provider plugin      │ ──▶  Azure Resource Manager API
 │  (desired)   │     │  - parse HCL      │ RPC │  (hashicorp/azurerm)  │      (management.azure.com)
 └──────────────┘     │  - build graph    │     └───────────────────────┘
                      │  - diff vs state  │
 ┌──────────────┐     │  - plan / apply   │
 │ terraform.   │ ◀─▶ │                   │
 │ tfstate      │     └───────────────────┘
 │ (known)      │
 └──────────────┘
```

* **Core**: the `terraform` binary. It reads your config, builds a **dependency graph**, and calculates the diff.
* **Providers**: plugins downloaded from the [Terraform Registry](https://registry.terraform.io) during `init`. Azure uses `azurerm`, `azapi`, and `azuread`.
* **State**: Terraform's record of what it created. It maps `azurerm_resource_group.rg` to a real Azure resource ID.

### 1.5 The core workflow

| Command | What it does | Touches Azure? |
|---|---|---|
| `terraform init` | Downloads providers and modules and configures the backend | No |
| `terraform fmt` | Rewrites files in the canonical style | No |
| `terraform validate` | Checks syntax and internal consistency | No |
| `terraform plan` | Refreshes state, compares it with the config, and shows the proposed changes | Reads only |
| `terraform apply` | Runs the plan (asks for confirmation) | **Yes** |
| `terraform destroy` | Deletes everything in state | **Yes** |

Plan symbols: `+` create · `-` destroy · `~` update in place · `-/+` replace (destroy, then create) · `<=` read (data source)

### 1.6 HCL syntax crash course

```hcl
# Single-line comment
// also a comment
/* multi-line
   comment */

<BLOCK TYPE> "<LABEL 1>" "<LABEL 2>" {
  argument_name = expression          # argument
  nested_block {                      # nested block
    key = "value"
  }
}

resource "azurerm_resource_group" "web" {   # type = azurerm_resource_group, local name = web
  name     = "rg-web-dev"                   # string
  location = "centralindia"
  tags = {                                  # map
    env = "dev"
  }
}
# Reference elsewhere as: azurerm_resource_group.web.name
```

Data types: `string`, `number`, `bool`, `list(...)`, `set(...)`, `map(...)`, `object({...})`, `tuple([...])`, and `null`.

### 1.7 Files Terraform creates

| File/folder | Commit to Git? | Purpose |
|---|---|---|
| `*.tf` | ✅ | Your configuration |
| `.terraform.lock.hcl` | ✅ | Locks provider versions and checksums |
| `.terraform/` | ❌ | Downloaded providers and modules |
| `terraform.tfstate` | ❌ **never** | State. It can contain secrets |
| `*.tfvars` | ⚠️ depends | Variable values. Never commit ones that hold secrets |

---

## 2. Lab 1.1 — Hello Terraform (no cloud account needed)

**Goal:** learn the workflow with zero cost and zero risk, using the `local` and `random` providers.

**Reference solution:** [labs/lab01-hello-terraform](labs/lab01-hello-terraform/)

### Step 1 — Create the folder and file

```bash
mkdir -p ~/tf-labs/lab01 && cd ~/tf-labs/lab01
code main.tf
```

### Step 2 — Write the configuration

```hcl
terraform {
  required_version = ">= 1.9"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

resource "random_pet" "server" {
  length    = 2
  separator = "-"
}

resource "local_file" "welcome" {
  filename = "${path.module}/output/welcome.txt"
  content  = <<-EOT
    Hello from Terraform!
    Your server name is: ${random_pet.server.id}
    Terraform workspace: ${terraform.workspace}
  EOT
}

output "server_name" {
  value = random_pet.server.id
}

output "file_path" {
  value = local_file.welcome.filename
}
```

### Step 3 — Run the workflow

```bash
terraform init          # look at the .terraform/ folder and the .terraform.lock.hcl file
terraform fmt           # no output means the file was already formatted
terraform validate      # Success! The configuration is valid.
terraform plan          # 2 to add, 0 to change, 0 to destroy
terraform apply         # type 'yes'
cat output/welcome.txt
terraform output server_name
```

### Step 4 — Explore state

```bash
terraform state list                       # random_pet.server, local_file.welcome
terraform state show random_pet.server
cat terraform.tfstate                      # it's plain JSON!
```

### Step 5 — Observe idempotency and drift

```bash
terraform apply                    # "No changes." Running it again changes nothing
rm output/welcome.txt              # simulate drift (someone deleted the resource)
terraform plan                     # Terraform notices and plans to re-create the file
terraform apply -auto-approve
```

### Step 6 — Force a replacement

```bash
terraform apply -replace="random_pet.server"
# The pet name changes AND local_file changes too, because it depends on the pet name.
# Look for "-/+ must be replaced" in the plan output.
```

### Step 7 — Look at the dependency graph

```bash
terraform graph > graph.dot
# Paste the content into https://dreampuf.github.io/GraphvizOnline to visualise it
```

### Step 8 — Clean up

```bash
terraform destroy
```

---

## 3. Lab 1.2 — Workflow drills (break → read the error → fix)

Each drill trains you to **read Terraform errors**, which is the most valuable debugging skill. Make one change at a time, run the command shown, read the error, then undo the change.

| # | Break it | Run | What you learn |
|---|---|---|---|
| 1 | Delete the closing `}` of `random_pet` | `terraform validate` | Syntax errors include file and line numbers |
| 2 | Change `length = 2` to `length = "two"` | `terraform validate` | Type checking |
| 3 | Reference `random_pet.serverx.id` | `terraform validate` | "Reference to undeclared resource" |
| 4 | Change the `random` version to `~> 99.0` | `terraform init -upgrade` | Version constraint resolution |
| 5 | Remove the `random` block from `required_providers`, delete `.terraform`, run init | `terraform init` | Terraform infers `hashicorp/random`, but **always declare providers explicitly** |
| 6 | Badly indent some lines | `terraform fmt -check -diff` | How CI enforces formatting |

### Version constraint operators

| Constraint | Meaning |
|---|---|
| `= 3.6.2` | Exactly this version |
| `>= 3.6` | This version or newer |
| `~> 3.6` | `>= 3.6, < 4.0` (any minor/patch release in 3.x) |
| `~> 3.6.2` | `>= 3.6.2, < 3.7.0` (patch releases only) |
| `>= 3.0, < 3.8` | A range |

---

## 4. Challenge (15 min)

1. Add a `random_password` resource (length 16, with special characters) and an output that shows it. What does Terraform show for the output? Add `sensitive = true` to the output and compare.
2. Then run `terraform output -raw <name>` and `grep result terraform.tfstate`. **Lesson:** sensitive values are still stored in plain text in state, so the state file must be protected.

---


## 🏭 In production

* **Day 1 rule at most companies:** nothing in prod is created by hand. If it's not in Git, it doesn't exist.
* **State is the crown jewel.** In Lab 1.1 it is a local file. In production it lives in locked, encrypted, access-controlled remote storage (Module 06) and is never committed to Git.
* **Pin versions from the first commit** (`required_version`, `required_providers`). "It worked on my laptop" usually means a different provider version.
* **Read the plan every time.** Senior engineers spend more time reading plans than writing HCL.


## 🎓 Exam corner

1. **True or false:** Terraform configuration is declarative. → **True.**
2. **Choose two** advantages of IaC: version control and peer review / guaranteed lower cloud bill / repeatable environments / no need for testing → **version control and review, repeatable environments.**
3. Which command initialises a working directory? → `terraform init`.
4. **True or false:** `terraform validate` needs access to your cloud account. → **False.**
5. What does `terraform fmt -check` do in CI? → Exits non-zero if any file isn't canonically formatted, without changing files.

## 5. Knowledge check

1. What is the difference between `terraform plan` and `terraform apply`?
2. Which files belong in Git, and which must never be committed?
3. What does `~> 2.5` allow?
4. What does `-/+` mean in a plan?
5. Where does Terraform download providers from, and where does it store them locally?

<details><summary>Answers</summary>

1. `plan` computes and shows the changes without making them. `apply` makes the changes (and creates its own plan first unless you give it a saved plan file).
2. Commit `*.tf` and `.terraform.lock.hcl`. Never commit `terraform.tfstate*`, `.terraform/`, or tfvars files that contain secrets.
3. `>= 2.5.0` and `< 3.0.0`.
4. The resource is replaced: it is destroyed and created again, usually because an argument that forces a new resource changed.
5. From the Terraform Registry (`registry.terraform.io`), into `.terraform/providers/`.
</details>
