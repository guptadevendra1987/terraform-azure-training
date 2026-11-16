# Module 11 — Testing & Code Quality

**Duration:** 1.5 hours (25 min theory · 65 min labs) · **Level:** Advanced
**Exam objectives:** 4g, 3c, 3g

> 📋 **Ticket PLAT-111** — A module change broke 6 teams' deployments. From now on, every module change must be proven by automated tests before release.

## Learning objectives

- Build a testing pyramid for IaC, from formatting through integration tests
- Write native `terraform test` files (`.tftest.hcl`) with `run` blocks, assertions, and `expect_failures`
- Use **mock providers** for fast, free, credential-less unit tests
- Use `precondition`, `postcondition`, and `check` blocks for runtime contracts
- Lint with TFLint (azurerm ruleset) and automate it all with pre-commit

---

## 1. Concepts

### 1.1 The IaC testing pyramid

```text
                 ▲  slower, costlier, more confidence
                 │
      ┌──────────┴──────────┐
      │  End-to-end / smoke │  deploy, then curl the app, run InSpec or Pester
      ├─────────────────────┤
      │ Integration tests   │  terraform test with REAL providers (creates and destroys)
      ├─────────────────────┤
      │ Unit tests (mocks)  │  terraform test + mock_provider: seconds, no Azure
      ├─────────────────────┤
      │ Policy / security   │  checkov, trivy, OPA on plan JSON
      ├─────────────────────┤
      │ Static              │  fmt, validate, tflint
      └─────────────────────┘
                 │  faster, cheaper: run on every commit
```

### 1.2 Runtime contracts inside the code

| Construct | When evaluated | On failure | Use for |
|---|---|---|---|
| `variable { validation {} }` | Plan, on input values | **Error** | Input format and ranges |
| `lifecycle { precondition {} }` | Before a resource is planned | **Error** | Assumptions across inputs and data sources |
| `lifecycle { postcondition {} }` | After apply/read (`self.`) | **Error** | Guarantees about the real object |
| `check {}` block | End of every plan/apply | **Warning** only | Health checks, drift, external endpoints |

### 1.3 `terraform test` anatomy

```hcl
# tests/unit.tftest.hcl
mock_provider "azurerm" {}             # optional: replaces the real provider

variables {                            # file-level inputs
  name = "sttest001"
}

run "descriptive_name" {
  command = plan                       # or apply (the default)
  variables { replication_type = "ZRS" }       # per-run overrides

  assert {
    condition     = azurerm_storage_account.this.account_replication_type == "ZRS"
    error_message = "..."
  }
}

run "bad_input_is_rejected" {
  command         = plan
  variables       { replication_type = "SUPER" }
  expect_failures = [var.replication_type]       # this run passes only if THIS fails
}
```

* Every `run` in a file shares state, in order. Resources created by `apply` runs are **destroyed automatically** at the end of the file.
* `run.<name>.<output>` lets later runs use earlier outputs.
* `module { source = "./tests/setup" }` runs a helper module (for example, to create a resource group).
* `override_resource` / `override_data` fake individual objects inside a real provider run.

---

## 2. Lab 11.1 — Unit tests with mocks (no Azure needed)

**Reference solution:** [labs/lab11-terraform-test](labs/lab11-terraform-test/)

The lab tests the **storage-account module** from Module 07, extended with contracts.

### Step 1 — Add contracts to the module (`main.tf`)

```hcl
lifecycle {
  precondition {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.name))
    error_message = "Storage account name must be 3-24 lowercase letters/digits."
  }
  precondition {
    condition     = contains(keys(var.tags), "owner")
    error_message = "tags must include an 'owner' key."
  }
  postcondition {
    condition     = self.https_traffic_only_enabled
    error_message = "Storage account must enforce HTTPS-only traffic."
  }
}

check "blob_endpoint_is_https" {
  assert {
    condition     = startswith(azurerm_storage_account.this.primary_blob_endpoint, "https://")
    error_message = "Blob endpoint is not HTTPS."
  }
}
```

### Step 2 — Positive unit tests (`tests/unit.tftest.hcl`)

```hcl
mock_provider "azurerm" {
  mock_resource "azurerm_storage_account" {
    defaults = {
      id                    = "/subscriptions/0000.../storageAccounts/sttest001"
      primary_blob_endpoint = "https://sttest001.blob.core.windows.net/"
    }
  }
}

variables {
  name                = "sttest001"
  location            = "centralindia"
  resource_group_name = "rg-test"
  tags                = { owner = "test" }
}

run "secure_defaults" {
  command = apply                       # mocked apply: free, and computed values become known
  assert {
    condition     = azurerm_storage_account.this.min_tls_version == "TLS1_2"
    error_message = "TLS must be 1.2."
  }
}

run "firewall_denies_when_allow_list_given" {
  command = apply
  variables { allowed_ip_ranges = ["203.0.113.0/24"] }
  assert {
    condition     = azurerm_storage_account.this.network_rules[0].default_action == "Deny"
    error_message = "Firewall must default to Deny when IP ranges are supplied."
  }
}
```

