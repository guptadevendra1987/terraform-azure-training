# Module 07 — Modules: Write, Version, Reuse

**Duration:** 4 hours (1h theory · 3h labs) · **Level:** Intermediate → Advanced
**Exam objectives:** 5a, 5b, 5c, 5d, 2c

> 📋 **Ticket PLAT-107** — Forty app teams each wrote their own VNet and storage code, all slightly different and half of them insecure. Publish versioned, secure-by-default modules that every team must use.

## Learning objectives

- Explain root modules vs child modules and the module interface (inputs and outputs)
- Write reusable modules with secure defaults, validation, and documentation
- Call modules with `for_each`, and compose modules by wiring outputs to inputs
- Source modules from local paths, Git tags, the public registry, and private registries
- Use **Azure Verified Modules (AVM)** and judge when to build your own instead
- Version and release modules with semantic versioning

---

## 1. Concepts

### 1.1 What is a module?

Any folder of `.tf` files is a module. The folder you run `terraform` in is the **root module**. Folders it calls with `module {}` blocks are **child modules**.

```text
 root module (live/dev)                      child module (modules/vnet)
 ┌──────────────────────────┐   inputs    ┌────────────────────────────┐
 │ module "network" {       │ ─────────▶  │ variable "name" {}         │
 │   source = "../vnet"     │             │ resource "azurerm_..." {}  │
 │   name   = "vnet-dev"    │  ◀───────── │ output "subnet_ids" {}     │
 │ }                        │   outputs   └────────────────────────────┘
 │ module.network.subnet_ids│
 └──────────────────────────┘
```

### 1.2 Standard module structure

```text
modules/vnet/
├── main.tf          # resources + terraform {required_providers}
├── variables.tf     # typed, described, validated inputs
├── outputs.tf       # everything a caller may need (ids, names)
├── README.md        # generated with terraform-docs
├── examples/basic/  # runnable example (also used by tests)
└── tests/           # terraform test files (Module 11)
```

### 1.3 Module design rules (20 years of lessons)

| Do | Don't |
|---|---|
| Wrap a **logical unit** (a network, an app platform) | Wrap a single resource with no added value |
| Use secure defaults (TLS 1.2, private, encrypted) | Expose every possible argument |
| Give inputs types, descriptions, and validation | Use `type = any` |
| Output IDs and names for composition | Hard-code subscription IDs or regions |
| Declare `required_providers` with a minimum version | Put `provider {}` blocks in a child module |
| Keep it flat: root → modules (at most 2 levels) | Build deep module-in-module-in-module chains |

### 1.4 Module sources

```hcl
module "a" { source = "./modules/vnet" }                                       # local path
module "b" { source = "git::https://github.com/org/tf-modules.git//vnet?ref=v1.4.0" }   # Git tag
module "c" { source = "git::ssh://git@ssh.dev.azure.com/v3/org/proj/repo//vnet?ref=v1.4.0" } # Azure Repos
module "d" {                                                                   # public registry
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "~> 0.23"
}
module "e" {                                                                   # private registry (HCP Terraform)
  source  = "app.terraform.io/my-org/vnet/azurerm"
  version = "1.4.0"
}
```

> `version` works only with registry sources. For Git, **pin `?ref=` to a tag or commit SHA**, never a branch.

### 1.5 Providers and modules

* Child modules **inherit** the default provider configuration.
* For multiple subscriptions, pass aliased providers explicitly:

```hcl
provider "azurerm" {
  alias           = "hub"
  subscription_id = var.hub_subscription_id
  features {}
}

module "hub_network" {
  source    = "./modules/vnet"
  providers = { azurerm = azurerm.hub }
}
```

### 1.6 Azure Verified Modules (AVM)

