# Module 14 — Capstone Project: Hub-and-Spoke Landing Zone

**Duration:** 2.5 hours (2h build · 30 min CAB-style review) · **Level:** Expert · **Format:** individually or in pairs
**Exam objectives:** All

> 📋 **Ticket PLAT-200** — Build the company's new hub-and-spoke landing zone for the payments platform: production-grade, tested, documented and ready for the CAB review.

You are the platform engineer at *Contoso Retail India*. Build a production-style hub-and-spoke network with a secure web workload, using **everything** from the course: modules, remote state, multiple environments, security, testing, and CI/CD.

**Reference solution:** [solution/](solution/). Try not to open it until you've finished, or until the trainer allows it.

---

## 1. Target architecture

```text
                              ┌─────────────────── rg-<s>-<env>-hub ───────────────────┐
                              │ vnet-<s>-<env>-hub  10.200.0.0/16                       │
                              │  ├─ AzureFirewallSubnet   (Firewall Basic: prod only)   │
                              │  ├─ AzureBastionSubnet                                  │
                              │  └─ snet-shared                                         │
                              │ Private DNS zone: privatelink.blob.core.windows.net     │
                              │ CanNotDelete lock (prod only)                           │
                              └──────────────▲──────────────────────▲───────────────────┘
                                   peering   │                      │  peering
              ┌──────── rg-<s>-<env>-web ────┴───────┐   ┌──── rg-<s>-<env>-data ──┴─────┐
              │ vnet-…-web  10.201.0.0/16            │   │ vnet-…-data  10.202.0.0/16    │
              │  ├─ snet-app (delegated: Web)  ◀── App Service (VNet-integrated, MSI)    │
              │  └─ snet-pe  ◀── Private Endpoint ──▶ Storage (no public access, no keys)│
              │  NSG per subnet, UDR 0.0.0.0/0 → Firewall (when enabled)                 │
              └──────────────────────────────────────┘   └───────────────────────────────┘
                     rg-<s>-<env>-shared: Log Analytics ◀── diagnostic settings
```

---

## 2. Requirements

### Functional (must have)

| # | Requirement |
|---|---|
| F1 | A hub VNet with `AzureFirewallSubnet`, `AzureBastionSubnet`, and a shared subnet, carved with `cidrsubnet()` |
| F2 | Any number of spokes defined **only in tfvars** (`map(object)`). Adding a spoke needs zero HCL changes |
| F3 | Bidirectional hub ↔ spoke peering |
| F4 | An NSG on every spoke subnet; rules come from data |
| F5 | Optional Azure Firewall (`enable_firewall`). When enabled, spoke subnets route `0.0.0.0/0` to it |
| F6 | A private DNS zone for blob in the hub, linked to the hub **and** every spoke |
| F7 | A Linux App Service in the `web` spoke: VNet integration, HTTPS only, TLS 1.2, system-assigned identity |
| F8 | A storage account with **no public network access and no shared keys**, reachable through a private endpoint; the app gets `Storage Blob Data Contributor` |
| F9 | Log Analytics in a shared RG; the app sends diagnostics to it |
| F10 | dev and prod deploy from the **same code** with different tfvars and separate state |

### Non-functional (must have)

| # | Requirement |
|---|---|
| N1 | At least 3 local modules: `hub-network`, `spoke-network`, `workload-web` |
| N2 | Remote state in Azure Storage with Entra ID auth; partial backend config per environment |
| N3 | Input validation: student format, environment, and that the `web` spoke and `app`/`pe` subnets exist |
| N4 | Consistent naming and mandatory tags through `locals` |
| N5 | Prod-only protections: `CanNotDelete` lock on the hub RG, 90-day log retention, ZRS storage, `P0v3` plan |
| N6 | `terraform fmt`, `validate`, `tflint`, and `checkov` pass (justified suppressions allowed) |
| N7 | At least 3 `terraform test` runs with mocked providers |

### Stretch goals

* S1: A GitHub Actions or Azure DevOps pipeline (Module 12) for dev → prod
* S2: An Azure Policy initiative (required tags + allowed locations) assigned to every spoke RG
* S3: Azure Bastion + a jump-box VM in the shared subnet
* S4: Replace your `hub-network` module with the AVM `avm-ptn-alz-*` / `avm-res-network-*` modules
* S5: Key Vault with a private endpoint, and an app setting that uses a Key Vault reference

---

## 3. Suggested plan (2 hours)