> **Two mock-provider gotchas (both found while building this lab):**
> 1. A mock provider does **not** apply the real provider's defaults. Any attribute you rely on (like `https_traffic_only_enabled`) must be set explicitly, which is better practice anyway.
> 2. With `command = plan`, computed values (IDs, endpoints) are unknown, and a `check` block that can't be evaluated **fails** the run. With mocks, prefer `command = apply`.

### Step 3 — Negative tests (`tests/validation.tftest.hcl`)

```hcl
mock_provider "azurerm" {}

run "rejects_invalid_replication_type" {
  command         = plan
  variables       { replication_type = "SUPER" }
  expect_failures = [var.replication_type]
}

run "rejects_uppercase_name" {
  command         = plan
  variables       { name = "StTest001" }
  expect_failures = [azurerm_storage_account.this]      # precondition failure
}
```

### Step 4 — Run

```bash
terraform init
terraform test -filter=tests/unit.tftest.hcl -filter=tests/validation.tftest.hcl
# Windows PowerShell: use backslashes -> -filter=tests\unit.tftest.hcl
```

Expected:

```text
tests/unit.tftest.hcl... pass
  run "secure_defaults"... pass
  run "firewall_denies_when_allow_list_given"... pass
  run "creates_one_container_per_name"... pass
tests/validation.tftest.hcl... pass
  ...
Success! 6 passed, 0 failed.
```

### Step 5 — TDD exercise

Write a failing test **first**, then implement it:

1. "When `replication_type` is `GRS`, `soft_delete_days` must be at least 14." Add a test with `expect_failures`, then add the validation (a cross-variable validation, Terraform ≥ 1.9).
2. "Containers named `$logs` are rejected." Test first, then validate.

---

## 3. Lab 11.2 — Integration test against real Azure (20 min)

```bash
terraform test -filter=tests/integration.tftest.hcl -var="student=dg"
```

What happens:

1. `run "setup"` applies `tests/setup` (resource group + suffix)
2. `run "deploy_storage"` applies the module with `run.setup.*` outputs and asserts on **real** attributes
3. Terraform destroys everything in reverse order

Watch the Portal during the test. Discuss: run integration tests nightly or on module release tags, not on every commit.

---

## 4. Lab 11.3 — TFLint and pre-commit (15 min)

`.tflint.hcl` (included in the lab folder):

```hcl
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
plugin "azurerm" {
  enabled = true
  version = "0.33.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}
```

```bash
tflint --init
tflint --recursive
```

Introduce mistakes and watch TFLint catch what `validate` cannot: `size = "Standard_B2ss"` (invalid VM size), an unused variable, or a variable without a description.

`.pre-commit-config.yaml` for the repository root:

```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.96.1
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
      - id: terraform_docs
      - id: terraform_checkov
        args: [--args=--quiet]
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks
```

```bash
pip install pre-commit && pre-commit install
pre-commit run --all-files
```

---


## 🏭 In production

* **Every module repository runs:** fmt, validate, tflint, checkov and mocked `terraform test` on each PR (in seconds, with no cloud cost), plus integration tests nightly or on release tags.
* **Test the contract, not the provider:** assert your module's decisions (naming, defaults, conditionals, validations), not that Azure works.
* **Bugs become tests:** every production incident caused by a module gets a regression test.
* **Pre-commit hooks** catch 80% of review comments before a PR even exists.


## 🎓 Exam corner

1. **True or false:** A failing `check` block blocks the apply. → **False** (warning).
2. Which block makes a test run pass only when a validation fails? → `expect_failures`.
3. **Choose two** that run without cloud credentials: `terraform validate` / `terraform fmt` / `terraform apply` / `terraform plan` (with the real provider) → **validate, fmt.**

## 5. Knowledge check

1. What's the difference between a postcondition and a check block?
2. Why are mock providers valuable, and what can't they catch?
3. What does `expect_failures` do?
4. A unit test with `command = plan` fails because a check block "could not be evaluated". Why?
5. Which tests would you run on every PR, and which nightly?

<details><summary>Answers</summary>

1. A failed postcondition is an error that stops the apply. A failed check block is only a warning, evaluated on every plan and apply.
2. They are fast, free, and need no credentials. They can't catch real API errors, quota limits, invalid SKU or region combinations, or RBAC issues.
3. It makes the run pass only if the listed object (variable, resource, check, output) fails its validation or condition.
4. With mocks during a plan, computed attributes are unknown, so the condition can't be resolved. Use `command = apply` with mocks, or `override_resource` with values.
5. On every PR: fmt, validate, tflint, checkov, and mocked unit tests. Nightly or on release: integration and end-to-end tests.
</details>
