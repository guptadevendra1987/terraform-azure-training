# HashiCorp Terraform Associate (004) — Certification Track

This course is aligned to the **HashiCorp Certified: Terraform Associate (004)** exam. Every objective is covered by at least one module and lab, and each module ends with an **🎓 Exam corner**.

Source: [HashiCorp Associate (004) learning path](https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-study-004) and [exam content list](https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-review-004).

## Exam facts

| Item | Detail |
|---|---|
| Exam | HashiCorp Certified: Terraform Associate (004) |
| Product version tested | **Terraform 1.12** |
| Duration | 1 hour |
| Format | Online proctored. Question types: **true/false**, **multiple choice** (one answer), **multiple answer** (the question says how many to pick) |
| Registration | [HashiCorp certifications portal](https://developer.hashicorp.com/certifications/infrastructure-automation). Check there for current price, language, and validity |
| Note | The exam is **cloud-agnostic**: questions use generic or AWS-style examples. Azure is how *we* practise, and the concepts transfer 1:1 |

> Students should install **Terraform 1.12 or newer** for exam practice (`winget upgrade Hashicorp.Terraform`, `brew upgrade terraform`).

---

## Objective → course map

| # | Objective | Where it's taught | Hands-on |
|---|---|---|---|
| **1** | **Infrastructure as Code (IaC) with Terraform** | | |
| 1a | Explain what IaC is | [M01 §1.1–1.2](../01-iac-fundamentals/README.md) | Lab 1.1 |
| 1b | Describe the advantages of IaC patterns | [M01 §1.1](../01-iac-fundamentals/README.md) | Drift experiment, Lab 1.1 step 5 |
| 1c | Explain how Terraform manages multi-cloud, hybrid cloud, and service-agnostic workflows | [M01 §1.3–1.4](../01-iac-fundamentals/README.md), [M02 Lab 2.3](../02-azure-first-deployment/README.md) | azurerm + azuread + random in one config |
| **2** | **Terraform fundamentals** | | |
| 2a | Install and version Terraform providers | [M01 §1.7, version constraints](../01-iac-fundamentals/README.md), [M13 Lab 13.3](../13-advanced/README.md) | Provider upgrade 4 → 5 |
| 2b | Describe how Terraform uses providers | [M01 §1.4](../01-iac-fundamentals/README.md), [M02 §1.1](../02-azure-first-deployment/README.md) | `terraform providers` |
| 2c | Write Terraform configuration using multiple providers | [M02 Lab 2.3](../02-azure-first-deployment/README.md), [M07 §1.5](../07-modules/README.md) | Provider aliases (DR region) |
| 2d | Explain how Terraform uses and manages state | [M06 §1.1–1.2](../06-state-management/README.md) | Lab 1.1 step 4, Lab 6.1 |
| **3** | **Core Terraform workflow** | | |
| 3a | Describe the Terraform workflow | [M01 §1.5](../01-iac-fundamentals/README.md) | Lab 1.1 |
| 3b | Initialize a Terraform working directory | M01, [M06 Lab 6.1](../06-state-management/README.md) | `init`, `-upgrade`, `-backend-config`, `-migrate-state`, `-reconfigure` |
| 3c | Validate a Terraform configuration | M01 Lab 1.2 | Break-it drills |
| 3d | Generate and review an execution plan | [M02 Lab 2.1](../02-azure-first-deployment/README.md) | `plan -out`, plan symbols, `-refresh-only` |
| 3e | Apply changes to infrastructure | M02 | `apply tfplan`, `-replace` |
| 3f | Destroy Terraform-managed infrastructure | Every lab's cleanup step | `destroy`, `plan -destroy` |
| 3g | Apply formatting and style adjustments | M01 Lab 1.2 drill 6, [M11](../11-testing-quality/README.md) | `fmt -check -recursive` |
| **4** | **Terraform configuration** | | |
| 4a | Use and differentiate `resource` and `data` blocks | [M04 §1.2, Lab 4.3](../04-resources-dependencies/README.md) | Data sources reading a shared VNet |
| 4b | Refer to resource attributes and create cross-resource references | [M02 §1.4](../02-azure-first-deployment/README.md), M04 | Implicit dependencies |
| 4c | Use variables and outputs | [M03](../03-variables-outputs/README.md) | Precedence experiments |
| 4d | Understand and use complex types | [M03 §1.3](../03-variables-outputs/README.md), [M05 Part A](../05-expressions-meta-arguments/README.md) | `map(object)`, `optional()` |
| 4e | Write dynamic configuration using expressions and functions | [M05](../05-expressions-meta-arguments/README.md) | Loops ladder, real-world functions lab |
| 4f | Define resource dependencies in configuration | [M04 §1.1](../04-resources-dependencies/README.md), [M10](../10-security-governance/README.md) | `depends_on` with RBAC propagation |
| 4g | Validate configuration using custom conditions | [M03](../03-variables-outputs/README.md), [M11](../11-testing-quality/README.md) | validation, pre/postconditions, `check` blocks |
| 4h | Sensitive data and secrets management with Vault | [M03 §1.7](../03-variables-outputs/README.md), [M10 Lab 10.4](../10-security-governance/README.md), [M13 §2](../13-advanced/README.md) | Vault + ephemeral + write-only |
| **5** | **Terraform modules** | | |
| 5a | Explain how Terraform sources modules | [M07 §1.4](../07-modules/README.md) | Local, Git, public registry (AVM) |
| 5b | Describe variable scope within modules | [M07 §1.1](../07-modules/README.md), [cram notes](cram-notes.md#5-modules) | Inputs/outputs only |
| 5c | Use modules in configuration | [M07 Lab 7.1](../07-modules/README.md) | Composition, `for_each` on a module |
| 5d | Manage module versions | [M07 Lab 7.2](../07-modules/README.md) | SemVer tags, `version` constraints |
| **6** | **Terraform state management** | | |
| 6a | Describe the local backend | [M01 Lab 1.1](../01-iac-fundamentals/README.md), [M09 Lab 9.1](../09-environments/README.md) | `terraform.tfstate`, `.backup`, `terraform.tfstate.d/` |
| 6b | Describe state locking | [M06 Lab 6.1 step 5](../06-state-management/README.md) | Two-terminal locking demo |
| 6c | Configure remote state using the backend block | [M06 Lab 6.1](../06-state-management/README.md), [M15](../15-hcp-terraform/README.md) | azurerm backend, `cloud` block |
| 6d | Manage resource drift and Terraform state | [M02 step 9](../02-azure-first-deployment/README.md), [M06 Labs 6.2, 6.5](../06-state-management/README.md) | `-refresh-only`, `moved`, `removed`, `state rm` |
| **7** | **Maintain infrastructure with Terraform** | | |
| 7a | Import existing infrastructure | [M06 Lab 6.3](../06-state-management/README.md), [M13 Lab 13.2](../13-advanced/README.md) | `import` blocks, `-generate-config-out`, aztfexport |
| 7b | Use the CLI to inspect state | [M06 §1.5](../06-state-management/README.md) | `state list/show`, `show`, `output` |
| 7c | When and how to use verbose logging | [M13 verbose logging](../13-advanced/README.md) | `TF_LOG`, `TF_LOG_PATH` |
| **8** | **HCP Terraform** | | |
| 8a | Use HCP Terraform to create infrastructure | [M15 Lab 15.1](../15-hcp-terraform/README.md) | `terraform login`, `cloud` block, remote runs |
| 8b | Collaboration and governance features | [M15 §1.7, Lab 15.2](../15-hcp-terraform/README.md) | Teams, policy sets, health assessments |
| 8c | Organize and use workspaces and projects | [M15 Lab 15.2](../15-hcp-terraform/README.md) | Projects, variable sets, run triggers |
| 8d | Configure and use HCP Terraform integration | [M15 Labs 15.1, 15.4](../15-hcp-terraform/README.md) | VCS workflow, dynamic credentials |

---

## Study plan for students (4 weeks after the course)

| Week | Focus | Activities |
|---|---|---|
| 1 | Objectives 1–3 | Redo Labs 1.1, 2.1, 2.3 **without notes**. Read the [cram notes](cram-notes.md) §1–3 |
| 2 | Objective 4 | Redo the loops ladder and functions lab. Write 10 `for` expressions in the console from memory |
| 3 | Objectives 5–7 | Redo Labs 6.1–6.3 and 7.1. Practise `state` commands. Turn on `TF_LOG` once |
| 4 | Objective 8 + review | Lab 15.1–15.2. Take [practice exam 1](practice-exam-1.md), review every wrong answer, then take [practice exam 2](practice-exam-2.md). Book the exam when you score **≥ 85%** on both |

## Exam-day tips

1. **Read for the qualifier:** "choose **two**", "**not**", "**most** secure", "**default** behaviour".
2. **Default behaviours win points:** `plan` refreshes by default, `apply` without a plan file creates a plan and asks for approval, `terraform.tfvars` and `*.auto.tfvars` are loaded automatically.
3. **Know what was deprecated or replaced:** `terraform taint` → `apply -replace`; `terraform refresh` → `apply -refresh-only`; `null_resource` → `terraform_data`; "Terraform Cloud" → **HCP Terraform**.
4. Flag hard questions and come back. An hour goes fast.
5. The exam is product-focused, not cloud-focused. Don't over-think AWS resource details.

## Files in this folder

| File | Use |
|---|---|
| [cram-notes.md](cram-notes.md) | The facts most likely to be tested, organised by objective |
| [practice-exam-1.md](practice-exam-1.md) | 57 questions in the real formats, mapped to objectives, with explanations |
| [practice-exam-2.md](practice-exam-2.md) | 30 harder, scenario-style questions |
