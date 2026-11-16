# Practice Exam 1 — Terraform Associate (004)

**57 questions · 60 minutes · pass target ≥ 70% (aim for 85%+)**
Formats: **[T/F]** true/false · **[MC]** one answer · **[MA-n]** choose *n* answers. The objective number is shown in brackets.

Answer on paper first. The answer key with explanations is at the end.

---

1. **[T/F] (1a)** Infrastructure as Code means you describe infrastructure in machine-readable definition files rather than configuring it manually.

2. **[MA-2] (1b)** Which are advantages of IaC?
   A. Changes can be peer-reviewed in version control
   B. It eliminates the need for cloud provider accounts
   C. Environments can be reproduced consistently
   D. It guarantees zero cost for infrastructure
   E. It removes the need for networking knowledge

3. **[MC] (1c)** How does Terraform support multi-cloud deployments?
   A. It translates one cloud's resources into another's automatically
   B. It uses one workflow and language, with a provider per platform, and a configuration can use several providers
   C. It only supports one provider per configuration
   D. It requires HCP Terraform to talk to more than one cloud

4. **[T/F] (1c)** A single Terraform configuration can manage resources in Azure, GitHub, and an on-premises VMware cluster at the same time.

5. **[MC] (2a)** What does `version = "~> 3.4"` allow?
   A. Only 3.4.0
   B. >= 3.4.0 and < 3.5.0
   C. >= 3.4 and < 4.0
   D. Any version newer than 3.4

6. **[MC] (2a)** Which file records the exact provider versions selected during `terraform init`?
   A. `terraform.tfstate`
   B. `.terraform.lock.hcl`
   C. `versions.tf`
   D. `.terraformrc`

7. **[T/F] (2a)** The dependency lock file also records the versions of modules.

8. **[MC] (2a)** You need newer provider versions that are still allowed by your constraints, but the lock file pins older ones. Which command?
   A. `terraform init -reconfigure`
   B. `terraform get -update`
   C. `terraform init -upgrade`
   D. `terraform apply -upgrade`

9. **[MC] (2b)** Where does Terraform download providers from by default?
   A. GitHub releases
   B. The Terraform Registry
   C. The cloud vendor's website
   D. They are compiled into the Terraform binary

10. **[MC] (2c)** How do you make one resource use a second configuration of the `azurerm` provider that has `alias = "dr"`?
    A. `provider = "azurerm.dr"`
    B. `provider = azurerm.dr`
    C. `alias = azurerm.dr`
    D. `providers = { azurerm = dr }`

11. **[MA-2] (2d)** What does Terraform use state for?
    A. Mapping resources in configuration to real-world objects
    B. Storing provider plugin binaries
    C. Tracking metadata such as dependencies
    D. Storing the HCL source code
    E. Replacing version control

12. **[T/F] (2d)** Terraform state can contain sensitive values in plain text.

13. **[MC] (3a)** What is the correct order of the core workflow?
    A. plan → write → apply
    B. write → plan → apply
    C. init → apply → plan
    D. validate → write → apply

14. **[MA-2] (3b)** What does `terraform init` do?
    A. Downloads providers
    B. Creates infrastructure
    C. Initialises the backend
    D. Formats code
    E. Destroys orphaned resources

15. **[T/F] (3b)** It is safe to run `terraform init` multiple times.

16. **[MC] (3c)** Which command checks syntax and internal consistency without contacting remote services?
    A. `terraform plan`
    B. `terraform validate`
    C. `terraform fmt`
    D. `terraform show`

17. **[MA-2] (3d)** Which commands refresh state automatically unless told not to?
    A. `terraform plan`
    B. `terraform validate`
    C. `terraform apply`
    D. `terraform fmt`
    E. `terraform output`

18. **[MC] (3d)** Values are saved in `terraform.tfvars` in the working directory. Which command uses them?
    A. `terraform plan`
    B. `terraform plan -var-file=terraform.tfvars`
    C. All of the above
    D. None of the above

19. **[MC] (3d)** In plan output, what does `-/+` mean?
    A. Update in place
    B. Destroy and then re-create (replace)
    C. Read a data source
    D. Move state

20. **[MA-2] (3e)** What happens when you run `terraform apply` (with no plan file)?
    A. Terraform makes the infrastructure changes defined in the configuration
    B. Terraform downloads plugins
    C. Terraform updates the state file with the changes made
    D. Terraform fixes formatting
    E. Terraform destroys and re-creates everything

21. **[MC] (3e)** Which flag replaces the deprecated `terraform taint` workflow?
    A. `-target`
    B. `-replace`
    C. `-recreate`
    D. `-refresh-only`

22. **[MC] (3f)** How do you preview what `terraform destroy` would remove?
    A. `terraform show -destroy`
    B. `terraform plan -destroy`
    C. `terraform destroy -dry-run`
    D. `terraform validate -destroy`

23. **[MC] (3g)** Which command fails in CI if any file is not canonically formatted?
    A. `terraform fmt -check`
    B. `terraform validate -fmt`
    C. `terraform lint`
    D. `terraform fmt -diff`

