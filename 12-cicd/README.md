# Module 12 — CI/CD Pipelines for Terraform

**Duration:** 1.5 hours (30 min theory · 1h labs; Lab 12.3 as demo) · **Level:** Advanced
**Exam objectives:** 3d, 3e, 8d

> 📋 **Ticket PLAT-112** — Engineers still apply from laptops using a shared client secret. Move every deployment to pipelines with secretless authentication, PR plans and production approvals.

## Learning objectives

- Design a Terraform pipeline: validate, plan, review, approve, apply the *same* plan
- Authenticate pipelines to Azure with **OIDC workload identity federation** (no secrets)
- Bootstrap the pipeline identity with Terraform (Entra ID app, federated credentials, RBAC)
- Build a GitHub Actions workflow with PR plan comments and environment approvals
- Build an Azure DevOps multi-stage YAML pipeline with templates and environments
- Add nightly drift detection

---

## 1. Concepts

### 1.1 The golden pipeline

```text
 ┌────────────── Pull request ──────────────┐   ┌──────────────── Merge to main ─────────────────────┐
 │ fmt → validate → tflint → checkov → test │   │ plan dev → apply dev (saved plan) → smoke test      │
 │ → plan dev (posted as PR comment)        │   │ → ⏸ manual approval → plan prod → apply prod        │
 └──────────────────────────────────────────┘   └─────────────────────────────────────────────────────┘
```

Rules:

1. **Nobody applies from a laptop** to shared environments. Laptops are for dev sandboxes only.
2. `plan -out` → review → `apply <planfile>`. Never apply an unreviewed fresh plan.
3. Pin the Terraform version (`TF_VERSION`) and commit `.terraform.lock.hcl`.
4. One concurrency group per state, and never cancel a running apply.
5. Treat plan files as secrets (short artifact retention).
6. Use a separate identity per environment, with prod RBAC only on the prod identity.

### 1.2 OIDC workload identity federation: how it works

```text
GitHub Actions job ──(1) requests OIDC token (sub = repo:org/repo:environment:prod)──▶ GitHub OIDC issuer
        │
        └──(2) presents token──▶ Entra ID: "Does app X have a federated credential matching this issuer + subject?"
                                     │ yes
        ◀──(3) Azure access token────┘        (valid ~1h, nothing stored anywhere)
        │
        └──(4) Terraform azurerm provider (ARM_USE_OIDC=true) calls ARM
```

| Federated credential subject | When it matches |
|---|---|
| `repo:org/repo:pull_request` | Any PR workflow run |
| `repo:org/repo:ref:refs/heads/main` | Jobs on the main branch **without** an environment |
| `repo:org/repo:environment:prod` | Jobs with `environment: prod` (combine with required reviewers) |
| Azure DevOps: `sc://org/project/service-connection` | That service connection |

### 1.3 Variables the azurerm provider reads in CI

| Variable | Value |
|---|---|
| `ARM_CLIENT_ID` | App registration (client) ID |
| `ARM_TENANT_ID` | Tenant ID |
| `ARM_SUBSCRIPTION_ID` | Target subscription |
| `ARM_USE_OIDC` | `true` |
| `ARM_OIDC_TOKEN` | (Azure DevOps) the token from `AzureCLI@2` `addSpnToEnvironment` |
| `TF_IN_AUTOMATION`, `TF_INPUT=false` | Cleaner output, never prompt |

The backend uses the same credentials (`use_azuread_auth = true` in `backend.hcl`).

---

## 2. Lab 12.1 — Bootstrap the pipeline identity with Terraform (30 min)

**Reference solution:** [labs/oidc-bootstrap](labs/oidc-bootstrap/)

This is a "Terraform creates the identity that runs Terraform" stack. It creates:

* `azuread_application` + `azuread_service_principal`
* Federated credentials for PRs, `main`, and each GitHub environment (`dev`, `prod`, `prod-readonly`), plus optionally Azure DevOps
* `Contributor` on the subscription and `Storage Blob Data Contributor` on the state storage account

```bash
cd labs/oidc-bootstrap
cat > bootstrap.tfvars <<'EOF'
student                  = "dg"
github_repo              = "<your-github-user>/tf-azure-cicd-demo"
state_storage_account_id = "/subscriptions/<sub>/resourceGroups/rg-dg-tfstate/providers/Microsoft.Storage/storageAccounts/stdgtfstateXXXXX"
EOF
terraform init && terraform apply -var-file=bootstrap.tfvars
terraform output github_secrets
```

> **Production hardening:** use one app per environment, scope prod's role to the prod subscription only, and give the drift-detection identity (`prod-readonly`) the **Reader** role plus state read access.

---

## 3. Lab 12.2 — GitHub Actions (60 min)

**Reference solution:** [labs/github-actions/.github/workflows](labs/github-actions/.github/workflows/)

### Step 1 — Create the demo repository

```bash
gh repo create tf-azure-cicd-demo --private --clone && cd tf-azure-cicd-demo
mkdir infra
cp -r <course>/09-environments/labs/lab09-multi-env/* infra/
cp -r <course>/07-modules/labs/lab07-modules/modules infra/modules   # fix the module source path in infra/main.tf
cp -r <course>/12-cicd/labs/github-actions/.github .
```

* Update `infra/main.tf` → `source = "./modules/vnet"`
* Rename `env/*/terraform.tfvars.example` to `terraform.tfvars`. They contain no secrets here, so remove `*.tfvars` from `.gitignore` for this repo, or pass values through `TF_VAR_*`.
* Fill in `env/*/backend.hcl` with your state account.
* Add a `tests/unit.tftest.hcl` (from Module 11) or remove that step.

