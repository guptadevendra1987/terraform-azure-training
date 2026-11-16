# Module 10 — Security, Secrets & Governance

**Duration:** 2.5 hours (40 min theory · 1h50 labs) · **Level:** Advanced
**Exam objectives:** 4g, 4h

> 📋 **Ticket PLAT-110** — The audit found a database password in a state file and SSH open to the internet. Fix secrets handling, enforce guardrails with Azure Policy, and scan every PR.

## Learning objectives

- Manage secrets with Azure Key Vault (RBAC model) and keep them out of code
- Grant least-privilege access with `azurerm_role_assignment`, Entra ID groups, and managed identities
- Handle RBAC propagation delays (`time_sleep`) and hidden dependencies
- Author and assign Azure Policy (custom and built-in) with Terraform
- Shift security left with static analysis tools: Checkov, Trivy, and TFLint
- Know the threat model: state, plan files, logs, and provider credentials
- Consume secrets from **HashiCorp Vault** without leaking them into state

---

## 1. Concepts

### 1.1 Where secrets leak in Terraform

| Leak point | Mitigation |
|---|---|
| Hard-coded in `.tf` / `.tfvars` in Git | `TF_VAR_*` from pipeline secrets, Key Vault data sources, git-secrets / gitleaks pre-commit |
| **State file** (always plain text) | Remote backend with RBAC, encryption, private endpoint. Ephemeral resources and write-only arguments (Module 13) |
| **Saved plan files** (`tfplan` contains values) | Treat as secret artifacts; short retention in CI |
| CLI and CI logs | `sensitive = true` on variables and outputs; never `echo` secrets |
| Provider credentials | OIDC or managed identity, so there is no secret to leak |

### 1.2 Key Vault: access policies compared with RBAC

| Access policies (legacy) | **RBAC** (recommended) |
|---|---|
| Configured on the vault | Standard Azure RBAC at vault, secret, or key scope |
| Max 1024 policies | Unlimited, group-based, PIM-eligible |
| `access_policy {}` blocks | `rbac_authorization_enabled = true` + `azurerm_role_assignment` |

Key roles: **Key Vault Administrator**, **Key Vault Secrets Officer** (read and write), **Key Vault Secrets User** (read), **Key Vault Crypto User**.

### 1.3 Least-privilege role assignment pattern

```hcl
resource "azurerm_role_assignment" "x" {
  scope                = <smallest scope possible>              # resource > RG > subscription
  role_definition_name = "<narrowest built-in role>"            # never Owner/Contributor for apps
  principal_id         = <group or managed identity object id>  # not individual users
}
```

### 1.4 Azure Policy with Terraform

```text
Policy definition (rule)  ──▶  Assignment (scope + parameters)  ──▶  Compliance / Deny / Modify / DINE
   azurerm_policy_definition       azurerm_{management_group,subscription,resource_group}_policy_assignment
Initiative (set of definitions): azurerm_policy_set_definition
```

**Terraform and Policy together:** Policy is the *guardrail*: it denies non-compliant deployments from **any** tool. Terraform deploys both the policies (platform team) and compliant resources (app teams).

### 1.5 Static analysis tools

| Tool | Focus | Command |
|---|---|---|
| `terraform validate` | Syntax and types | built-in |
| **TFLint** + azurerm ruleset | Provider-aware lint (invalid VM sizes, deprecated syntax) | `tflint --init && tflint` |
| **Checkov** | Security and compliance policies (CIS, Azure benchmarks) | `checkov -d .` |
| **Trivy** (successor of tfsec) | Misconfiguration scanning | `trivy config .` |
| OPA / Conftest, Sentinel | Custom policy-as-code on **plan JSON** | `terraform show -json plan > plan.json` |

---

## 2. Lab 10.1 — Key Vault with RBAC, generated secrets, and identities

**Reference solution:** [labs/lab10-keyvault-rbac](labs/lab10-keyvault-rbac/)

> Requires **User Access Administrator** or **Owner** (to create role assignments) and permission to create Entra ID groups.

### Step 1 — Providers

Add `azuread`, `random`, and `time` alongside `azurerm`. Configure Key Vault features for the lab:

```hcl
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true   # lab only
      recover_soft_deleted_key_vaults = true
    }
  }
}
```

### Step 2 — Identities and groups

* `azuread_group.app_readers`: a security group, owned by you
* `azurerm_user_assigned_identity.app`: the app identity, which exists before the workload
* `azuread_group_member`: the identity joins the group

### Step 3 — Vault and role assignments

```hcl
resource "azurerm_key_vault" "main" {
  name                       = "kv-${var.student}-lab10-${random_string.suffix.result}"
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = false     # true in production
  soft_delete_retention_days = 7
  # ...
}

resource "azurerm_role_assignment" "deployer_kv_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "readers_kv_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azuread_group.app_readers.object_id
}
```