24. **[MC] (4a)** What is the main difference between a `resource` block and a `data` block?
    A. Data blocks are faster
    B. Resources are managed by Terraform. Data sources only read existing information
    C. Data blocks can only read Terraform outputs
    D. There is none

25. **[MC] (4b)** How do you reference the `id` of `data "azurerm_subnet" "app"`?
    A. `azurerm_subnet.app.id`
    B. `data.azurerm_subnet.app.id`
    C. `data.app.id`
    D. `subnet.app.id`

26. **[MC] (4c)** `variable "vpc_cidrs"` is a map keyed by region. Which expression returns the value for `us-east-1`?
    A. `var.vpc_cidrs.0`
    B. `vpc_cidrs["us-east-1"]`
    C. `var.vpc_cidrs["us-east-1"]`
    D. `var.vpc_cidrs[0]`

27. **[MC] (4c)** Which has the HIGHEST precedence?
    A. `terraform.tfvars`
    B. `TF_VAR_region` environment variable
    C. `-var="region=x"` on the command line
    D. The `default` in the variable block

28. **[T/F] (4c)** A variable with no default and no supplied value causes Terraform to prompt for it interactively (unless `-input=false`).

29. **[MC] (4c)** How do you hide an output's value in CLI output?
    A. `hidden = true`
    B. `sensitive = true`
    C. `secret = true`
    D. You can't

30. **[MA-2] (4d)** Which are structural types (elements can have different types)?
    A. `list`
    B. `object`
    C. `map`
    D. `tuple`
    E. `set`

31. **[MC] (4d)** What does `optional(number, 64)` inside an object type mean?
    A. The attribute must be 64
    B. The attribute may be omitted, and then defaults to 64
    C. At most 64 attributes
    D. The type is number or null only

32. **[MC] (4e)** Which expression produces a map?
    A. `[for s in var.names : upper(s)]`
    B. `{for s in var.names : s => upper(s)}`
    C. `var.names[*]`
    D. `toset(var.names)`

33. **[MC] (4e)** `for_each` accepts which value types?
    A. A list of strings or a number
    B. A map, or a set of strings
    C. Any collection
    D. Only a map

34. **[T/F] (4e)** You can write your own functions in HCL.

35. **[MC] (4e)** What is the purpose of a `dynamic` block?
    A. Create multiple resources
    B. Generate repeated nested blocks inside a resource
    C. Load variables dynamically
    D. Make a resource optional

36. **[MC] (4f)** When should you use `depends_on`?
    A. On every resource, to be explicit
    B. Only when a dependency isn't visible through references
    C. Only with modules
    D. Never. It is deprecated

37. **[MC] (4g)** Which construct reports a **warning** but doesn't block the apply when its assertion fails?
    A. A `validation` block
    B. A `precondition`
    C. A `postcondition`
    D. A `check` block

38. **[MC] (4g)** In a `postcondition`, which object refers to the resource's own attributes?
    A. `this`
    B. `self`
    C. `each`
    D. `resource`

39. **[T/F] (4h)** Marking a variable `sensitive = true` encrypts it in the state file.

40. **[MA-2] (4h)** Which are good practices for secrets?
    A. Read them from Vault at plan/apply time
    B. Commit `terraform.tfvars` with passwords to a private repo
    C. Use ephemeral values and write-only arguments so secrets are not stored in state
    D. Print secrets with `terraform output -raw` in CI logs
    E. Hard-code the Vault token in the provider block

41. **[MC] (5a)** Which module source supports the `version` argument?
    A. `./modules/network`
    B. `git::https://example.com/net.git`
    C. `hashicorp/consul/aws` (registry)
    D. `github.com/org/net`

42. **[T/F] (5b)** A child module can directly read the variables declared in its parent (root) module.

43. **[MC] (5b)** How does a root module get a value out of a child module?
    A. `var.child.value`
    B. `module.<name>.<output_name>`
    C. `child.<resource>.<attr>`
    D. `local.module.value`

44. **[MC] (5c)** You added a new `module` block. What must you run before `plan`?
    A. `terraform get` or `terraform init`
    B. `terraform refresh`
    C. `terraform fmt`
    D. Nothing

45. **[MC] (5d)** How do you pin a Git module to a release?
    A. `version = "v1.2.0"`
    B. `?ref=v1.2.0` in the source URL
    C. `tag = "v1.2.0"`
    D. Git modules cannot be pinned

46. **[MC] (6a)** Where does the local backend store state by default?
    A. `~/.terraform.d/state`
    B. `terraform.tfstate` in the working directory
    C. `.terraform/state.json`
    D. In memory only

47. **[MC] (6b)** What does state locking prevent?
    A. Reading state
    B. Concurrent operations writing to the same state
    C. Provider upgrades
    D. Drift

48. **[T/F] (6b)** All backends support state locking.

49. **[MC] (6c)** Why can't you use `var.environment` inside a `backend` block?
    A. Backends are configured before variables are evaluated, so use partial configuration instead
    B. Variables are only for modules
    C. Backends only accept numbers
    D. You can, with `-var`

