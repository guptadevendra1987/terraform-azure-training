# Production Playbook — How Real Teams Run Terraform on Azure

Throughout this course, you are a new engineer on the **Platform Engineering team at Contoso Retail India**: 40 application teams, 3 environments, about 2,000 Azure resources, and an audit every quarter. Every module starts with a **📋 ticket** from this company. This playbook holds the standards those tickets expect you to follow. Real companies have a document like this, and new joiners are expected to know it.

---

## 1. Operating model

```text
                 ┌────────────────────────── Platform team (you) ──────────────────────────┐
                 │ landing zones · hub network · policies · module library · pipelines      │
                 │ state storage · CI identities · HCP Terraform / workspace vending        │
                 └───────────────▲───────────────────────────────────────────┬─────────────┘
           versioned modules,    │ pull requests to                          │ modules, pipeline templates,
           pipeline templates    │ platform repo                             │ subscriptions, identities
                 ┌───────────────┴──────────┐                    ┌───────────▼──────────────┐
                 │ App team: payments       │   ...  40 teams    │ App team: catalog         │
                 │ repo: payments-infra     │                    │ repo: catalog-infra       │
                 └──────────────────────────┘                    └──────────────────────────┘
```

| Who | Owns | Can change prod by |
|---|---|---|
| Platform team | Hub network, policy, shared modules, pipelines | PR + 2 approvals + change window |
| App teams | Their spoke resources, using platform modules | PR + 1 approval from their team + automated policy checks |
| Security team | Policy definitions, scanner rules, Key Vault standards | PR to the policy repo |
| Nobody | Manual changes in the Portal for prod | — (read-only RBAC; break-glass only) |

---

## 2. Repository standard

```text
payments-infra/
├── .github/
│   ├── CODEOWNERS                 # who must review which paths
│   ├── pull_request_template.md   # plan summary + risk + rollback
│   └── workflows/terraform.yml    # calls the platform's reusable workflow
├── stacks/                        # one folder = one state = one blast radius
│   ├── network/
│   ├── data/
│   └── app/
│       ├── main.tf  variables.tf  outputs.tf  providers.tf  versions.tf
│       └── env/
│           ├── dev/   terraform.tfvars  backend.hcl
│           └── prod/  terraform.tfvars  backend.hcl
├── tests/                         # terraform test files
├── docs/
│   ├── adr/                       # architecture decision records
│   └── runbooks/                  # what to do when things break
├── .pre-commit-config.yaml
├── .tflint.hcl
└── README.md                      # how to deploy, owners, on-call
```

**Stack sizing rule:** if a plan takes more than about 5 minutes or touches more than about 300 resources, split the stack. Things that change together stay together (an app and its storage). Things with different lifecycles are separated (network vs. app).

---

## 3. Naming standard (based on the Microsoft Cloud Adoption Framework)

Pattern: `<type>-<workload>-<env>-<region>-<instance>`, all lowercase.

| Resource | Abbreviation | Example |
|---|---|---|
| Resource group | `rg` | `rg-payments-prod-cin-001` |
| Virtual network / subnet | `vnet` / `snet` | `vnet-hub-prod-cin-001` / `snet-app` |
| Network security group | `nsg` | `nsg-payments-app-prod-cin` |
| Public IP | `pip` | `pip-agw-payments-prod-cin` |
| Key Vault | `kv` (≤24 chars) | `kv-payments-prod-cin` |
| Storage account | `st` (no dashes, ≤24) | `stpaymentsprodcin001` |
| Log Analytics | `log` | `log-platform-prod-cin` |
| App Service plan / app | `asp` / `app` | `app-payments-api-prod-cin` |
| Managed identity | `id` | `id-payments-api-prod` |
| Private endpoint | `pe` | `pe-stpaymentsprodcin001-blob` |

Region short codes: `cin` = Central India, `sin` = South India, `win` = West India. Naming is implemented **once** in a `locals` block or a naming module, never typed by hand in each resource ([Module 05, Task 1](../05-expressions-meta-arguments/labs/functions-real-world/main.tf)).

---

## 4. Tagging policy (enforced by Azure Policy in `Deny` mode)

| Tag | Required | Example | Used by |
|---|---|---|---|
| `owner` | ✅ | `payments-team` | Incident routing |
| `cost_center` | ✅ | `CC-1042` | Finance chargeback |
| `environment` | ✅ | `prod` | Policy, monitoring |
| `managed_by` | ✅ | `terraform` | "Don't touch in the Portal" signal |
| `data_classification` | ✅ for data stores | `confidential` | Security reviews |
| `repo` | recommended | `github.com/contoso/payments-infra` | Find the code from the Portal |

Mandatory tags are merged **last** so teams cannot override them: `merge(var.extra_tags, local.mandatory_tags)`.

---

## 5. Version policy

