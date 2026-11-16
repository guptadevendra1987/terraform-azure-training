# Final Assessment & Interview Preparation

* **Part A:** 30 multiple-choice questions (30 min, pass mark 70%)
* **Part B:** 5 practical scenarios (discussion or written)
* **Part C:** 25 interview questions, beginner to expert, with model answers

Answers are in collapsible sections. Trainers: remove them before printing the student version.

---

## Part A — Multiple choice

1. Which command downloads providers and configures the backend?
   a) `terraform plan` b) `terraform init` c) `terraform get` d) `terraform validate`
2. What does `~> 4.0` allow?
   a) 4.0.x only b) >= 4.0, < 5.0 c) >= 4.0 d) any 4.x or 5.x
3. In azurerm v4, which setting is mandatory that was optional in v3?
   a) `features {}` b) `subscription_id` (or `ARM_SUBSCRIPTION_ID`) c) `tenant_id` d) `client_id`
4. Which has the HIGHEST variable precedence?
   a) `terraform.tfvars` b) `TF_VAR_x` c) `-var` on the CLI d) `default`
5. `sensitive = true` on an output…
   a) encrypts it in state b) hides it in CLI output only c) removes it from state d) prevents its use in modules
6. Which meta-argument is best for "0 or 1 of a resource"?
   a) `for_each` b) `count` c) `depends_on` d) `provider`
7. You remove the first item from a list used with `count`. What happens?
   a) Only that item is destroyed b) The later items are updated or replaced because their indexes shift c) Nothing d) Error
8. Which block renames a resource without destroying it?
   a) `import` b) `removed` c) `moved` d) `lifecycle`
9. How does the azurerm backend implement locking?
   a) A table b) A blob lease c) A Cosmos DB record d) It has no locking
10. Which backend argument enables Entra ID auth to the state storage?
    a) `use_msi` b) `use_azuread_auth` c) `use_oidc` d) `access_key`
11. A data source…
    a) creates resources b) reads existing objects c) deletes resources d) only works with modules
12. `create_before_destroy` is mainly used to…
    a) speed up applies b) avoid downtime on replacement c) prevent deletion d) ignore drift
13. Where should `provider` blocks live?
    a) In every module b) Only in the root module c) Only in child modules d) In tfvars
14. Which is the correct Git module source pinned to a tag?
    a) `git::https://x.git?ref=main` b) `git::https://x.git//vnet?ref=v1.2.0` c) `https://x.git@v1.2.0` d) `x.git#v1.2.0`
15. AVM stands for…
    a) Azure Virtual Machines b) Azure Verified Modules c) Azure Vault Manager d) Automated VNet Modules
16. Which statement about CLI workspaces is TRUE?
    a) Each workspace can use a different backend b) All workspaces share the same backend configuration c) Workspaces isolate credentials d) Workspaces are required for multiple environments
17. Why use `terraform init -reconfigure` when switching env backend files?
    a) To upgrade providers b) To avoid being prompted to migrate state between environments c) To delete state d) To unlock state
18. The best way for GitHub Actions to authenticate to Azure is…
    a) A client secret in repo secrets b) OIDC workload identity federation c) A storage account key d) A personal access token
19. A `check` block that fails…
    a) stops the apply b) produces a warning c) destroys the resource d) is ignored
20. `expect_failures` in a test run means…
    a) the test is skipped b) the run passes only if the listed object fails validation c) failures are ignored d) retries on failure
21. Mock providers are used to…
    a) speed up apply in prod b) run tests without real cloud calls c) mock Azure Policy d) encrypt state
22. Which is TRUE about write-only arguments (`*_wo`)?
    a) Stored encrypted in state b) Never stored in plan or state c) Require Terraform Cloud d) Only for azapi
23. When would you use `azapi_update_resource`?
    a) To delete a resource b) To set a property that azurerm doesn't expose on an existing resource c) To import d) To read data
24. Which tool generates Terraform code from an existing resource group?
    a) tflint b) aztfexport c) checkov d) terraform-docs