[AVM](https://azure.github.io/Azure-Verified-Modules/) are Microsoft-owned, supported modules that follow one specification.

* **Resource modules** (`avm-res-*`): one resource plus its extras (locks, RBAC, diagnostics, private endpoints)
* **Pattern modules** (`avm-ptn-*`): multi-resource architectures (hub-and-spoke, ALZ)
* Common interface: `lock`, `role_assignments`, `diagnostic_settings`, `private_endpoints`, `tags`, `enable_telemetry`

| Use AVM when | Write your own when |
|---|---|
| You want supported, well-tested building blocks | You need a company-opinionated wrapper (naming, tags, policies) |
| Speed matters more than control | The AVM interface is too generic for your teams |

> **Best of both:** write thin internal modules that *wrap* AVM modules and add company defaults.

---

## 2. Lab 7.1 — Build two reusable modules

**Reference solution:** [labs/lab07-modules](labs/lab07-modules/)

Target layout in `~/tf-labs/lab07`:

```text
lab07/
├── modules/
│   ├── vnet/              (main.tf, variables.tf, outputs.tf, README.md)
│   └── storage-account/   (main.tf, variables.tf, outputs.tf)
└── root/
    └── main.tf
```

### Step 1 — The `vnet` module

Turn your Lab 05.2 code into a module:

1. Move the VNet, subnet, NSG, and association resources into `modules/vnet/main.tf`. Add a `terraform { required_providers {...} }` block **without** a `provider` block.
2. Replace every hard-coded value with a variable: `name`, `location`, `resource_group_name`, `address_space`, `dns_servers`, `subnets`, `tags`.
3. Let the caller pass `address_prefixes` directly (`list(string)`), and add `create_nsg = optional(bool, true)`.
4. Create NSGs only for subnets with `create_nsg = true`:

```hcl
resource "azurerm_network_security_group" "this" {
  for_each = { for k, v in var.subnets : k => v if v.create_nsg }
  # ...
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each                  = azurerm_network_security_group.this    # iterate over another resource's instances
  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = each.value.id
}
```

5. Outputs: `id`, `name`, `subnet_ids` (map), `nsg_ids` (map).

Compare with [modules/vnet](labs/lab07-modules/modules/vnet/).

### Step 2 — The `storage-account` module (secure by default)

Requirements:

* TLS 1.2, no public blobs, versioning, blob and container soft delete (`soft_delete_days`, default 7)
* `containers` (list) creates private containers
* `allowed_subnet_ids` / `allowed_ip_ranges`: if either is non-empty, the firewall default is `Deny`
* A `lifecycle { precondition {...} }` that validates the name (3–24 lowercase letters and digits)
* Outputs: `id`, `name`, `primary_blob_endpoint`, `container_ids`

### Step 3 — Root module: composition + `for_each` on a module

```hcl
module "network" {
  source = "../modules/vnet"
  # ...
}

module "storage" {
  source   = "../modules/storage-account"
  for_each = local.storage_accounts          # one module instance per workload

  name               = "st${var.student}${each.key}${random_string.suffix.result}"
  containers         = each.value.containers
  allowed_subnet_ids = [module.network.subnet_ids["app"]]   # composition: output → input
  # ...
}

output "storage_endpoints" {
  value = { for k, m in module.storage : k => m.primary_blob_endpoint }
}
```

### Step 4 — Deploy

```bash
cd root
terraform init           # note "Initializing modules..."
terraform apply -var="student=dg"
terraform state list     # module.network.azurerm_subnet.this["web"], module.storage["app"]...
```

### Step 5 — Refactor into a module without destroying anything

You have Lab 05 resources at the root (`azurerm_subnet.this`). Moving them into a module changes their addresses. Use `moved` blocks:

```hcl
moved {
  from = azurerm_virtual_network.main
  to   = module.network.azurerm_virtual_network.this
}
moved {
  from = azurerm_subnet.this
  to   = module.network.azurerm_subnet.this      # moves every instance at once
}
```

---

## 3. Lab 7.2 — Version and publish a module through Git (40 min)

1. Create a GitHub or Azure Repos repo `tf-module-azure-vnet` and push `modules/vnet` to its root.
2. Tag a release:

   ```bash
   git tag -a v1.0.0 -m "Initial release" && git push origin v1.0.0
   ```

3. Consume it:

   ```hcl
   module "network" {
     source = "git::https://github.com/<you>/tf-module-azure-vnet.git?ref=v1.0.0"
     # ...
   }
   ```

4. Add a new **optional** input (`ddos_protection_plan_id`, default `null`), then tag `v1.1.0` (minor: backward compatible).
5. Rename an input and tag `v2.0.0` (major: breaking). Show how consumers stay on `v1.x` until they are ready.

**Semantic versioning for modules:**

| Change | Bump |
|---|---|
| Bug fix, no interface change | PATCH `1.0.1` |
| New optional input or output | MINOR `1.1.0` |
| Removed or renamed input, changed default behaviour, resource address changes without `moved` | MAJOR `2.0.0` |

Generate docs: `terraform-docs markdown table --output-file README.md --output-mode inject .`

---

## 4. Lab 7.3 — Use an Azure Verified Module (40 min)

**Reference solution:** [labs/lab07-avm](labs/lab07-avm/)

> **Requires Terraform `>= 1.12`.** The AVM VNet module's input validations rely on short-circuit `||` evaluation, which arrived in Terraform 1.12. On 1.11, `terraform init` fails with `var.ipam_pools is null`, even though the module itself declares `>= 1.9`. **Lesson:** a declared `required_version` is a claim, not a guarantee. Test upgrades.

```hcl
module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "~> 0.23"

  name          = "vnet-${var.student}-avm"
  location      = azurerm_resource_group.main.location
  parent_id     = azurerm_resource_group.main.id      # AVM uses the RG *ID*, not its name
  address_space = ["10.40.0.0/16"]

  subnets = {
    web = {
      name                   = "snet-web"
      address_prefixes       = ["10.40.1.0/24"]
      network_security_group = { id = azurerm_network_security_group.web.id }
    }
  }

  enable_telemetry = false
}
```

Tasks:

1. Open the module's registry page. Find the **Inputs**, **Outputs**, and **Examples** tabs.
2. Note that this AVM module uses the `azapi` provider internally. Add it to `required_providers`.
3. Run `terraform init`, then look inside `.terraform/modules/vnet/`. Reading other people's module code is a key skill.
4. Add a `lock = { kind = "CanNotDelete" }` input and plan. One line gives you a resource lock.
5. **Discussion:** compare your `vnet` module with AVM on lines of code, features, and maintenance burden.

---

## 5. Clean up

```bash
terraform destroy -var="student=dg"     # in root/ and lab07-avm/
```

---


## 🏭 In production

* **Thin company wrappers around AVM** give you Microsoft-maintained resources plus your naming, tagging and security defaults.
* **Every module release has:** a CHANGELOG entry, a SemVer tag, passing tests, a generated README, and an upgrade note for majors.
* **Consumers pin minor versions** (`~> 1.4`) and receive updates through Renovate/Dependabot PRs.
* **Don't build "god modules"** with 80 variables. Compose small modules in the root instead.


## 🎓 Exam corner

1. **True or false:** A child module can read the root module's variables directly. → **False** (inputs and outputs only).
2. Which source types support the `version` argument? → **Registry** sources only.
3. How do you reference output `vnet_id` from module `network`? → `module.network.vnet_id`.
4. What must you run after adding a new module block? → `terraform init` (or `terraform get`).
5. **Choose two** valid module sources: `./modules/vnet` / `git::https://...?ref=v1.0.0` / `module://vnet` / `C++ library` → **local path, Git with ref.**

## 6. Knowledge check

1. Why shouldn't a child module contain a `provider` block?
2. How do you deploy the same module into two subscriptions?
3. What's wrong with `source = "git::https://...git?ref=main"`?
4. How do you move a root resource into a module without recreating it?
5. Can a module output be used as a `for_each` key in another module?

<details><summary>Answers</summary>

1. It prevents callers from using `for_each`, `count`, or `depends_on` on the module, and from passing their own provider configuration. It also makes removing the module difficult.
2. Configure two aliased `azurerm` providers with different `subscription_id`s and pass them with `providers = { azurerm = azurerm.x }`.
3. `main` moves, so builds are not reproducible. Pin to a tag or commit SHA.
4. With a `moved` block from `azurerm_x.name` to `module.<name>.azurerm_x.name`.
5. Only if the value is known at plan time (for example, names from variables). IDs that are "known after apply" cannot be keys.
</details>
