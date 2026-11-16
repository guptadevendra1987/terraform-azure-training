# Module 09 — Managing Multiple Environments

**Duration:** 1.5 hours (20 min theory · 1h10 labs) · **Level:** Intermediate → Advanced
**Exam objectives:** 6a, 6c, 8c

> 📋 **Ticket PLAT-109** — The same code must deploy dev and prod. Last month a dev pipeline changed prod by accident. Design environment separation that makes that impossible.

## Learning objectives

- Compare the main multi-environment patterns: CLI workspaces, per-environment tfvars + backends, directory per environment, and Terragrunt or HCP Terraform
- Use `terraform.workspace` correctly, and know when **not** to use workspaces
- Build one configuration that deploys dev and prod with different inputs and separate state
- Promote changes safely from dev to prod
- Protect production with resource locks and per-subscription separation

---

## 1. Concepts

### 1.1 The patterns

| Pattern | How | Pros | Cons |
|---|---|---|---|
| **CLI workspaces** | `terraform workspace new prod`. One config, state per workspace | Quick, no duplication | Easy to apply to the wrong workspace; same backend and credentials for all environments; env differences hidden in maps |
| **tfvars + backend config per env** | `env/dev/terraform.tfvars` + `env/dev/backend.hcl` | One codebase, explicit inputs, separate state accounts possible | Requires a wrapper script or pipeline discipline (`-reconfigure`) |
| **Directory per env** | `live/dev/main.tf`, `live/prod/main.tf`, both calling versioned modules | Very explicit; prod can pin module `v1.2`, dev `v1.3` | Some duplication of root code |
| **Terragrunt** | `terragrunt.hcl` per env, DRY backend and inputs | Very DRY at scale, dependency orchestration | Extra tool to learn |
| **HCP Terraform / Spacelift / env0** | Remote workspaces with variables, RBAC, policies | Central governance, UI, run history | Cost, SaaS dependency |

> **Expert recommendation for Azure:**
> * **Separate subscriptions** for prod and non-prod (blast radius, RBAC, Azure Policy, cost).
> * **Separate state storage** (or at least separate containers) per environment, so a dev pipeline identity *cannot* read prod state.
> * Use **tfvars + backend per env** or **directory per env**. Keep CLI workspaces for short-lived copies (feature branches, test stacks).

### 1.2 Typical enterprise repository

```text
infra-live/
├── modules/                    # or consumed from a module registry/repo with ?ref=vX.Y.Z
├── stacks/
│   ├── network/                # each stack = its own state, small blast radius
│   │   ├── *.tf
│   │   └── env/
│   │       ├── dev/  {terraform.tfvars, backend.hcl}
│   │       └── prod/ {terraform.tfvars, backend.hcl}
│   └── app/
└── pipelines/                  # dev → (approval) → prod
```

### 1.3 Promotion flow

```text
 PR opened ──▶ fmt/validate/lint/test ──▶ plan dev + plan prod (comment on PR)
 merge ──▶ apply dev ──▶ smoke test ──▶ manual approval ──▶ apply prod (same commit!)
```

The same commit, the same module versions, and different inputs. Never "fix it in prod only".

---

## 2. Lab 9.1 — CLI workspaces (30 min)

**Reference solution:** [labs/lab09-workspaces](labs/lab09-workspaces/)

```bash
terraform init
terraform workspace list                 # * default
terraform workspace new dev
terraform apply -var="student=dg"        # rg-dg-ws-dev, 10.91.0.0/16
terraform workspace new prod
terraform apply -var="student=dg"        # rg-dg-ws-prod, southindia, 10.92.0.0/16
terraform workspace select dev
terraform state list
ls terraform.tfstate.d/                  # local backend: one folder per workspace
```

Key code:

```hcl
locals {
  settings = {
    dev  = { location = "centralindia", address_space = "10.91.0.0/16" }
    prod = { location = "southindia",   address_space = "10.92.0.0/16" }
  }
  cfg = local.settings[terraform.workspace]     # fails loudly for unknown workspaces
}
```

**Discussion: the danger.** You run `terraform destroy` thinking you're in dev, but `terraform workspace show` says `prod`. Mitigations: show the workspace in your shell prompt, and use pipelines rather than laptops for prod.

With the azurerm backend, workspaces are stored as `<key>env:<workspace>` blobs. Look in the container.

Clean up: `terraform destroy` in **each** workspace, then `terraform workspace select default && terraform workspace delete dev`.

---