### Step 4 — Generate and store a secret

```hcl
resource "random_password" "db_admin" {
  length = 24
  # ...
}

resource "time_sleep" "rbac_propagation" {
  depends_on      = [azurerm_role_assignment.deployer_kv_officer]
  create_duration = "60s"
}

resource "azurerm_key_vault_secret" "db_admin" {
  name         = "sql-admin-password"
  value        = random_password.db_admin.result
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [time_sleep.rbac_propagation]      # hidden dependency
}
```

### Step 5 — Experiment: remove the sleep

Comment out `depends_on`, run destroy and then apply. You will often get `403 Forbidden ... does not have secrets set permission`, because RBAC propagation takes up to several minutes. This is a textbook case of a **hidden dependency**, and the reason `depends_on` exists.

### Step 6 — Verify least privilege

```bash
terraform apply -var="student=dg"
az keyvault secret show --vault-name <kv> -n sql-admin-password --query value -o tsv   # works (Officer)
grep -c "sql-admin-password" <(terraform state pull)    # the secret value is in state too
```

**Discussion:** the password exists in the state file. Options are to accept it (with protected state), to let the consuming service generate it (for example, an Entra-only SQL login with no password at all), or to use ephemeral resources and write-only arguments (Module 13).

### Step 7 — Reading existing secrets (pattern)

```hcl
data "azurerm_key_vault_secret" "api_key" {
  name         = "third-party-api-key"
  key_vault_id = data.azurerm_key_vault.shared.id
}
# use: data.azurerm_key_vault_secret.api_key.value  (the value is also stored in state!)
```

Better for apps: pass only the **reference** `@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.x.versionless_id})` in App Service settings, so the app resolves it at runtime with its identity.

---

## 3. Lab 10.2 — Azure Policy as code (40 min)

**Reference solution:** [labs/lab10-policy](labs/lab10-policy/)

1. Write a **custom definition** "Require `cost_center` tag" with an `effect` parameter (`Audit`/`Deny`/`Disabled`), using `jsonencode()` for `policy_rule`, `parameters`, and `metadata`.
2. **Assign** it to your lab resource group with `effect = Deny` and a friendly `non_compliance_message`.
3. Look up the **built-in** "Allowed locations" definition with `data "azurerm_policy_definition"` and assign it with `["centralindia","southindia"]`.
4. Apply. Then test the guardrail:

```bash
terraform apply -var="student=dg" -var="include_cost_center=false"
# Error: RequestDisallowedByPolicy ... All resources must have a cost_center tag
```

5. Try a VNet in `eastus` with the Azure CLI. It is denied by the location policy.
6. (Extra) Group both into an **initiative** with `azurerm_policy_set_definition`, and assign the initiative instead.

> Policy assignments can take up to about 15 minutes to take effect. If the Deny doesn't trigger straight away, wait and retry.

---

## 4. Lab 10.3 — Shift-left security scanning (40 min)

**Starting point:** [labs/lab10-insecure-scan](labs/lab10-insecure-scan/) (intentionally insecure) · **Fixed version:** [labs/lab10-insecure-scan-fixed](labs/lab10-insecure-scan-fixed/)

```bash
cd labs/lab10-insecure-scan
checkov -d . --compact
trivy config .
cat > .tflint.hcl <<'EOF'
plugin "azurerm" {
  enabled = true
  version = "0.33.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}
EOF
tflint --init && tflint
```

Tasks:

1. List every finding in a table: **tool · check ID · resource · fix**.
2. Fix them all **without** reading the fixed version first: TLS 1.2, HTTPS only, no public blobs, restricted SSH, RDP removed, tenant from a data source, purge protection, network ACLs, password supplied through `TF_VAR_` and marked sensitive.
3. Rescan until it's clean, or justify suppressions inline:

```hcl
resource "azurerm_storage_account" "logs" {
  #checkov:skip=CKV2_AZURE_1:Customer-managed keys not required for training logs
  # ...
}
```

