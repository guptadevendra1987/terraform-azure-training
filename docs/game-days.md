# Game Days — Production Incident Simulations

In a game day, the trainer **breaks something**, and students respond as the on-call engineer would. They diagnose it, fix it, and write a short incident note. Every scenario below is safe to run in the training subscription.

**How to run one (20–30 min each):**

1. The trainer runs the **Inject** steps on a student's (or a shared) deployment, without telling them what changed.
2. Students receive only the **Alert** text.
3. Students investigate and fix it, then write a 5-line incident note: *what happened, impact, how detected, fix, prevention*.
4. Debrief using the **Expected response**.

Recommended timing: Game days 1–3 at the end of Day 3, 4–6 at the end of Day 4, and 7–8 during the capstone.

---

## GD-1 · "Someone fixed it in the Portal" (drift)

**Prerequisite:** Lab 4.1 network deployed.
**Inject:**

```bash
az network nsg rule create -g rg-dg-net-dev --nsg-name nsg-dg-dev-web -n hotfix-allow-8080 \
  --priority 300 --destination-port-ranges 8080 --access Allow --protocol Tcp
az network vnet update -g rg-dg-net-dev -n vnet-dg-dev --set tags.changed_by=portal
```

**Alert:** *"The nightly drift job exited with code 2 for stack network-dev."*

**Expected response:**

1. Run `terraform plan -refresh-only` to see exactly what changed outside Terraform.
2. Ask: **is the change wanted?** In this scenario, the 8080 rule was a real hotfix (keep it) and the tag was noise (revert it).
3. Codify the rule in HCL (a PR), then run `terraform apply` to remove the stray tag.
4. Prevention: read-only Portal RBAC for prod, and nightly drift detection.

---

## GD-2 · "The pipeline is stuck: state locked"

**Prerequisite:** Lab 6.1 (remote backend).
**Inject:** run `terraform apply` in a terminal and **close the terminal window** at the confirmation prompt, which leaves the blob lease held.
**Alert:** *"All runs for app-dev fail with 'Error acquiring the state lock' for 30 minutes."*

**Expected response:**

1. Read the lock info: who, when, which operation.
2. Confirm nobody is running (pipeline history, ask the person named in the lock).
3. Run `terraform force-unlock <ID>`, then `terraform plan` to confirm the state is healthy.
4. Prevention: `cancel-in-progress: false`, job timeouts, and no laptop applies.

---

## GD-3 · "The plan wants to delete production data"

**Prerequisite:** Lab 3.1 or 6.2 storage stack.
**Inject:** in the student's code, rename `azurerm_storage_account.main` to `azurerm_storage_account.primary` (commit it as "refactor: better names").
**Alert:** *"The PR plan shows: 1 to add, 0 to change, 1 to destroy (storage account)."*

**Expected response:**

1. **Do not merge.** A refactor must never destroy anything.
2. Add a `moved` block, then plan again: `0 to add, 0 to change, 0 to destroy`.
3. Prevention: the PR checklist ("any destroy?"), `prevent_destroy` on data stores, and a CI rule that fails when a destroy appears in a prod plan without a label.

---

## GD-4 · "Apply failed half-way"

**Prerequisite:** Lab 10.1 (Key Vault + RBAC).
**Inject:** set the `time_sleep` `create_duration` to `"0s"` and run destroy + apply so RBAC isn't ready yet.
**Alert:** *"Pipeline failed: 403 Forbidden on azurerm_key_vault_secret.db_admin. 9 of 10 resources created."*

**Expected response:**

1. Don't destroy everything. Run `terraform plan` and see that only the secret is left to create (state recorded the other 9).
2. Identify the cause: RBAC propagation (a hidden dependency).
3. Fix it with an adequate `time_sleep` + `depends_on`, or simply re-apply once propagation is done.
4. Prevention: model hidden dependencies explicitly, and test with fresh environments.

---

## GD-5 · "Secret pushed to GitHub"

**Inject:** the trainer commits a `terraform.tfvars` with `sql_admin_password = "Winter2026!"` to the demo repo from Module 12.
**Alert:** *"GitHub secret scanning: a possible password was found in tf-azure-cicd-demo."*

**Expected response (the order matters):**

1. **Rotate the credential immediately.** Assume it is compromised.
2. Remove it from the repository history (`git filter-repo` or BFG) and force-push, coordinating with the team.
3. Move the secret to Key Vault/Vault, using `TF_VAR_` from pipeline secrets or ephemeral values.
4. Prevention: the gitleaks pre-commit hook, `*.tfvars` in `.gitignore`, and push protection.

---

## GD-6 · "Provider upgrade broke main"

**Inject:** in the capstone repo, change `azurerm` to `~> 5.0` and run `terraform init -upgrade` (as Dependabot would).
**Alert:** *"CI on main is red: Unsupported argument service_endpoints."*

**Expected response:**

1. Revert or pin back to `~> 4.0` to unblock the team (main must stay green).
2. Open a planned upgrade task: follow the [Lab 13.3 runbook](../13-advanced/README.md#5b-lab-133--production-drill-provider-major-upgrade-azurerm-4--5-25-min).
3. Prevention: version constraints that block major bumps, and Dependabot PRs that must pass CI before merging.

---

## GD-7 · "Production resource group deleted?!"

**Prerequisite:** capstone **prod** applied with the hub lock enabled.
**Inject:** try to delete the hub RG through the CLI as a "well-meaning colleague": `az group delete -n rg-dg-prod-hub --yes`.
**Alert:** *"Activity log alert: failed delete operation on rg-dg-prod-hub by <user>."*

**Expected response:**

1. Confirm the `ScopeLocked` error: the lock worked, and there was no impact.
2. Talk about why the user had delete rights at all (RBAC review).
3. Explain the limit: `terraform destroy` **would** remove the lock first. Discuss `prevent_destroy`, pipeline guardrails, and no destroy for prod.

---

## GD-8 · "State file overwritten"

**Prerequisite:** Lab 6.1 backend with blob versioning.
**Inject:** `terraform state pull > s.json`, delete half of the `resources` array, then `terraform state push -force s.json`.
**Alert:** *"The plan for app-dev wants to CREATE 6 resources that already exist."*

**Expected response:**

1. Stop all runs on this stack.
2. Portal → state blob → **Versions** → restore the version from before the bad push (or `az storage blob` commands).
3. `terraform plan` → "No changes".
4. Prevention: nobody has `state push` rights in prod pipelines, plus blob versioning, soft delete, and access logs.

---

## Incident note template

```text
Title:        <one line>
Detected by:  <alert / person / pipeline>         Time to detect: <min>
Impact:       <what users/teams saw>              Time to recover: <min>
Root cause:   <the real cause, not "human error">
Fix:          <what you did>
Prevention:   <code / process / RBAC change, with ticket number>
```