### Step 2 — Configure GitHub

```bash
gh variable set AZURE_CLIENT_ID       --body "<from terraform output>"
gh variable set AZURE_TENANT_ID       --body "<...>"
gh variable set AZURE_SUBSCRIPTION_ID --body "<...>"
```

In the GitHub UI, go to **Settings → Environments** and create `dev`, `prod` (add yourself as a *Required reviewer*), and `prod-readonly`.

### Step 3 — Walk through the workflow

| Job | Highlights |
|---|---|
| `validate` | fmt, validate (no backend), tflint, checkov, mocked tests. No Azure credentials needed |
| `plan-dev` | `-detailed-exitcode` (0 = no changes, 2 = changes) → output; on a PR the plan goes into a PR comment; on main the plan is uploaded as an artifact |
| `apply-dev` | `environment: dev`, downloads **the same plan file**, `terraform apply dev.tfplan`. Skipped when there are no changes |
| `deploy-prod` | `environment: prod` pauses for approval; runs even if dev had no changes, but never after a failure |

### Step 4 — Exercise the flow

1. Create a branch, add a subnet in `env/dev/terraform.tfvars`, and open a PR. Read the plan comment.
2. Merge. Watch `apply-dev`, then approve `prod` in the Actions UI.
3. Break formatting in a PR. The `validate` job fails before any Azure call is made.
4. Add an NSG rule allowing `*` on port 22. Checkov fails the PR.

### Step 5 — Drift detection

[drift-detection.yml](labs/github-actions/.github/workflows/drift-detection.yml) runs nightly, plans prod with `-lock=false` (read-only), and opens a GitHub issue when the exit code is 2. Trigger it manually after changing a tag in the Portal.

---

## 4. Lab 12.3 — Azure DevOps (40 min)

**Reference solution:** [labs/azure-devops](labs/azure-devops/)

### Step 1 — Service connections (workload identity federation)

**Project settings → Service connections → New → Azure Resource Manager → Workload identity federation (automatic)**. Create `sc-terraform-dev` and `sc-terraform-prod`.

*Manual alternative:* choose "manual", copy the **Issuer** and **Subject identifier**, and feed them to the bootstrap stack's `azure_devops` variable to reuse the Terraform-created app.

### Step 2 — Environments

**Pipelines → Environments**: create `dev` and `prod`. On `prod`, add **Approvals and checks → Approvals**.

### Step 3 — Pipeline structure

```text
azure-pipelines.yml
├── stage Validate               fmt, validate, checkov (JUnit results published to the run)
├── template terraform-stage.yml (dev)   plan job → deployment job "apply" (runs on main only)
└── template terraform-stage.yml (prod)  only for non-PR builds; approval gate on environment "prod"
```

The key OIDC trick in `AzureCLI@2`:

```yaml
addSpnToEnvironment: true
inlineScript: |
  export ARM_CLIENT_ID=$servicePrincipalId
  export ARM_TENANT_ID=$tenantId
  export ARM_OIDC_TOKEN=$idToken
  export ARM_USE_OIDC=true
```

### Step 4 — Run it

Push the repository to Azure Repos (or connect the GitHub repository), create a pipeline from `azure-pipelines.yml`, and run it. Approve prod.

---

## 5. Discussion: HCP Terraform, Spacelift, env0, and Atlantis

| Feature | DIY pipelines (this lab) | HCP Terraform / TACOs |
|---|---|---|
| Cost | Runner minutes | Per resource or per user |
| State | Your Azure storage | Managed (or yours) |
| Policy as code | Checkov / OPA in the pipeline | Sentinel / OPA built in |
| Drift detection | Scheduled workflow | Built in |
| Private module registry | Git tags | Built in |
| PR automation | Custom scripts | Built in (Atlantis-style) |

---


## 🏭 In production

* **Pipelines are the only way to prod.** Humans approve, and pipelines apply.
* **Reusable workflow templates** (a GitHub reusable workflow or Azure DevOps template) are owned by the platform team, so 40 app repos get fixes in one place.
* **Separate identities per environment,** federated (OIDC), with the narrowest roles. The prod identity is usable only from the protected `prod` environment.
* **Plans are posted on PRs for every environment,** so reviewers see the prod impact before merging.


## 🎓 Exam corner

1. Which plan flag returns exit code 2 when changes are present? → `-detailed-exitcode`.
2. **True or false:** `terraform apply tfplan` applies without asking for confirmation. → **True.**
3. Which option disables interactive prompts for missing variables in automation? → `-input=false` (or `TF_INPUT=false`).

## 6. Knowledge check

1. Why apply a saved plan file instead of running `terraform apply` again in the apply job?
2. What is the OIDC `subject` for a GitHub job with `environment: prod`?
3. Why must `cancel-in-progress` be false for Terraform jobs?
4. What does `-detailed-exitcode` return, and how is it used?
5. How do you keep a dev pipeline from touching prod?

<details><summary>Answers</summary>

1. It guarantees that exactly the reviewed changes are applied. A fresh plan may differ if the code or the infrastructure changed in the meantime.
2. `repo:<owner>/<repo>:environment:prod`.
3. Cancelling an apply mid-way can leave resources half-created and the state lock held.
4. 0 = no changes, 1 = error, 2 = changes present. It is used to skip the apply or to flag drift.
5. Use separate identities and federated credentials per environment, RBAC scoped per environment, separate state, and environment approvals.
</details>
