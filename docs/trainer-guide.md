# Trainer Guide — Delivery Plan & Teaching Notes

This guide is for the person delivering the course. Timings assume 5 days of 09:30–18:00 with a 45-minute lunch and two 15-minute breaks, which gives 8 hours of content a day.

---

## Before the course (1 week ahead)

| Task | Detail |
|---|---|
| Subscription | One subscription per student, or one shared subscription with enough quota: about 10 B-series vCPUs, 10 public IPs, and 5 App Service plans **per student** |
| RBAC | Students: Contributor + User Access Administrator (Module 10 creates role assignments), and permission to create Entra ID groups and app registrations (Modules 10 and 12). Otherwise run those labs as demos |
| Providers | Register the resource providers ([00-lab-setup §5](../00-lab-setup/README.md#5-register-resource-providers-one-time-per-subscription)) |
| Pre-work email | Send Module 00 and ask students to run `check-prereqs` and reply with a screenshot |
| Dry run | Run every lab end to end in the training subscription. Quotas and region SKU availability change |
| Policies | Check for corporate Azure Policies (allowed locations, required tags, deny public IPs) that could block labs, and request exemptions for the training RG prefix |
| GitHub | Day 5 needs a GitHub account (or Azure DevOps org) per student |

---

## Hour-by-hour plan

### Day 1 — Foundations

| Time | Topic | Mode |
|---|---|---|
| 09:30 | Introductions, goals, environment check (`check-prereqs`) | Discussion |
| 10:00 | **M01** IaC concepts, Terraform architecture, workflow | Slides + whiteboard |
| 10:45 | **Lab 1.1** Hello Terraform (local/random) | Hands-on |
| 11:15 | Break | |
| 11:30 | **Lab 1.2** Break-it drills, version constraints | Hands-on |
| 12:00 | **M02 Part A**: how Terraform logs in, service principals, roles and scopes. **Project [visual-guide.html](../02-azure-first-deployment/visual-guide.html)** | Visual guide |
| 12:30 | **Lab 2.1** Steps 1–5: resource group → storage account → container, one plan at a time | Hands-on |
| 13:15 | Lunch | |
| 14:00 | **Lab 2.1** Steps 6–10: whoami, update vs replace, drift. **Lab 2.2** least-privilege service principal (students without rights to create one watch your screen) | Hands-on |
| 14:30 | **Lab 2.3** Multiple providers and aliases (DR region + Entra ID) | Hands-on |
| 15:00 | **M03 Part A**: the big picture (order / kitchen / dish), then ladder **steps 1–4** (first variable, types, objects, validation) | Whiteboard + Hands-on |
| 15:45 | Break | |
| 16:00 | Ladder **steps 5–7**: run the precedence table live, locals, outputs + "the password is in state" moment | Hands-on |
| 16:30 | **M03 Part B**: Lab 3.1 Parameterise storage on Azure (Lab 3.2 console as homework if short of time) | Hands-on |
| 17:30 | Day recap quiz (M01–M03 knowledge checks), cleanup script | Quiz |

### Day 2 — Building Real Infrastructure

| Time | Topic | Mode |
|---|---|---|
| 09:30 | Recap + Q&A | |
| 09:45 | **M04** dependencies, data sources, lifecycle | Slides |
| 10:15 | **Lab 4.1** Three-tier network | Hands-on |
| 11:00 | Break | |
| 11:15 | **Lab 4.2** Lifecycle experiments + **Lab 4.3** data sources | Hands-on |
| 12:15 | **M05 Part A**: mental model + decision tree, then ladder **steps 1–2** (count, count as a switch) | Whiteboard + Hands-on |
| 13:00 | Lunch | |
| 13:45 | Ladder **steps 3–4**: the count trap vs for_each. **Project both plans side by side** | Hands-on |
| 14:15 | Ladder **steps 5–8**: map of objects, for expressions, flatten, dynamic | Hands-on |
| 15:00 | Break | |
| 15:15 | **M05 Part B**: cookbook + **Lab 5.1** real-world functions (8 tasks: guess the functions first) | Hands-on |
| 16:00 | **Lab 5.2** Data-driven Azure network | Hands-on |
| 16:45 | **Day 2 Challenge** Network from YAML | Challenge |
| 17:45 | Solution walkthrough, exam corner M04–M05, cleanup | Review |

### Day 3 — State & Reuse

| Time | Topic | Mode |
|---|---|---|
| 09:30 | **M06** state internals, backends, locking, hardening | Slides |
| 10:15 | **Lab 6.1** Bootstrap backend, migrate, locking | Hands-on |
| 11:00 | Break | |
| 11:15 | **Lab 6.2** moved / removed refactoring | Hands-on |
| 12:00 | **Lab 6.3** Import click-ops resources + generate config | Hands-on |
| 13:00 | Lunch | |
| 13:45 | **Lab 6.4** remote state + **Lab 6.5** disaster recovery | Hands-on |
| 14:30 | **M07** module design, sources, versioning, AVM | Slides |
| 15:15 | Break | |
| 15:30 | **Lab 7.1** Build vnet + storage modules, composition | Hands-on |
| 16:45 | **Lab 7.2** Git-versioned module, **Lab 7.3** AVM | Hands-on |
| 17:45 | Recap quiz M04–M07 | Quiz |

### Day 4 — Workloads & Security

| Time | Topic | Mode |
|---|---|---|
| 09:30 | Recap + **Game Days GD-1 to GD-3** (drift, stuck lock, destructive refactor) from Day 3 material | Game day |
| 10:00 | **M08** VM building blocks, cloud-init vs provisioners, identities + **Lab 8.1** Linux VM | Slides + Hands-on |
| 11:00 | Break | |
| 11:15 | **Lab 8.2** App Service + monitoring + managed identity | Hands-on |
| 12:15 | **M09** environment patterns + **Lab 9.2** per-env backends (Lab 9.1 as a 10-min demo) | Slides + Hands-on |
| 13:15 | Lunch | |
| 14:00 | **M10** secrets threat model, Key Vault RBAC, Policy + **Lab 10.1** | Slides + Hands-on |
| 15:00 | **Lab 10.2** Policy (Deny in action) + **Lab 10.3** scanning | Hands-on |
| 15:45 | Break | |
| 16:00 | **Lab 10.4** HashiCorp Vault (ephemeral + write-only) | Hands-on |
| 16:30 | **M11** testing pyramid + **Labs 11.1–11.3** (mocked tests, TFLint) | Slides + Hands-on |
| 17:45 | Cleanup + exam corner quiz M08–M11 | Quiz |

### Day 5 — Expert Practice & Certification

| Time | Topic | Mode |
|---|---|---|
| 09:30 | **M12** pipeline design + OIDC + **Lab 12.1** bootstrap + **Lab 12.2** GitHub Actions (12.3 Azure DevOps as demo) | Slides + Hands-on |
| 11:00 | Break | |
| 11:15 | **M15 HCP Terraform**: concepts, **Lab 15.1** `cloud` block + state migration | Slides + Hands-on |
| 12:15 | **Lab 15.2** HCP as code (projects, variable sets, dynamic credentials, run triggers, policy) + 15.3/15.4 demo | Hands-on |
| 13:15 | Lunch | |
| 14:00 | **M13** AzAPI, ephemeral/write-only, bulk import, **Lab 13.3 provider upgrade 4 → 5**, logging | Demo + Hands-on |
| 15:30 | Break | |
| 15:45 | **M14 Capstone** build (pairs) | Project |
| 17:15 | Capstone **CAB review**: each pair presents its plan, risks, rollback, and tests | Review |
| 17:45 | **Exam readiness:** practice exam 1 (timed), certification study plan, feedback, **full cleanup** | Quiz |

> **If you are behind schedule:** Lab 2.2, Lab 4.3, Lab 6.4, Lab 7.2, Lab 9.1, Lab 12.3, and Lab 15.4 can become 5-minute demos without losing continuity. Never cut the loops ladder (M05 Part A) or Lab 15.1: they carry the most exam weight.

### Certification and production threads (run them through all 5 days)

* **🎓 Exam corner:** finish each module with its exam corner questions (2–3 minutes). Students who answer them all are well prepared for the [practice exams](../certification/README.md).
* **📋 Tickets:** open each module by reading its Contoso ticket aloud, and close it by asking "is the ticket done, by our [Definition of Done](production-playbook.md#10-definition-of-done-for-any-terraform-change)?"
* **🏭 Game days:** GD-1 to GD-3 on the morning of Day 4, and GD-4 to GD-8 as capstone interruptions ("an incident just came in"). See [game-days.md](game-days.md).

---

## Teaching tips (from experience)

1. **Make them type.** Copy-paste learners forget by Day 3. Let them copy only from the reference solution when stuck.
2. **Read errors aloud.** When a student hits an error, project it and decode it with the class. Terraform errors are excellent once people learn to read them.
3. **Draw the graph.** For dependencies and `for_each`, draw boxes and arrows. Visual learners need it.
4. **Plan output is the hero.** Before every apply, ask: "How many adds, changes, destroys do you expect?" Then compare.
5. **Celebrate destroy.** Make cleanup a ritual at the end of every lab. It also reinforces dependency ordering.
6. **Shared subscription collisions:** the `student` variable prevents naming collisions, but global names (storage, Key Vault, web apps) also need random suffixes. Point out why.
7. **RBAC propagation surprises** (Modules 6, 10): warn students before Lab 6.1 and Lab 10.1 that the first attempt may 403, and turn it into a teaching moment.
8. **Keep a "parking lot"** on the whiteboard for advanced questions, and answer them in Module 13.

---

## Common lab issues and quick fixes

| Lab | Issue | Fix |
|---|---|---|
| All | `subscription ID could not be determined` | `ARM_SUBSCRIPTION_ID` not exported in this terminal |
| 2.1 | `StorageAccountAlreadyTaken` | Use a random suffix |
| 4.1 / 8.1 | SSH blocked | Corporate proxy hides the real IP. Use `curl ifconfig.me` from the same network, or use Cloud Shell |
| 6.1 | `403 AuthorizationPermissionMismatch` on init | Role assignment still propagating. Wait 1–2 minutes |
| 6.1 | `-migrate-state` prompt doesn't appear | They ran `init` before adding the backend block, or there is no local state |
| 7.3 | `var.ipam_pools is null` on init | Terraform older than 1.12. Upgrade |
| 8.1 | `SkuNotAvailable` | B-series unavailable in the region or zone. Change `vm_size` or the region |
| 8.2 | 403 on storage | `storage_use_azuread = true` missing in the provider |
| 10.1 | Secret creation 403 | RBAC propagation. Increase `time_sleep` |
| 10.2 | Deny doesn't trigger | Policy assignment takes up to about 15 minutes |
| 11.1 | `0 passed` on Windows | Use `-filter=tests\unit.tftest.hcl` (backslash) |
| 12.2 | `AADSTS70021: No matching federated identity record` | The subject doesn't match. Check the environment name and the branch in the job |
| 15.1 | Remote plan fails: `unable to build authorizer` | The run executes on HCP, so `az login` doesn't apply. Configure workspace variables or dynamic credentials |
| 15.2 | `organization ... not found` / feature not available | Wrong org name or token, or the feature (policy sets, some team settings) isn't in the student's HCP plan |
| 10.4 | `permission denied` from Vault | `VAULT_ADDR` / `VAULT_TOKEN` not exported in this terminal |
| All | `No space left on device` during `init` | On Windows each `.terraform` folder holds a full copy of each provider (azurerm is about 250 MB). Delete `.terraform` folders of finished labs, and keep labs outside OneDrive-synced folders |

---

## End-of-course cleanup

```bash
./00-lab-setup/scripts/cleanup.sh --include-state --force
az ad app list --display-name "app-" --query "[?contains(displayName,'terraform-cicd')].{name:displayName,id:appId}" -o table   # delete these
az ad group list --query "[?contains(displayName,'lab10-kv-readers')].id" -o tsv                                           # delete these
az policy definition list --query "[?contains(name,'require-cost-center')].name" -o tsv                                   # delete these
```