## 3. Lab 9.2 — One codebase, per-environment inputs and backends (60 min)

**Reference solution:** [labs/lab09-multi-env](labs/lab09-multi-env/)

### Step 1 — Structure

```text
lab09-multi-env/
├── providers.tf         # backend "azurerm" {}   ← empty: partial configuration
├── variables.tf
├── main.tf              # calls the Module 07 vnet module
├── deploy.sh / deploy.ps1
└── env/
    ├── dev/  terraform.tfvars  backend.hcl   (key = lab09/app-dev.tfstate)
    └── prod/ terraform.tfvars  backend.hcl   (key = lab09/app-prod.tfstate, enable_delete_lock = true)
```

### Step 2 — Fill in the backend files

Edit `env/*/backend.hcl` with your state storage account from Module 06. Copy `terraform.tfvars.example` to `terraform.tfvars` in each env folder.

### Step 3 — Deploy dev, then prod

```bash
./deploy.sh dev plan
./deploy.sh dev apply
./deploy.sh prod plan
./deploy.sh prod apply
```

```powershell
.\deploy.ps1 -Env dev -Action plan
.\deploy.ps1 -Env dev -Action apply
```

Why `-reconfigure`? Switching environments means switching backend configuration. Without it, Terraform asks whether to **migrate** dev state into prod, and answering "yes" would be a disaster.

### Step 4 — Make a change and promote it

1. Add a `mgmt = { netnum = 10 }` subnet to **dev** only. Plan and apply dev.
2. Verify, then add it to prod's tfvars. Plan prod: the plan shows exactly one subnet added.

### Step 5 — Prove the prod lock works (and learn its limits)

```bash
az group delete -n rg-dg-app-prod --yes      # fails: ScopeLocked. Portal and CLI accidents are blocked
./deploy.sh prod plan                        # no changes
```

Now plan a destroy: `terraform plan -destroy -var-file=env/prod/terraform.tfvars`. The lock **depends on** the resource group, so Terraform deletes the lock *first* and then the RG. An Azure lock protects against out-of-band deletion, **not** against `terraform destroy`.

To also guard against Terraform itself, combine the lock with:

* `lifecycle { prevent_destroy = true }` on critical resources (it can't be toggled by a variable, so it's a deliberate code change)
* A pipeline that never runs `destroy` for prod, and an identity without delete rights on locks (`Microsoft.Authorization/locks/delete`)

### Step 6 — (Discussion) Directory-per-env alternative

```hcl
# live/prod/main.tf
module "app" {
  source = "git::https://github.com/org/tf-modules.git//app?ref=v1.4.0"   # prod pinned
  environment = "prod"
  # ...
}
# live/dev/main.tf uses ?ref=v1.5.0-rc1 to test the next version first
```

---

## 4. Clean up

```bash
./deploy.sh prod destroy                     # removes the lock first, then everything else
./deploy.sh dev destroy
```

---


## 🏭 In production

* **Prod lives in its own subscription,** with its own state storage and pipeline identity, and dev credentials can't even *read* prod state.
* **The same commit is promoted** from dev to prod. Hotfixing prod directly is how environments drift apart.
* **Environment differences are inputs** (tfvars), reviewed side by side in the PR plan comments for every environment.
* **CLI workspaces** are fine for short-lived feature or test copies, not for environment separation.


## 🎓 Exam corner

1. **True or false:** HCP Terraform workspaces and CLI workspaces are the same thing. → **False.**
2. Where does the local backend keep non-default CLI workspace state? → `terraform.tfstate.d/<name>/`.
3. Which named value returns the current CLI workspace? → `terraform.workspace`.
4. What does `terraform init -reconfigure` do? → Re-initialises the backend while ignoring the saved configuration, without migrating state.

## 5. Knowledge check

1. Name two reasons CLI workspaces are discouraged for dev/prod separation.
2. Why do you need `terraform init -reconfigure` when switching between backend config files?
3. Where should environment differences live, and where should they not?
4. How do you stop a dev pipeline from changing prod?

<details><summary>Answers</summary>

1. All workspaces share one backend and the same credentials, so there's no access isolation. It is also easy to run commands in the wrong workspace, and the environment differences are hidden inside the code.
2. Terraform otherwise detects a backend change and offers to migrate state from the old backend into the new one.
3. In variables or tfvars files (inputs). They should not live in conditionals scattered across resources.
4. Use separate subscriptions and state storage, a separate pipeline identity per environment with RBAC scoped to that environment only, and protected pipeline environments with approvals.
</details>
