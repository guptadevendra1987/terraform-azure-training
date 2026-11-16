# Practice Exam 2 — Scenario Questions (Harder)

**30 questions · 35 minutes.** Formats: **[T/F]**, **[MC]**, **[MA-n]**. These test *understanding*, not recall. Many are based on situations from the labs.

---

1. **[MC] (4e)** A list `["a","b","c"]` is used with `count`. You remove `"a"` and run plan. What happens?
   A. Only `[0]` is destroyed
   B. `[0]` and `[1]` are updated or replaced, and `[2]` is destroyed
   C. Nothing changes
   D. Terraform errors

2. **[MC] (4e)** `for_each = toset([for s in azurerm_subnet.x : s.id])` fails during the first plan. Why?
   A. Sets aren't allowed
   B. The subnet IDs aren't known until apply, and `for_each` keys must be known at plan time
   C. `toset` is deprecated
   D. You must use `count`

3. **[MC] (4e)** Which returns `null` when the conditional resource `azurerm_public_ip.pip` has `count = 0`?
   A. `azurerm_public_ip.pip[0].id`
   B. `one(azurerm_public_ip.pip[*].id)`
   C. `azurerm_public_ip.pip.id`
   D. `lookup(azurerm_public_ip.pip, "id")`

4. **[MC] (4e)** What is `merge({owner="team"}, {owner="x", env="dev"})`?
   A. `{owner="team", env="dev"}`
   B. `{owner="x", env="dev"}`
   C. An error: duplicate key
   D. `{owner=["team","x"], env="dev"}`

5. **[MC] (4d)** `variable "x" { type = list(string) }` is passed `["a", 1]`. What happens?
   A. An error
   B. `1` is converted to `"1"`
   C. The list becomes a tuple
   D. `1` is dropped

6. **[MA-2] (4g)** You must reject a storage account name with uppercase letters **before** anything is created. Which work?
   A. A `validation` block on the variable
   B. A `check` block
   C. A `precondition` on the resource
   D. An output with `sensitive = true`
   E. `depends_on`

7. **[T/F] (4g)** A failing `check` block assertion stops `terraform apply`.

8. **[MC] (4f)** A VM's startup script reads a Key Vault secret. The role assignment is created in the same configuration but not referenced by the VM. What should you add?
   A. Nothing
   B. `depends_on = [azurerm_role_assignment.kv]` on the VM
   C. `lifecycle { create_before_destroy = true }`
   D. A `moved` block

9. **[MC] (2c)** You must deploy the same module into two subscriptions. What is the correct approach?
   A. Two `terraform` blocks
   B. Two aliased provider configurations, passed with `providers = { azurerm = azurerm.sub2 }`
   C. Set `subscription_id` inside the child module
   D. Use two workspaces at the same time

10. **[MC] (5b)** A child module needs the root module's `local.tags`. How?
    A. Reference `local.tags` directly in the child
    B. Declare `variable "tags"` in the child and pass `tags = local.tags`
    C. Use `parent.local.tags`
    D. Use `terraform_remote_state`

11. **[MC] (5d)** Your module consumers must get bug fixes automatically, but not breaking changes, from a registry module currently at 2.3.1. Which constraint?
    A. `= 2.3.1`
    B. `>= 2.3.1`
    C. `~> 2.3`
    D. `~> 2`

12. **[T/F] (5a)** `terraform init` must be re-run after changing a module's `source` or `version`.

13. **[MC] (6c)** You switch between `env/dev.backend.hcl` and `env/prod.backend.hcl`. Terraform asks whether to copy state. What should you use?
    A. `terraform init -migrate-state`
    B. `terraform init -reconfigure -backend-config=env/prod.backend.hcl`
    C. `terraform state push`
    D. `terraform workspace new prod`

14. **[MC] (6b)** A CI job was killed during apply, and now every run says "Error acquiring the state lock". After confirming no run is active, what do you do?
    A. Delete the state file
    B. `terraform force-unlock <LOCK_ID>`
    C. `terraform init -upgrade`
    D. `terraform apply -lock=false` forever

15. **[MC] (6d)** You want Terraform to stop managing a resource but keep it running. Which is the declarative, reviewable way?
    A. `terraform state rm`
    B. A `removed` block with `lifecycle { destroy = false }`
    C. Delete the resource block
    D. `terraform destroy -target`

16. **[MC] (6d)** You renamed `azurerm_storage_account.main` to `.logs` in code. What prevents data loss?
    A. `terraform apply -replace`
    B. A `moved { from = azurerm_storage_account.main  to = azurerm_storage_account.logs }` block
    C. `import` block
    D. `prevent_destroy` alone

17. **[T/F] (6a)** CLI workspaces with the local backend store state under `terraform.tfstate.d/<workspace>/`.