25. `terraform plan -detailed-exitcode` returns 2 when…
    a) there is an error b) there are no changes c) changes are present d) the state is locked
26. Which identity type should a VM use if it needs Key Vault access at first boot?
    a) System-assigned b) User-assigned c) None d) Service principal with a secret
27. An Azure `CanNotDelete` lock on a resource group…
    a) prevents `terraform destroy` entirely b) blocks Portal and CLI deletion, but Terraform removes the lock first if the lock is in the same config c) prevents updates d) is ignored by Azure
28. What does `terraform plan -refresh-only` show?
    a) Only creates b) Differences between state and real infrastructure (drift) c) Provider updates d) Module versions
29. Which file must be committed to Git?
    a) `terraform.tfstate` b) `.terraform/` c) `.terraform.lock.hcl` d) `tfplan`
30. Which is NOT a reason to split infrastructure into multiple state files?
    a) Smaller blast radius b) Faster plans c) Team ownership boundaries d) To avoid using modules

<details><summary>Answer key</summary>

1 b · 2 b · 3 b · 4 c · 5 b · 6 b · 7 b · 8 c · 9 b · 10 b · 11 b · 12 b · 13 b · 14 b · 15 b · 16 b · 17 b · 18 b · 19 b · 20 b · 21 b · 22 b · 23 b · 24 b · 25 c · 26 b · 27 b · 28 b · 29 c · 30 d
</details>

---

## Part B — Practical scenarios

**B1. Click-ops to code.** A team built 40 resources in the Portal across 3 resource groups. Describe your plan to bring them under Terraform with zero downtime.

<details><summary>Model answer</summary>

Inventory with Azure Resource Graph, then run `aztfexport` per resource group to get the import blocks and draft HCL. Refactor the code into modules, variables, and naming conventions. Iterate `terraform plan` until it shows **only imports and 0 changes** (or intentional, reviewed changes). Store state remotely, apply the imports through a pipeline, delete the import blocks afterwards, and lock down Portal write access (RBAC/Policy) so the drift does not return.
</details>

**B2. Wrong workspace.** An engineer ran `terraform destroy` in the `prod` workspace by mistake. Twelve resources are gone. What do you do now, and what do you change so it can't happen again?

<details><summary>Model answer</summary>

Now: stop all pipelines, assess the damage, and re-apply from code (stateful data needs backups: SQL PITR, storage soft delete or versioning, Key Vault soft delete). Restore the state version from blob versioning if needed. Prevent: no laptop access to prod, a separate prod subscription and identity, an approval-gated pipeline that never runs destroy, `prevent_destroy` on critical resources, resource locks, and no CLI workspaces for prod.
</details>

**B3. Secret in state.** Security found the SQL admin password in a state file. Options?

<details><summary>Model answer</summary>

Short term: rotate the password and restrict state access (RBAC, private endpoint, audit logs). Long term: use Entra-only authentication (no password), or write-only arguments with ephemeral `random_password` (`administrator_login_password_wo`), or let Key Vault and the service manage the secret outside Terraform. Pass references, not values, to apps.
</details>

**B4. "Known after apply" for_each.** `for_each = toset(azurerm_subnet.x[*].id)` fails. Why, and how do you fix it?

<details><summary>Model answer</summary>

`for_each` keys must be known at plan time, and IDs are only known after apply. Key by something static (subnet names from variables): `for_each = var.subnets`, then reference `azurerm_subnet.x[each.key].id` inside the resource.
</details>

**B5. Upgrade the azurerm major version.** How do you upgrade from 3.x to 4.x across 30 stacks safely?

<details><summary>Model answer</summary>

Read the upgrade guide (renamed or removed arguments, `subscription_id` now required, resource provider registration changes). Upgrade one non-prod stack in a branch with `init -upgrade`, fix the deprecations, and expect **zero** changes in the plan. Use `moved` blocks where resource types were renamed. Roll out per environment through the pipeline, and pin the version in shared modules with a compatible range.
</details>

---

## Part C — Interview questions (beginner → expert)

<details><summary><b>Beginner</b></summary>

