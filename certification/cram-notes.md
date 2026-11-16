# Terraform Associate (004) — Cram Notes

The most testable facts, organised by exam objective. Read this the night before the exam.

---

## 1. IaC

* **IaC** means defining infrastructure in version-controlled, human-readable code. The benefits are **repeatability, consistency, versioning, review/audit, automation, self-documentation, and speed**.
* Terraform is **declarative** (you describe the desired end state) and **idempotent** (applying again changes nothing).
* **Multi-cloud / service-agnostic:** one workflow and one language for any API that has a provider (Azure, AWS, GCP, GitHub, Datadog, Kubernetes…). One configuration can use many providers at once, which also covers hybrid cloud (on-premises + cloud).
* **Immutable infrastructure:** replace rather than modify (for example, new VM images). This reduces drift.

## 2. Fundamentals

* **Providers** are plugins that translate HCL into API calls. They are downloaded by `terraform init` from the registry (or a mirror) into `.terraform/providers`.
* `required_providers` in the `terraform {}` block: `source = "hashicorp/azurerm"` (`<namespace>/<type>`, with registry host `registry.terraform.io` by default) and `version`.
* Version constraints: `=`, `!=`, `>`, `>=`, `<`, `<=`, and `~>` (pessimistic: `~> 1.2` means `>= 1.2, < 2.0`; `~> 1.2.0` means `>= 1.2.0, < 1.3.0`).
* `required_version` constrains the **Terraform CLI** version.
* **`.terraform.lock.hcl`**: the dependency lock file. It records the **provider** versions and checksums selected (**not modules**). Commit it. `terraform init -upgrade` updates it.
* **Provider aliases:** `alias = "west"` in a provider block, then `provider = aws.west` on a resource, or `providers = { aws = aws.west }` on a module.
* **State** maps resources to real objects, stores metadata and dependencies, and improves performance. Local state lives in `terraform.tfstate` (previous version: `terraform.tfstate.backup`).
* State is plain JSON and **may contain secrets**. Protect it.

## 3. Core workflow

| Command | Key facts |
|---|---|
| `init` | Downloads providers and modules, configures the backend. Safe to run repeatedly. `-upgrade`, `-reconfigure`, `-migrate-state`, `-backend-config=` |
| `validate` | Syntax and internal consistency. **No** remote state or API access needed (after init) |
| `fmt` | Canonical style. `-check` (CI), `-recursive`, `-diff` |
| `plan` | **Refreshes by default**, then shows the changes. `-out=file`, `-destroy`, `-refresh-only`, `-refresh=false`, `-target`, `-var`, `-var-file`, `-replace` |
| `apply` | Without a plan file it plans and asks for approval. With a plan file it applies with no prompt. `-auto-approve`, `-replace=ADDR` |
| `destroy` | Destroys everything in state. Alias of `apply -destroy` |
| `show` | Human-readable state or plan. `-json` |
| `output` | Reads outputs from state. `-raw`, `-json` |
| `console` | Interactive expression evaluation |
| `graph` | DOT-format dependency graph |

Plan symbols: `+` create, `-` destroy, `~` update in place, `-/+` replace (destroy then create), `+/-` create-before-destroy replace, `<=` read data source.

## 4. Configuration

* **resource** = manage (create/update/delete). **data** = read only.
* Reference syntax: `<TYPE>.<NAME>.<ATTR>`, `data.<TYPE>.<NAME>.<ATTR>`, `var.<NAME>`, `local.<NAME>`, `module.<NAME>.<OUTPUT>`.
* **Variable precedence (low → high):** default → environment `TF_VAR_name` → `terraform.tfvars` → `terraform.tfvars.json` → `*.auto.tfvars` (alphabetical) → `-var` / `-var-file` (CLI order, the last one wins).
* No value and no default means Terraform **prompts** (unless `-input=false`, which fails instead).
* **Types:** primitive: `string`, `number`, `bool`. Complex: **collection** types `list`, `map`, `set` (all elements share one type) and **structural** types `object`, `tuple` (elements can differ). `any`, `optional(type, default)`.
* Maps are accessed with `var.m["key"]` or `var.m.key`. Lists with `var.l[0]`. Maps have **no** numeric index.
* **Meta-arguments:** `count`, `for_each`, `depends_on`, `provider`, `lifecycle` (and `providers` for modules).
* `for_each` takes a **map or a set of strings**. `count` and `for_each` cannot both be used.
* **Splat:** `aws_instance.web[*].id`.
* **Dynamic blocks** generate nested blocks. Overusing them hurts readability.
* **Functions:** built-in only, and you **cannot write your own** (provider-defined functions come from providers: `provider::<name>::<fn>`). Test them in `terraform console`.
* **Dependencies:** implicit (references, preferred) and explicit `depends_on` (hidden dependencies).
* **Custom conditions:** `validation` (on variables), `precondition`/`postcondition` (lifecycle, which **block**), `check` blocks (**warn only**).
* **Sensitive:** `sensitive = true` hides the value in CLI output and is **still stored in state**. **Ephemeral** values and **write-only** (`_wo`) arguments are never stored.
* **Vault:** Terraform reads secrets with the Vault provider (data sources or, preferably, **ephemeral** resources). Dynamic secrets have short lifetimes. Authenticate with environment variables or auth methods, never a hard-coded token.