| Time | Milestone | Check |
|---|---|---|
| 0:00–0:15 | Repo skeleton, `providers.tf`, partial backend, `variables.tf` with validation | `terraform init -backend-config=...` works |
| 0:15–0:45 | `hub-network` module + RGs + Log Analytics | `plan` shows the hub |
| 0:45–1:15 | `spoke-network` module with `for_each`, peering, NSGs, DNS links | Two spokes peered, `apply` dev |
| 1:15–1:45 | `workload-web` module: storage + PE + app + RBAC + diagnostics | `curl` the app URL |
| 1:40–1:50 | Tests (mocked) + tflint + checkov | All green |
| 1:50–2:00 | Plan prod (`enable_firewall = true`) and review it; apply only if the trainer approves | Prod plan reviewed |

> **Cost warning:** Azure Firewall Basic and `P0v3` cost money by the hour. Apply prod only if instructed, and destroy it immediately after the demo.

---

## 4. How to run the reference solution

```bash
cd solution
cp env/dev.tfvars.example env/dev.tfvars                 # set student
cp env/dev.backend.hcl.example env/dev.backend.hcl       # set the state account
terraform init -backend-config=env/dev.backend.hcl
terraform test                                           # mocked: no Azure needed
terraform plan -var-file=env/dev.tfvars -out=dev.tfplan
terraform apply dev.tfplan
```

### Verification checklist

```bash
APP=$(terraform output -raw app_url); curl -I $APP
az network vnet peering list -g rg-dg-dev-web --vnet-name vnet-dg-dev-web -o table      # Connected
az network private-endpoint show -g rg-dg-dev-web -n pe-dg-dev-web-blob --query "customDnsConfigs"
az storage account show -n <st> --query "{public:publicNetworkAccess, keys:allowSharedKeyAccess}"
```

Prove that private access works: open the web app's **SSH/Kudu console** and run `nslookup <st>.blob.core.windows.net`. It should resolve to a `10.201.2.x` address.

---

## 5. Assessment rubric (100 points)

| Area | Points | Excellent (full marks) |
|---|---|---|
| Functional requirements F1–F10 | 35 | All deployed and verified in dev |
| Module design | 15 | Clean interfaces, typed and validated inputs, useful outputs, no providers in modules |
| Data-driven / DRY | 10 | Spokes and subnets entirely from tfvars, sensible `for_each`, no copy-paste |
| State and environments | 10 | Remote state, Entra auth, separate dev/prod keys, `-reconfigure` understood |
| Security | 15 | No secrets in code or state where avoidable, private endpoint, managed identity, least privilege, scanners pass |
| Testing and quality | 10 | ≥3 meaningful tests, fmt/validate/tflint clean |
| Presentation | 5 | Explains one design trade-off and one thing they would change for production |
| *Stretch goals* | +5 each | |

---


## 🏭 In production

This capstone ships with the same governance files a real platform repository has (see [solution/](solution/)):

| File | Purpose |
|---|---|
| `.github/CODEOWNERS` | Who must review which paths (network changes need the network team) |
| `.github/pull_request_template.md` | Plan summary, review checklist, risk and rollback |
| `.pre-commit-config.yaml` / `.tflint.hcl` | Local quality gates identical to CI |
| `docs/adr/0001-state-and-environment-strategy.md` | Why the repository is structured this way |
| `tests/unit.tftest.hcl` | Mocked tests for prod-only protections |

Present your capstone **as a change request** to the "CAB" (trainer + peers): show the plan, the risks, the rollback and the tests. Follow the [Production Playbook](../docs/production-playbook.md).


## 🎓 Exam corner

Re-take [practice exam 2](../certification/practice-exam-2.md): most of its scenarios appear in this capstone.

## 6. Review questions for the demo

1. Why is `firewall_enabled` passed as a separate boolean instead of checking `firewall_private_ip != null` in the spoke module?
2. What happens to the prod hub if someone runs `terraform destroy`? What protects it, and what doesn't?
3. How would you give a second team their own spoke without letting them change the hub?
4. Which values in your state file are sensitive, and how is the state protected?

<details><summary>Trainer notes</summary>

1. `count`/`for_each` must be known at plan time. The firewall IP is only known after apply, which causes *"Invalid count argument"* on the first deployment.
2. The `CanNotDelete` lock blocks Portal and CLI deletes, but Terraform destroys the lock first. Real protection comes from a pipeline policy (no prod destroy), `prevent_destroy`, and RBAC without lock-delete rights.
3. Use a separate stack and state per spoke. The spoke team reads the hub through data sources (or remote state outputs), and the hub-side peering is created by the platform pipeline or by a role scoped only to peerings.
4. Storage endpoints and IDs are not secret, but the plan or state can include app settings, connection strings, and the app's identity details. Protect state with RBAC, a private endpoint, and versioning.
</details>
