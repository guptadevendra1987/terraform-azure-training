# Terraform on Microsoft Azure — Beginner to Expert (40 Hours)

Hands-on Terraform training on Microsoft Azure: labs, modules, and real-world examples.

> **Philosophy:** about 70% of this course is labs. Every concept is introduced with a short explanation, then you build it on real Azure resources, break it, fix it, and extend it.

---

## The story: you work at Contoso Retail India

You have just joined the **Platform Engineering team at Contoso Retail India**: 40 app teams, dev and prod, about 2,000 Azure resources, and quarterly audits. Every module starts with a **📋 ticket** from that company, and the [Production Playbook](docs/production-playbook.md) is the team's rulebook: naming, tagging, PR reviews, change management, rollback, and day-2 operations. Practise incident response with the [Game Days](docs/game-days.md).

## Who this course is for

| Audience | What you get |
|---|---|
| Cloud / DevOps engineers new to IaC | A solid foundation: HCL, the core workflow, state, and Azure resources |
| Engineers already using the Azure Portal or ARM/Bicep | How to move to Terraform, import existing resources, and refactor safely |
| Platform / SRE engineers | Modules, remote state, multiple environments, testing, policy, CI/CD with OIDC, HCP Terraform, and landing-zone patterns |
| **Certification candidates** | Full coverage of the **HashiCorp Terraform Associate (004)** objectives, with practice exams. See the [Certification Track](certification/README.md) |

**Prerequisites:** basic Azure knowledge (subscriptions, resource groups, VNets, VMs), comfort with a terminal, and basic Git.

---

## Course agenda (5 days × 8 hours = 40 hours)

| Day | Module | Hours | Main labs | Exam objectives |
|---|---|---|---|---|
| **Day 1 — Foundations** | [00 Lab Setup](00-lab-setup/README.md) | (pre-work) | Install tools and log in to Azure | |
| | [01 IaC & Terraform Fundamentals](01-iac-fundamentals/README.md) | 2 | First run with no cloud account, core workflow | 1, 2b, 2d, 3 |
| | [02 Your First Azure Deployment](02-azure-first-deployment/README.md) ([visual guide](02-azure-first-deployment/visual-guide.html)) | 3 | How Terraform logs in, **least-privilege service principal**, storage built step by step, multiple providers | 2a–2c, 3 |
| | [03 Variables, Locals & Outputs](03-variables-outputs/README.md) | 3 | Typed variables, validation, tfvars, sensitive data | 4c, 4d, 4g |
| **Day 2 — Building Real Infra** | [04 Resources, Dependencies & Data Sources](04-resources-dependencies/README.md) | 3 | VNet, subnets, NSG, lifecycle rules | 4a, 4b, 4f |
| | [05 Loops, Expressions & Functions (made simple)](05-expressions-meta-arguments/README.md) | 4 | **8-step loops ladder**, **real-world functions lab**, data-driven network | 4d, 4e |
| | Day 2 Challenge Lab | 1 | Network built from a YAML file | 4e |
| **Day 3 — State & Reuse** | [06 State Management](06-state-management/README.md) | 4 | Remote backend, locking, import, moved/removed, recovery | 2d, 6, 7a, 7b |
| | [07 Modules](07-modules/README.md) | 4 | Write, version, and use modules; Azure Verified Modules | 5 |
| **Day 4 — Workloads & Security** | [08 Compute & PaaS Workloads](08-compute-paas/README.md) | 2.5 | Linux VM + cloud-init, App Service with managed identity | 4b, 4f |
| | [09 Multiple Environments](09-environments/README.md) | 1.5 | Workspaces compared with separate directories, per-env backends | 6a, 6c |
| | [10 Security, Secrets & Governance](10-security-governance/README.md) | 2.5 | Key Vault, RBAC, Azure Policy, scanners, **HashiCorp Vault** | 4g, 4h |
| | [11 Testing & Code Quality](11-testing-quality/README.md) | 1.5 | `terraform test`, mocks, checks, TFLint | 4g, 3c |
| **Day 5 — Expert Practice** | [12 CI/CD Pipelines](12-cicd/README.md) | 1.5 | GitHub Actions + Azure DevOps with OIDC | 3d, 3e |
| | [15 HCP Terraform](15-hcp-terraform/README.md) | 2 | `cloud` block, state migration, projects and workspaces as code, dynamic credentials, policy | **8** |
| | [13 Advanced Topics](13-advanced/README.md) | 1.5 | AzAPI, ephemeral values, bulk import, **provider major upgrade 4 → 5**, logging | 2a, 7a, 7c |
| | [14 Capstone Project](14-capstone/README.md) | 2.5 | Hub-and-spoke landing zone, presented as a change request | All |
| | Exam readiness | 0.5 | [Practice exam 1](certification/practice-exam-1.md) (the rest is homework) | All |