## 5. Modules

* A module is a directory of `.tf` files. The **root module** is where you run Terraform. **Child modules** are called with `module "x" { source = ... }`.
* **Sources:** local path (`./modules/x`), Terraform Registry (`namespace/name/provider`, which **supports `version`**), GitHub, generic Git (`git::https://...?ref=v1.2.0`), HTTP URLs, S3/GCS buckets. `version` works **only** for registry sources.
* **Variable scope:** a child module **cannot** read the parent's variables, locals, or resources. Data flows **only** through module **input variables** (in) and **outputs** (out). The parent reads `module.<name>.<output>`. A child cannot read the parent's outputs.
* After adding or changing a module `source`, run `terraform init` (or `terraform get`).
* Public registry modules are verified/partner/community. **Private registry** in HCP Terraform.
* Pin module versions (`version = "~> 2.1"`) and Git tags (`?ref=`).

## 6. State

* **Local backend** (the default): `terraform.tfstate` in the working directory. CLI workspaces are stored in `terraform.tfstate.d/<workspace>/`.
* **Remote backends:** `azurerm`, `s3`, `gcs`, `consul`, `http`, …, or the `cloud` block for HCP Terraform. Backend blocks **cannot use variables**: use partial configuration with `-backend-config`.
* **Locking** prevents concurrent writes. It happens automatically on operations that write state. `-lock=false` disables it (dangerous). `terraform force-unlock LOCK_ID` releases a stuck lock. **Not all backends support locking.**
* **Drift:** `terraform plan -refresh-only` shows it, and `terraform apply -refresh-only` accepts reality into state. (`terraform refresh` is deprecated.)
* **Refactoring:** a `moved` block (rename/move without destroying), a `removed` block (forget without destroying), `terraform state mv`, and `terraform state rm`.
* `terraform state pull` / `push` (push is dangerous). Every write increments the state `serial`. `lineage` identifies the state.

## 7. Maintain

* **Import:** an `import` block (`to`, `id`, `for_each` supported) is declarative and plannable. `terraform plan -generate-config-out=x.tf` generates code. The `terraform import ADDR ID` CLI command needs the resource block to exist first.
* **Inspect state:** `terraform state list`, `terraform state show ADDR`, `terraform show`, `terraform output`.
* **Logging:** `TF_LOG=TRACE|DEBUG|INFO|WARN|ERROR|JSON`; `TF_LOG_PATH=file` (requires `TF_LOG`); `TF_LOG_CORE` / `TF_LOG_PROVIDER` separate the core and provider logs. A crash writes `crash.log`.
* `-replace=ADDR` forces recreation (replaces the deprecated `terraform taint`).
* `-target=ADDR` is for exceptional cases only. It is not for routine use.

## 8. HCP Terraform

* **Organization → projects → workspaces.** A workspace has its own state, variables, runs, settings, and permissions.
* **Workflows:** CLI-driven (`cloud` block + `terraform login`), VCS-driven (speculative plans on PRs, runs on merge), API-driven.
* `terraform login` stores the token in `credentials.tfrc.json`. The `cloud` block cannot coexist with a `backend` block. `terraform init` migrates existing state into HCP Terraform.
* **Execution modes:** remote (the default: runs on HCP), local (HCP stores state only), agent (runs on your agents in a private network).
* **Variables:** Terraform or environment category, can be marked sensitive. **Variable sets** share them across the organization, projects, or workspaces.
* **Dynamic provider credentials:** OIDC tokens per run (Azure, AWS, GCP, Vault). No static secrets.
* **Run triggers:** an apply in a source workspace queues a run in the target workspace.
* Cross-workspace data: `tfe_outputs` data source or `terraform_remote_state` (backend `remote`).
* **Governance:** teams and permissions, policy sets (**Sentinel** or **OPA**; enforcement: advisory, soft-mandatory, hard-mandatory), run tasks, cost estimation, **health assessments** (drift detection + continuous validation), Explorer, change requests, audit trails, private registry, SSO.
* The Terraform version is set **per workspace** and upgraded in the workspace settings.