| Item | Rule |
|---|---|
| Terraform CLI | `required_version = "~> 1.12"` and the same version in every pipeline. Upgrade quarterly |
| Providers | `~>` on the minor version (`~> 4.30`). **Commit `.terraform.lock.hcl`**, generated for all platforms: `terraform providers lock -platform=linux_amd64 -platform=windows_amd64 -platform=darwin_arm64` |
| Major provider upgrades | A dedicated PR, following the [upgrade runbook](../13-advanced/README.md#5b-lab-133--production-drill-provider-major-upgrade-azurerm-4--5-25-min). The plan must show **no changes** |
| Modules | SemVer Git tags or registry versions. Consumers pin `~> MAJOR.MINOR`. Breaking changes mean a major version plus a migration note |
| Renovate/Dependabot | Opens weekly PRs for provider and module bumps, and CI plans them automatically |

---

## 6. Change workflow

```text
 1. Ticket (PLAT-123) ──▶ 2. Branch feat/PLAT-123-add-subnet ──▶ 3. Commit (pre-commit: fmt, validate, tflint, checkov, gitleaks)
 4. Pull request ──▶ CI: static checks + tests + plan for each env, posted as a PR comment
 5. Review (CODEOWNERS) using the checklist below ──▶ 6. Merge
 7. Apply dev (saved plan) ──▶ smoke tests ──▶ 8. Change approval (CAB for prod "normal" changes) ──▶ 9. Apply prod in the change window
10. Verify (monitoring, the runbook's checks) ──▶ 11. Close the ticket with the plan/apply links
```

### Change types

| Type | Example | Approval |
|---|---|---|
| Standard (pre-approved) | Add a tag, scale an App Service plan, add an NSG rule from the approved list | PR review only |
| Normal | New subnet, new service, provider upgrade | PR review + CAB / change approval, inside a change window |
| Emergency | Production outage fix | Incident commander approval, then a retrospective PR within 24 hours |

### Plan review checklist (put it in the PR template)

- [ ] The plan summary (`X to add, Y to change, Z to destroy`) matches what the ticket asks for
- [ ] **Any `destroy` or `-/+ replace`?** Each one is explained in the PR. Data stores replaced = **stop**
- [ ] No unexpected changes to resources the PR didn't touch (could be drift, so investigate)
- [ ] No secrets in the diff, tfvars, or outputs
- [ ] Security scanners pass, or have justified suppressions
- [ ] Cost impact reviewed (Infracost comment or HCP cost estimation)
- [ ] A rollback plan is written down

---

## 7. Apply runbook (production)

1. Confirm the change ticket is approved and you are inside the window.
2. Announce in `#platform-changes`: *"Applying PLAT-123 to prod: +1 subnet, 0 destroy. ETA 5 min."*
3. Approve the pipeline's prod environment. **Never** apply prod from a laptop.
4. Watch the apply logs. If it fails part-way, **do not** panic and re-run blindly (see the runbook below).
5. Verify: the resource exists, monitoring is green, and the smoke test passes.
6. Post the result, and link the run in the ticket.

### Rollback strategy

Terraform has **no "undo" button**. Rolling back means applying the previous code:

* `git revert <merge-commit>` → PR → pipeline → apply (the same process as any change)
* For data stores: rely on **backups, soft delete, and versioning**. A revert does not bring back deleted data.
* For risky changes, prefer **expand → migrate → contract** (add the new thing, move traffic, remove the old thing in a later change).

---

## 8. Day-2 operations

| Activity | Frequency | How |
|---|---|---|
| Drift detection | Nightly | Scheduled `plan -detailed-exitcode` or HCP health assessments. Exit code 2 opens a ticket |
| Provider/module updates | Weekly PRs | Renovate/Dependabot + CI plan |
| Terraform CLI upgrade | Quarterly | Upgrade dev stacks first. Explorer or a repo search finds stragglers |
| State backup check | Monthly | Restore a previous blob version in a test container |
| Access review | Quarterly | Who can write state and who can approve prod |
| Break-glass test | Quarterly | The emergency account works and alerts fire |
| Cost review | Monthly | Untagged resources, idle resources, SKU right-sizing |

---

## 9. Incident runbooks (summary)

Full exercises are in [game-days.md](game-days.md).

| Symptom | First response |
|---|---|
| `Error acquiring the state lock` | Check for a running pipeline. If none, `force-unlock <ID>` and record why |
| Unexpected destroy in a prod plan | **Stop.** Do not apply. Diff the code, look for drift, missing `moved` blocks, or provider changes |
| Apply failed part-way | Re-run `plan`, because state records what succeeded. Fix the cause and apply the remainder |
| Someone changed prod in the Portal | `plan -refresh-only` to see it. Either codify the change (PR) or revert it (apply). Then fix the RBAC gap |
| A secret was committed to Git | **Rotate the secret first**, then purge the history, then add gitleaks |
| State file corrupted or deleted | Restore the previous blob version (versioning + soft delete), then plan, and expect "No changes" |

---

## 10. Definition of Done for any Terraform change

- [ ] Code formatted, validated, linted, and scanned
- [ ] Variables typed, described, and validated. Outputs described
- [ ] Names and tags follow the standards
- [ ] Tests updated (`terraform test`) for module changes
- [ ] Plan reviewed for every environment
- [ ] README / ADR / runbook updated if behaviour changed
- [ ] Applied through the pipeline, never from a laptop