1. **What is Terraform state, and why is it needed?** It maps config addresses to real resource IDs, stores metadata and dependencies, and lets Terraform compute diffs.
2. **What's the difference between `terraform plan` and `apply`?** Plan previews changes. Apply makes them.
3. **What are providers?** Plugins that translate HCL resources into API calls (azurerm → ARM).
4. **Variables vs locals vs outputs?** Inputs, internal computed values, and return values.
5. **How do you avoid committing secrets?** gitignore tfvars and state, use `TF_VAR_*` from secret stores, use OIDC or managed identities, and add a gitleaks pre-commit hook.
6. **What does `terraform fmt` do?** It rewrites files in the canonical HCL style.
7. **What is a resource address?** `type.name[index]`, for example `azurerm_subnet.this["web"]` or `module.net.azurerm_vnet.this`.
8. **What does `depends_on` do?** It adds an explicit dependency edge for hidden dependencies.
</details>

<details><summary><b>Intermediate</b></summary>

9. **count vs for_each?** count: indexed, good for 0/1 or identical copies. for_each: keyed and stable, good for named instances.
10. **What is a dynamic block?** It generates repeated nested blocks from a collection.
11. **How do you share data between stacks?** Data sources (preferred across teams), `terraform_remote_state`, or a naming convention.
12. **Explain the lifecycle options.** prevent_destroy, create_before_destroy, ignore_changes, replace_triggered_by, plus pre- and postconditions.
13. **How do you import existing resources?** `import` blocks (plus `-generate-config-out`), the `terraform import` CLI, or aztfexport.
14. **How do you handle multiple environments?** tfvars + backend per env, or directory per env, with separate subscriptions and state. Avoid workspaces for prod.
15. **What is drift, and how do you detect it?** Changes made outside Terraform. Detect it with `plan -refresh-only` or scheduled plans with `-detailed-exitcode`.
16. **Why pin provider versions, and why commit the lock file?** Reproducible builds, with no surprise breaking changes.
</details>

<details><summary><b>Advanced / Expert</b></summary>

17. **Design a Terraform platform for 50 app teams on Azure.** Landing zones (management groups, policy, hub-and-spoke) run by the platform team. A module registry (AVM wrappers). Subscription vending. Per-team state and identities with OIDC. Pipeline templates with fmt, lint, security scanning, tests, plan, approvals, and apply. Drift detection, and policy as code on plans (OPA or Sentinel).
18. **How do you refactor a monolithic state into smaller stacks?** Plan the boundaries, then use `removed { destroy = false }` in the old stack and `import` blocks in the new one (or `state mv` with `-state-out` for local operations). Verify zero changes in both.
19. **How do you test Terraform modules?** fmt/validate/tflint, checkov, `terraform test` with mocks (unit) and real providers (integration), examples as tests, and Terratest for complex end-to-end checks.
20. **How do you keep secrets out of state?** Ephemeral resources, write-only arguments, Entra-only auth, Key Vault references, and letting services generate their own credentials.
21. **When do you use AzAPI?** For day-0 or preview features, properties missing from azurerm, or POST actions. Use `azapi_update_resource` to patch.
22. **Explain OIDC federation for pipelines.** The CI issues a JWT, Entra ID matches the issuer and subject against a federated credential, and returns a short-lived token. No secret exists anywhere.
23. **What breaks when a module output is used in `count` or `for_each`?** If it's unknown at plan time, you get the "Invalid count/for_each argument" error. Design interfaces with plan-time-known keys and booleans.
24. **How would you handle a stuck lock in CI?** Confirm no run is active (pipeline history, blob lease), then `terraform force-unlock <ID>`. Investigate why the job died, and set `cancel-in-progress: false`.
25. **Terraform vs Bicep for an Azure-only company?** Bicep: day-0 Azure features, no state, a native tool. Terraform: multi-provider (Entra ID, GitHub, Datadog), a mature module and testing ecosystem, plan visibility, and existing skills. Choose based on scope, team skills, and governance tooling. Many organisations use both.
</details>