50. **[MC] (6d)** Someone changed a tag in the cloud console. How do you update state to match reality **without** changing infrastructure?
    A. `terraform apply -refresh-only`
    B. `terraform state push`
    C. `terraform apply -replace`
    D. `terraform init -reconfigure`

51. **[MC] (6d)** Which block renames a resource's address without destroying it?
    A. `import`
    B. `removed`
    C. `moved`
    D. `rename`

52. **[MC] (7a)** Which command writes HCL for resources referenced by `import` blocks that have no configuration yet?
    A. `terraform import -generate`
    B. `terraform plan -generate-config-out=generated.tf`
    C. `terraform show -config`
    D. `terraform state pull`

53. **[MA-2] (7b)** Which commands show what Terraform is managing?
    A. `terraform state list`
    B. `terraform validate`
    C. `terraform show`
    D. `terraform fmt`
    E. `terraform init`

54. **[MC] (7c)** Which environment variable turns on detailed logs?
    A. `TF_DEBUG=1`
    B. `TF_LOG=DEBUG`
    C. `TERRAFORM_VERBOSE=true`
    D. `TF_TRACE=on`

55. **[MC] (8a)** Which block connects a configuration to HCP Terraform for CLI-driven runs?
    A. `backend "hcp" {}`
    B. `cloud {}` inside the `terraform` block
    C. `provider "tfe" {}`
    D. `remote_state {}`

56. **[MA-2] (8b)** Which are HCP Terraform governance features?
    A. Policy sets (Sentinel/OPA)
    B. `terraform fmt`
    C. Team permissions
    D. The `local` backend
    E. `terraform console`

57. **[MC] (8c)** What shares variables across all workspaces in an HCP Terraform project?
    A. A `.tfvars` file in each repo
    B. A variable set assigned to the project
    C. Run triggers
    D. Workspace tags

---

<details><summary><b>Answer key with explanations</b></summary>

| # | Answer | Explanation |
|---|---|---|
| 1 | True | That is the definition of IaC |
| 2 | A, C | Review/versioning and consistency. IaC doesn't remove cost or the need for knowledge |
| 3 | B | One workflow and language, with providers per platform. Resources are **not** auto-translated between clouds |
| 4 | True | Multiple providers in one configuration |
| 5 | C | `~> 3.4` allows the rightmost component to increase: >= 3.4, < 4.0 |
| 6 | B | The dependency lock file |
| 7 | False | It records **providers only**. Modules are not locked |
| 8 | C | `init -upgrade` |
| 9 | B | The public Terraform Registry (unless a mirror is configured) |
| 10 | B | `provider = <name>.<alias>`, unquoted |
| 11 | A, C | Mapping and metadata. Plugins live in `.terraform`, and code lives in Git |
| 12 | True | State can contain passwords and keys, so protect it |
| 13 | B | Write → plan → apply |
| 14 | A, C | Providers/modules and backend initialisation |
| 15 | True | It is idempotent |
| 16 | B | `validate` |
| 17 | A, C | `plan` and `apply` refresh by default |
| 18 | C | `terraform.tfvars` is loaded automatically, and passing it explicitly also works |
| 19 | B | Replace |
| 20 | A, C | It changes infrastructure and records the result in state |
| 21 | B | `terraform apply -replace=ADDR` |
| 22 | B | `plan -destroy` |
| 23 | A | `fmt -check` exits non-zero when files need formatting |
| 24 | B | Managed vs read-only |
| 25 | B | Data sources are prefixed with `data.` |
| 26 | C | Map key access through `var.` |
| 27 | C | Command-line `-var` / `-var-file` win |
| 28 | True | An interactive prompt, unless `-input=false` |
| 29 | B | `sensitive = true` (still stored in state) |
| 30 | B, D | object and tuple are structural. list/map/set are collections |
| 31 | B | An optional attribute with a default |
| 32 | B | Braces with `key => value` |
| 33 | B | A map or a set of strings |
| 34 | False | Only built-in (and provider-defined) functions |
| 35 | B | Repeated nested blocks |
| 36 | B | For hidden dependencies only |
| 37 | D | `check` blocks warn. Validations and conditions error |
| 38 | B | `self` |
| 39 | False | It only redacts CLI output |
| 40 | A, C | Vault plus ephemeral/write-only values. Never commit or print secrets |
| 41 | C | `version` applies to registry sources only |
| 42 | False | Data flows only through inputs and outputs |
| 43 | B | `module.<name>.<output>` |
| 44 | A | Modules must be installed |
| 45 | B | `?ref=` |
| 46 | B | `terraform.tfstate` |
| 47 | B | Concurrent writes and corruption |
| 48 | False | Locking depends on the backend |
| 49 | A | Use `-backend-config` (partial configuration) |
| 50 | A | `apply -refresh-only` |
| 51 | C | `moved` |
| 52 | B | `-generate-config-out` |
| 53 | A, C | `state list` and `show` |
| 54 | B | `TF_LOG` with a level (TRACE/DEBUG/INFO/WARN/ERROR/JSON) |
| 55 | B | The `cloud` block (plus `terraform login`) |
| 56 | A, C | Policy sets and team permissions |
| 57 | B | A project-scoped variable set |
</details>