4. Add a pre-commit hook (`.pre-commit-config.yaml`) using [pre-commit-terraform](https://github.com/antonbabenko/pre-commit-terraform) with `terraform_fmt`, `terraform_validate`, `terraform_tflint`, and `terraform_checkov`.

---

## 4b. Lab 10.4 — Secrets from HashiCorp Vault (30 min)

**Exam objective 4h** · **Reference solution:** [labs/lab10-vault](labs/lab10-vault/)

In many enterprises **Vault** is the central secrets platform. Terraform *consumes* secrets from it; humans and apps never see them.

### Step 1 — Start a local Vault dev server (in-memory, for learning only)

```bash
# Option A: binary (winget install Hashicorp.Vault / brew install hashicorp/tap/vault)
vault server -dev -dev-root-token-id=root
# Option B: Docker
docker run --rm -p 8200:8200 -e VAULT_DEV_ROOT_TOKEN_ID=root hashicorp/vault

# In a second terminal
export VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root      # PowerShell: $env:VAULT_ADDR=...; $env:VAULT_TOKEN="root"
vault kv put secret/payments/db username=pay_admin password='S3cr3t-From-Vault!'
```

### Step 2 — Part 1: the classic way (data source)

```hcl
provider "vault" {}            # reads VAULT_ADDR and VAULT_TOKEN. Never hard-code tokens

data "vault_kv_secret_v2" "db_classic" {
  mount = "secret"
  name  = "payments/db"
}
```

`terraform validate` prints a **deprecation warning**: *"Please use new Ephemeral KVV2 Secret resource"*. Apply, then:

```bash
terraform state pull | grep -c "S3cr3t-From-Vault"     # ≥ 1: the password is now in state
```

### Step 3 — Part 2: the modern way (ephemeral + write-only)

```hcl
ephemeral "vault_kv_secret_v2" "db" {
  mount = "secret"
  name  = "payments/db"
}

resource "azurerm_key_vault_secret" "db_password" {
  name             = "payments-db-password"
  key_vault_id     = data.azurerm_key_vault.lab.id
  value_wo         = ephemeral.vault_kv_secret_v2.db.data["password"]
  value_wo_version = var.secret_version
}
```

Comment out Part 1, apply with `-var="key_vault_name=<kv from Lab 10.1>" -var="key_vault_resource_group=rg-dg-lab10"`, and check again: **0 matches** in state. The value is in Azure Key Vault, and Vault remains the source of truth.

### Step 4 — Rotate

```bash
vault kv put secret/payments/db username=pay_admin password='R0tated-2026!'
terraform apply ... -var="secret_version=2"
```

### Production patterns with Vault (discussion)

| Pattern | How |
|---|---|
| **Dynamic Azure credentials for Terraform itself** | Vault Azure secrets engine creates a short-lived service principal per run (`data "vault_azure_access_credentials"`). No long-lived secret in CI |
| **Dynamic database credentials** | Vault database engine issues per-app, auto-expiring DB users |
| **Vault + HCP Terraform** | Vault-backed dynamic provider credentials, configured with workspace variables (Module 15) |
| **Authenticating Terraform to Vault** | JWT/OIDC auth from CI, AppRole for legacy runners. Never the root token |

---

## 5. Clean up

```bash
terraform destroy -var="student=dg"      # lab10-keyvault-rbac and lab10-policy
```

---


## 🏭 In production

* **Secrets hierarchy (best first):** no secret at all (managed identity / Entra auth), then a short-lived dynamic secret (Vault, OIDC), then ephemeral + write-only, then a protected-state secret, and **never** a secret in Git.
* **Every security scanner finding gets an owner:** fix it, or suppress it inline with a justification and a ticket number. Reviewers check suppressions in every PR.
* **Policy rollout:** start every new Azure Policy in `Audit` for 2–4 weeks, review the compliance report, then switch to `Deny`. Switching straight to `Deny` breaks other teams' pipelines.
* **Break-glass:** keep a documented, monitored emergency account for when automation or RBAC fails. Test it quarterly.

## 🎓 Exam corner (objectives 4h, 4g)

1. **True or false:** Usernames and passwords referenced in configuration, even as variables, end up in plain text in the state file. → **True** (unless ephemeral or write-only).
2. **True or false:** `sensitive = true` encrypts the value in state. → **False.**
3. Which Terraform feature lets a resource accept a value that is never stored in state? → Write-only arguments (`*_wo`), fed by ephemeral values.
4. Where should a Vault token for Terraform come from? → An environment variable (`VAULT_TOKEN`) or an auth method, never the configuration.
5. **Choose two** ways to protect secrets in state: encrypt the backend storage at rest / restrict access to the state backend / commit state to Git / print it with `terraform output` → **encryption at rest, restricted access.**

## 6. Knowledge check

1. Does `sensitive = true` keep a secret out of state?
2. Why assign Key Vault roles to a group or managed identity rather than a user?
3. Why do new role assignments sometimes fail on first apply, and how do you fix it?
4. What's the difference between Azure Policy `Audit` and `Deny`?
5. Checkov flags a finding that is acceptable for your use case. What do you do?

<details><summary>Answers</summary>

1. No. It only redacts output. Use ephemeral or write-only values, or avoid Terraform-managed secrets.
2. Membership changes need no Terraform change, access survives people leaving, and it works with PIM and access reviews.
3. Entra ID and RBAC are eventually consistent. Add `time_sleep` with `depends_on`, or retry.
4. `Audit` records non-compliance but allows the deployment. `Deny` blocks the ARM request.
5. Suppress it inline with a documented justification (`#checkov:skip=ID:reason`), and review suppressions in PRs.
</details>