18. **[MC] (7a)** After importing with an `import` block, the plan shows `~ update in-place`. What does that mean?
    A. The import failed
    B. Your configuration doesn't exactly match the real resource, so review it before applying
    C. Imports always update resources
    D. The state is corrupted

19. **[MC] (7c)** A provider returns a vague 400 error. What is the best next step?
    A. `TF_LOG=DEBUG terraform plan`, then inspect the HTTP request and response
    B. Delete `.terraform`
    C. Downgrade Terraform
    D. Use `-target`

20. **[MA-2] (7b)** Which commands read state without modifying it?
    A. `terraform state list`
    B. `terraform state rm`
    C. `terraform state show`
    D. `terraform state push`
    E. `terraform state mv`

21. **[MC] (3d)** A pipeline must apply exactly what was reviewed in the PR. Which pattern?
    A. `terraform apply -auto-approve` in both jobs
    B. `terraform plan -out=tfplan`, review, then `terraform apply tfplan`
    C. `terraform apply -refresh=false`
    D. `terraform plan -detailed-exitcode` only

22. **[MC] (3d)** What does `terraform plan -detailed-exitcode` return when changes are present?
    A. 0
    B. 1
    C. 2
    D. 3

23. **[T/F] (3e)** `terraform apply tfplan` asks for interactive approval.

24. **[MC] (4h)** Which keeps a database password **out of the state file** entirely?
    A. `sensitive = true` on the variable
    B. Ephemeral `random_password` + the resource's write-only `*_wo` argument
    C. `nonsensitive()`
    D. Storing the password in an output

25. **[MC] (8a)** You add a `cloud` block to a configuration that already has local state, then run `terraform init`. What happens?
    A. Local state is deleted
    B. Terraform offers to migrate the existing state to the HCP Terraform workspace
    C. An error: backends cannot change
    D. Both states are kept in sync

26. **[MC] (8a)** A remote run in HCP Terraform fails to authenticate to Azure, though `az login` works on your laptop. Why?
    A. HCP Terraform doesn't support Azure
    B. The run executes on HCP infrastructure, so credentials must come from workspace variables or dynamic credentials
    C. You need `terraform login` again
    D. The `cloud` block is missing `subscription_id`

27. **[MC] (8b)** Which policy enforcement level blocks the run but allows an authorised user to override?
    A. advisory
    B. soft-mandatory
    C. hard-mandatory
    D. mandatory-override

28. **[MC] (8c)** Workspace **app** must re-run whenever workspace **network** applies successfully. What should you configure?
    A. A variable set
    B. A run trigger on app, with network as the source
    C. A VCS webhook
    D. `depends_on`

29. **[MC] (8d)** Which workflow gives a pull request an automatic speculative plan?
    A. CLI-driven
    B. VCS-driven
    C. API-driven with no configuration
    D. Local execution mode

30. **[MA-2] (8b)** Which two capabilities make up HCP Terraform **health assessments**?
    A. Health assessments (drift detection)
    B. The private registry
    C. Continuous validation of `check` blocks
    D. Variable sets
    E. Run triggers

---

<details><summary><b>Answer key with explanations</b></summary>

| # | Answer | Why |
|---|---|---|
| 1 | B | Indexes shift (the count trap). See loops ladder step 3 |
| 2 | B | `for_each` keys must be known during plan |
| 3 | B | `one()` of an empty list is `null` |
| 4 | B | Later arguments override earlier ones |
| 5 | B | Terraform converts compatible primitive values to the declared type (number → string) |
| 6 | A, C | Both run before creation. `check` only warns |
| 7 | False | `check` blocks produce warnings |
| 8 | B | A hidden dependency calls for `depends_on` |
| 9 | B | Aliased providers passed to the module |
| 10 | B | Child modules only see their own inputs |
| 11 | C | `~> 2.3` allows 2.x (>= 2.3) but not 3.0 |
| 12 | True | Modules are installed by init/get |
| 13 | B | `-reconfigure` switches backends without migrating |
| 14 | B | `force-unlock` after confirming nobody is running |
| 15 | B | `removed` is plannable and reviewable. `state rm` is imperative |
| 16 | B | A `moved` block |
| 17 | True | The `terraform.tfstate.d` folder |
| 18 | B | Align the configuration with reality first |
| 19 | A | Verbose logs show the API exchange |
| 20 | A, C | `list` and `show` are read-only |
| 21 | B | A saved plan file |
| 22 | C | 0 = no changes, 1 = error, 2 = changes |
| 23 | False | Applying a saved plan doesn't prompt |
| 24 | B | Ephemeral + write-only values are never persisted |
| 25 | B | `init` offers state migration |
| 26 | B | Remote execution environment |
| 27 | B | soft-mandatory |
| 28 | B | Run triggers |
| 29 | B | VCS-driven |
| 30 | A, C | Health assessments = drift detection + continuous validation (re-checking `check` blocks and conditions) |
</details>