A detailed hour-by-hour plan is in [docs/trainer-guide.md](docs/trainer-guide.md).

---

## Repository layout

```
terraform-azure-training/
├── README.md                     ← you are here
├── docs/
│   ├── trainer-guide.md          ← hour-by-hour delivery plan and teaching tips
│   ├── production-playbook.md    ← Contoso's standards: naming, tagging, PRs, change and rollback
│   ├── game-days.md              ← 8 production incident simulations
│   ├── cheatsheet.md             ← CLI + HCL quick reference
│   ├── troubleshooting.md        ← common errors and fixes
│   └── assessment.md             ← final exam + interview questions with answers
├── certification/                ← Terraform Associate (004): objective map, cram notes, 2 practice exams
├── 00-lab-setup/                 ← tool install, Azure login, helper scripts
├── 01-iac-fundamentals/ … 13-advanced/, 15-hcp-terraform/
│   ├── README.md                 ← 📋 ticket, concepts, labs, 🏭 in production, 🎓 exam corner, quiz
│   └── labs/<lab-name>/          ← runnable reference solution
└── 14-capstone/                  ← project brief, rubric, reference solution
```

## How to do a lab

1. Read the module `README.md` and **type** the code yourself in a new folder (`~/tf-labs/labXX`). Typing builds muscle memory.
2. Get stuck? Compare your code with the reference solution in `labs/<lab-name>/`.
3. Every lab ends with a **Cleanup** step. Always run `terraform destroy` so you don't pay for idle resources.

> **Variable files:** `*.tfvars` is git-ignored because tfvars files often contain secrets, so the labs ship `*.tfvars.example` files. Copy one to `terraform.tfvars` (or the path the lab names) and set your own values.

## Course conventions

| Convention | Value |
|---|---|
| Terraform | **1.12 or newer** (the version the Associate 004 exam tests). Labs need `>= 1.9`; Modules 10.4 and 13 need `>= 1.11`; the AVM lab (7.3) needs `>= 1.12` |
| AzureRM provider | `~> 4.0`, pinned on purpose. azurerm 5.x exists, and upgrading is a production drill in [Lab 13.3](13-advanced/README.md) |
| Default region | `centralindia` (change `location` to whatever region you prefer) |
| Naming | `<prefix>-<student>-<workload>-<env>`, for example `rg-dg-web-dev` |
| Mandatory tags | `course = "tf-azure-training"`, `owner = <student>` (the cleanup script uses these) |
| Student isolation | Every lab takes a `student` variable (your initials) so many students can share one subscription |

## Cost guardrails

* Use the smallest SKUs: `Standard_B1s`/`Standard_B2s` VMs, `B1` App Service, and `Standard_LRS` storage.
* Create a **budget alert** during setup (see [00-lab-setup](00-lab-setup/README.md#6-create-a-cost-budget-alert)).
* At the end of each day, run [00-lab-setup/scripts/cleanup.ps1](00-lab-setup/scripts/cleanup.ps1) (or `cleanup.sh`).
* If you destroy everything each day, the whole course costs well under USD 10 per student.
