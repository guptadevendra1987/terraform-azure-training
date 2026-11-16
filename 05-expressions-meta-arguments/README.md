# Module 05 — Loops, Expressions & Functions (Made Simple)

**Duration:** 4 hours + 1 hour Day 2 challenge · **Level:** Beginner → Intermediate
**Exam objectives:** 4d (complex types), 4e (expressions and functions), 4b (references)

> 📋 **Ticket PLAT-105** — Adding a subnet currently means copying 40 lines of HCL. The network and security teams want to send you a YAML/JSON/CSV file instead. Make the network data-driven.

## Learning objectives

- Know **which loop to use when**: `count`, `for_each`, `for` expressions, or `dynamic` blocks
- Explain why `for_each` is safer than `count` for named things, and prove it with a plan
- Transform lists and maps with `for` expressions, filters, and grouping
- Flatten nested data (VNets → subnets, apps → environments) into something `for_each` can use
- Solve real platform tasks with built-in functions: naming, tagging, CSV/JSON/YAML input, IP planning, templates, validation
- Build an Azure network entirely from data

> **How this module works:** Parts A and B run **without Azure**, using Terraform's built-in `terraform_data` resource. They give instant results and cost nothing. Part C applies the same ideas to real Azure resources.

---

## Part A — Loops, one step at a time (2 hours)

### A.1 The mental model

There are four kinds of "loop" in Terraform, and they do different jobs:

| I want to… | Use | Analogy | Creates resources? |
|---|---|---|---|
| Make **N identical copies**, or switch something **on/off** | `count` | A **photocopier**: copies are numbered 0, 1, 2… | ✅ |
| Make **one copy per named item** | `for_each` | A wall of **lockers with name tags** | ✅ |
| **Transform data** (lists ↔ maps, filter, rename) | `for` expression | An **Excel formula** dragged down a column | ❌ (data only) |
| Repeat a **nested block inside** one resource | `dynamic` block | `for_each`, but for the blocks inside a resource | ❌ (repeats blocks) |

### A.2 Which one should I use?

```text
Do you need several RESOURCES (or modules)?
├── No: do you need several NESTED BLOCKS inside one resource (rules, ip configs)?
│        ├── Yes ──▶ dynamic block
│        └── No  ──▶ you are reshaping data ──▶ for expression
└── Yes: is it just "0 or 1" (a feature flag)?
         ├── Yes ──▶ count = var.enabled ? 1 : 0
         └── No: does each item have a NAME / identity?
                  ├── Yes ──▶ for_each   ◀── the answer 90% of the time in production
                  └── No (truly identical copies) ──▶ count
```

### A.3 The ladder: 8 small steps

All in [labs/loops-step-by-step](labs/loops-step-by-step/). Each folder is a complete, tiny configuration, commented line by line. For every step:

```bash
cd labs/loops-step-by-step/step01-count-basics
terraform init
terraform apply -auto-approve
terraform state list           # SEE how Terraform names each copy
# then do the "TRY THIS" section at the bottom of main.tf
terraform destroy -auto-approve
```

| Step | Concept | What you will SEE |
|---|---|---|
| [01 count basics](labs/loops-step-by-step/step01-count-basics/main.tf) | `count`, `count.index`, splat `[*]` | `web[0]`, `web[1]`, `web[2]`; scale to 5 and back to 2 |
| [02 count as a switch](labs/loops-step-by-step/step02-count-conditional/main.tf) | `condition ? 1 : 0`, `one()`, `try()` | Resources appear and disappear with a flag; safe references |
| [03 the count trap](labs/loops-step-by-step/step03-count-trap/main.tf) | Why indexes are dangerous | Remove 1 item, and the plan **replaces 2 and destroys 3** |
| [04 for_each with a set](labs/loops-step-by-step/step04-for-each-set/main.tf) | `for_each`, `toset`, `each.key` | Same change, and the plan **destroys only 1** |
| [05 for_each with a map](labs/loops-step-by-step/step05-for-each-map/main.tf) | `map(object)`, `each.value`, `optional()` | The production pattern: one map entry = one VM |
| [06 for expressions](labs/loops-step-by-step/step06-for-expressions/main.tf) | `[for …]`, `{for …}`, `if`, group by `...` | Eight transformations of the same data |
| [07 nested data](labs/loops-step-by-step/step07-nested-loops-flatten/main.tf) | `flatten`, `setproduct`, composite keys | VNets × subnets → `"spoke/web"` keys |
| [08 dynamic blocks](labs/loops-step-by-step/step08-dynamic-blocks/main.tf) | `dynamic`, `content`, iterator | One NSG with N rules (Azure `plan` only) |

### A.4 The most important experiment: steps 3 and 4

Both steps manage three storage accounts and then remove the **first** one.

**With `count` (step 3):**

```text
State BEFORE                       Remove "stlogs"           What Terraform plans
storage[0] = stlogs                storage[0] = stimages     storage[0]: stlogs → stimages    REPLACE
storage[1] = stimages      ──▶     storage[1] = stbackups    storage[1]: stimages → stbackups REPLACE
storage[2] = stbackups                                       storage[2]: stbackups            DESTROY

Plan: 2 to add, 0 to change, 3 to destroy        ← you wanted to delete 1, you lose 3 accounts' data
```

**With `for_each` (step 4):**

```text
storage["stlogs"]                                           storage["stlogs"]    DESTROY
storage["stimages"]        ──▶   (keys don't move)   ──▶    storage["stimages"]  no change
storage["stbackups"]                                        storage["stbackups"] no change

Plan: 0 to add, 0 to change, 1 to destroy        ← exactly what you asked for
```

> These plan summaries are **real output** from the lab. Run them yourself and compare.

### A.5 Reading `each` and `count` without confusion

| Inside a resource with… | You can use | Example value |
|---|---|---|
| `count = 3` | `count.index` | `0`, `1`, `2` |
| `for_each = toset(["a","b"])` | `each.key`, `each.value` | both `"a"` |
| `for_each = { web = {size="B2s"} }` | `each.key`, `each.value.size` | `"web"`, `"B2s"` |
| `dynamic "security_rule" { for_each = … }` | `security_rule.key`, `security_rule.value` | index or key, then the item |

| Referencing from outside | `count` resource | `for_each` resource |
|---|---|---|
| One instance | `azurerm_x.this[0]` | `azurerm_x.this["web"]` |
| All IDs as a list | `azurerm_x.this[*].id` | `[for v in azurerm_x.this : v.id]` or `values(azurerm_x.this)[*].id` |
| All IDs as a map | n/a | `{ for k, v in azurerm_x.this : k => v.id }` |

### A.6 The `for` expression syntax, decoded

```text
[ for  s  in  var.list  :  upper(s)          if  s != "" ]
  │    │       │            │                  │
  │    │       │            │                  └── optional filter
  │    │       │            └── what to produce for each item
  │    │       └── what to loop over
  │    └── a name YOU choose for the current item
  └── [ ] makes a LIST      { } makes a MAP (then use  key => value)

{ for  k, v  in  var.map  :  k => v.cidr }
       │  │
       │  └── value
       └── key            (with a list, the two names are index, value)
```

### A.7 Common mistakes (and the error you'll see)

| Mistake | Error message | Fix |
|---|---|---|
| `for_each = ["a", "b"]` (a list) | `The given "for_each" argument value is unsuitable: … a set of strings or a map` | `for_each = toset([...])` |
| `for_each` over IDs created in the same apply | `Invalid for_each argument … known only after apply` | Key by names from variables, not IDs |
| Using `count.index` in a `for_each` resource | `Reference to "count" in non-counted context` | Use `each.key` / `each.value` |
| `azurerm_x.this.id` on a counted resource | `Missing resource instance key` | `azurerm_x.this[0].id` or `[*]` |
| Duplicate keys in `{for …}` | `Duplicate object key` | Make keys unique, or group with `...` |
| Both `count` and `for_each` | `Invalid combination of "count" and "for_each"` | Pick one |

---

## Part B — Functions made simple (1 hour)

### B.1 How to read any function call

```text
cidrsubnet( "10.0.0.0/16" ,  8  ,  2  )   →  "10.0.2.0/24"
   │             │           │     │
   name          input      how many    which one
                 network    extra bits  (0, 1, 2…)
```

Functions only **calculate**. They never create anything. Test every function in `terraform console` before you put it in code:

```bash
terraform console
> upper("payments")
"PAYMENTS"
> exit
```

### B.2 "I want to…" cookbook

| I want to… | Function | Console example → result |
|---|---|---|
| Lowercase a name | `lower` | `lower("Payments-API")` → `"payments-api"` |
| Replace characters | `replace` | `replace("pay api", " ", "-")` → `"pay-api"` |
| Build a string from parts | `format` / `"${}"` | `format("rg-%s-%s", "pay", "prod")` → `"rg-pay-prod"` |
| Cut to a max length | `substr` | `substr("stpaymentsprodcentralindia", 0, 24)` |
| Remove spaces | `trimspace` | `trimspace("  a ")` → `"a"` |
| Join / split | `join`, `split` | `join(",", ["a","b"])` → `"a,b"` |
| Count items | `length` | `length(["a","b"])` → `2` |
| Combine maps (the last one wins) | `merge` | `merge({a=1},{a=2,b=3})` → `{a=2,b=3}` |
| Combine lists | `concat` | `concat(["a"],["b"])` → `["a","b"]` |
| Map lookup with a default | `lookup` | `lookup({dev="B1"}, "prod", "B2")` → `"B2"` |
| First non-empty value | `coalesce` | `coalesce("", "x")` → `"x"` |
| Try, and fall back if it errors | `try` | `try(var.cfg.size, "B1")` |
| Test whether something works | `can` | `can(regex("^[a-z]+$", "abc"))` → `true` |
| Is it in the list? | `contains` | `contains(["dev","prod"], "uat")` → `false` |
| Remove duplicates | `distinct` / `toset` | `distinct(["a","a"])` → `["a"]` |
| Lists of lists → one list | `flatten` | `flatten([["a"],["b","c"]])` → `["a","b","c"]` |
| Two lists → map | `zipmap` | `zipmap(["a","b"],[1,2])` → `{a=1,b=2}` |
| Every combination | `setproduct` | `setproduct(["x"],["1","2"])` → `[["x","1"],["x","2"]]` |
| Optional single item → value or null | `one` | `one([])` → `null` |
| Split a network | `cidrsubnet(s)` | `cidrsubnets("10.0.0.0/16", 8, 8)` → `["10.0.0.0/24","10.0.1.0/24"]` |
| The Nth IP in a subnet | `cidrhost` | `cidrhost("10.0.1.0/24", 4)` → `"10.0.1.4"` |
| Read a file | `file` | `file("${path.module}/x.txt")` |
| Read CSV / JSON / YAML | `csvdecode` / `jsondecode` / `yamldecode` | `jsondecode("{\"a\":1}")` → `{a=1}` |
| Fill in a template | `templatefile` | `templatefile("init.tftpl", {name="web"})` |
| Encode for Azure `custom_data` | `base64encode` | `base64encode("hi")` → `"aGk="` |
| Policy JSON from HCL | `jsonencode` | `jsonencode({a=1})` → `"{\"a\":1}"` |

### B.3 Lab 5.1 — Functions in real production tasks

**Lab:** [labs/functions-real-world](labs/functions-real-world/) (no Azure needed)

The other teams don't write HCL. They send you **files**:

```text
data/vms.csv               ← from the ops team (messy: empty cells, uppercase emails, spaces)
data/firewall-rules.json   ← from the security team (approved rules)
data/app-settings.yaml     ← from the developers (defaults + per-environment overrides)
templates/cloud-init.yaml.tftpl
```

For each of the 8 tasks in `main.tf`: **read the TASK comment, close your eyes, and name the functions you would use**. Then read the solution, apply, and check the output.

| Task | Real-world ask | Key functions | Result (prod) |
|---|---|---|---|
| 1 | Company naming convention | `lower` `replace` `format` `substr` `lookup` | `rg-payments-api-prod-cin`, `stpaymentsapiprodcin001` |
| 2 | Mandatory tags nobody can override | `merge` (order matters!) | `owner = "payments-team"` wins |
| 3 | Build VMs from the ops team's CSV, cleaning bad data | `csvdecode` `coalesce` `tonumber` `trimspace` `lower` | 4 prod VMs; empty zone defaults to 1 |
| 4 | Security team JSON → one NSG rule per source, unique priorities | `jsondecode` `flatten` `format` `merge` | priorities 100, 110, 120, 130 |
| 5 | IP plan for a new spoke | `cidrsubnets` `zipmap` `cidrhost` | web `10.42.0.0/24` … aks `10.42.16.0/20` |
| 6 | Per-environment app settings with defaults | `yamldecode` `merge` `try` `contains` | prod: 3 replicas, fraud-detection on |
| 7 | Generate cloud-init for a VM | `templatefile` `jsonencode` `base64encode` | Ready-to-use `custom_data` |
| 8 | Reject dangerous input | `alltrue` `can` `cidrhost` `contains` | `0.0.0.0/0` is rejected |

```bash
cd labs/functions-real-world
terraform init && terraform apply -auto-approve
terraform plan -var="environment=dev"                 # CSV filter: only app02 is dev
terraform plan -var='allowed_admin_cidrs=["0.0.0.0/0"]'   # TASK 8 rejects it
terraform console
> local.subnet_cidrs
> local.fw_rules_flat
> local.raw_vms[3]                                    # see the raw CSV row with empty cells
```

**Extension exercises:**

1. Add a `storage_accounts.csv` and create one `terraform_data` per row, with names generated by your Task 1 convention.
2. Add a `uat` environment to the YAML that overrides only `log_level`. Check the merged result in the console.
3. Make Task 1 fail validation if the generated storage name would be shorter than 3 characters.

---
## Part C — Lab 5.2: Data-driven Azure network with for_each, dynamic & count

**Reference solution:** [labs/lab05-dynamic-network](labs/lab05-dynamic-network/)

Now apply Parts A and B to real Azure. Replace the roughly 150 repetitive lines from Module 04 with about 60 data-driven lines.

### Step 1 — Model the network as data (`variables.tf`)

```hcl
variable "student" { type = string }

variable "location" {
  type    = string
  default = "centralindia"
}

variable "address_space" {
  type    = string
  default = "10.20.0.0/16"
}

variable "enable_nat_gateway" {
  type    = bool
  default = false
}

variable "subnets" {
  description = "Subnets keyed by name. newbits/netnum feed cidrsubnet()."
  type = map(object({
    newbits           = optional(number, 8)
    netnum            = number
    service_endpoints = optional(list(string), [])
    nat_gateway       = optional(bool, false)
    nsg_rules = optional(list(object({
      name                   = string
      priority               = number
      direction              = optional(string, "Inbound")
      access                 = optional(string, "Allow")
      protocol               = optional(string, "Tcp")
      destination_port_range = string
      source_address_prefix  = string
    })), [])
  }))

  default = {
    web = {
      netnum = 1
      nsg_rules = [
        { name = "allow-https", priority = 100, destination_port_range = "443", source_address_prefix = "Internet" },
        { name = "allow-http", priority = 110, destination_port_range = "80", source_address_prefix = "Internet" },
      ]
    }
    app = {
      netnum      = 2
      nat_gateway = true
      nsg_rules = [
        { name = "allow-web", priority = 100, destination_port_range = "8080", source_address_prefix = "10.20.1.0/24" },
      ]
    }
    data = {
      netnum            = 3
      service_endpoints = ["Microsoft.Sql", "Microsoft.Storage"]
      nsg_rules = [
        { name = "allow-app-sql", priority = 100, destination_port_range = "1433", source_address_prefix = "10.20.2.0/24" },
      ]
    }
  }

  validation {
    condition     = alltrue(flatten([for s in var.subnets : [for r in s.nsg_rules : r.priority >= 100 && r.priority <= 4096]]))
    error_message = "NSG rule priorities must be between 100 and 4096."
  }
}
```

### Step 2 — Resources with `for_each` and `dynamic` (`main.tf`)

```hcl
locals {
  tags = { course = "tf-azure-training", owner = var.student }
}

resource "azurerm_resource_group" "net" {
  name     = "rg-${var.student}-net05"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.student}-net05"
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name
  address_space       = [var.address_space]
  tags                = local.tags
}

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                 = "snet-${each.key}"
  resource_group_name  = azurerm_resource_group.net.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.address_space, each.value.newbits, each.value.netnum)]
  service_endpoints    = each.value.service_endpoints
}

resource "azurerm_network_security_group" "this" {
  for_each = var.subnets

  name                = "nsg-${var.student}-${each.key}"
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name
  tags                = local.tags

  dynamic "security_rule" {
    for_each = each.value.nsg_rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = "*"
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = var.subnets

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}
```

### Step 3 — Conditional NAT gateway with `count`

```hcl
resource "azurerm_public_ip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  name                = "pip-${var.student}-nat"
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway" "this" {
  count = var.enable_nat_gateway ? 1 : 0

  name                = "ng-${var.student}-net05"
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name
  sku_name            = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  count = var.enable_nat_gateway ? 1 : 0

  nat_gateway_id       = azurerm_nat_gateway.this[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

# Combine a condition with a for expression: only subnets flagged nat_gateway = true
resource "azurerm_subnet_nat_gateway_association" "this" {
  for_each = var.enable_nat_gateway ? { for k, v in var.subnets : k => v if v.nat_gateway } : {}

  subnet_id      = azurerm_subnet.this[each.key].id
  nat_gateway_id = azurerm_nat_gateway.this[0].id
}
```

### Step 4 — Outputs with for expressions

```hcl
output "subnet_ids" {
  value = { for k, s in azurerm_subnet.this : k => s.id }
}

output "subnet_cidrs" {
  value = { for k, s in azurerm_subnet.this : k => one(s.address_prefixes) }
}

output "nat_public_ip" {
  value = one(azurerm_public_ip.nat[*].ip_address) # null when disabled
}

output "all_nsg_rules" {
  value = flatten([
    for subnet, cfg in var.subnets : [
      for r in cfg.nsg_rules : "${subnet}/${r.name}:${r.destination_port_range}"
    ]
  ])
}
```

### Step 5 — Deploy and experiment

```bash
terraform init
terraform apply -var="student=dg"
terraform state list                       # notice azurerm_subnet.this["web"] style addresses
```

1. **Add a subnet** `mgmt = { netnum = 10 }` in a tfvars file and plan. Only the new resources are added.
2. **Remove `web`** and plan. Only web's subnet, NSG, and association are destroyed. Compare this with the count trap from §1.3.
3. **Enable NAT**: `-var="enable_nat_gateway=true"`. Only the `app` subnet gets associated.
4. **Add an NSG rule** to `data`. The dynamic block updates the NSG in place.

### Step 6 — The count trap (demo, 10 min)

In a scratch folder, create 3 resource groups with `count` over a list, apply, then remove the first element and plan. Count the replacements. Then refactor to `for_each` and use a `moved` block (previewed here, covered in depth in Module 06):

```hcl
moved {
  from = azurerm_resource_group.rg[1]
  to   = azurerm_resource_group.rg["app"]
}
```

### Clean up

```bash
terraform destroy -var="student=dg"
```

---

## Part D — Day 2 Challenge Lab — Network from YAML (1 hour)

**Reference solution:** [labs/day2-challenge-yaml-network](labs/day2-challenge-yaml-network/)

The network team doesn't want to write HCL. They maintain a `network.yaml` file:

```yaml
vnets:
  hub:
    address_space: 10.100.0.0/16
    subnets:
      AzureFirewallSubnet: { cidr: 10.100.0.0/26 }
      shared:              { cidr: 10.100.1.0/24, rules: [ { name: allow-ssh-from-corp, priority: 100, port: "22", source: 203.0.113.0/24 } ] }
  spoke1:
    address_space: 10.101.0.0/16
    subnets:
      web: { cidr: 10.101.1.0/24, rules: [ { name: allow-https, priority: 100, port: "443", source: Internet } ] }
      app: { cidr: 10.101.2.0/24 }
```

**Requirements**

1. Read the file with `yamldecode(file(...))`.
2. Create one VNet per key, and one subnet per subnet entry (hint: `flatten` into a map keyed `"vnet/subnet"`).
3. Create an NSG **only** for subnets that have `rules`, and **never** for `AzureFirewallSubnet`.
4. Peer every spoke to the hub, in both directions (hint: filter `k != "hub"`).
5. Output a map `"vnet/subnet" => cidr`.
6. Adding a spoke to the YAML must require **zero** HCL changes.

---

## 🏭 In production

* **Data in files, logic in HCL.** Real teams keep subnets, firewall rules, and VM lists in YAML/JSON/CSV owned by the relevant team, reviewed through pull requests, and read with `yamldecode`/`jsondecode`/`csvdecode`. Adding a subnet becomes a one-line data change.
* **`for_each` keys are forever.** A key is part of the resource address in state. Changing keys later (`"web"` → `"frontend"`) means a `moved` block for every instance. Choose stable, meaningful keys from day one.
* **Never key by something that changes:** display names that marketing may rename, list positions, or computed IDs.
* **Keep loops readable.** If a `for` expression needs a comment longer than itself, move it into a named `local` with a descriptive name.
* **Plan review habit:** for any loop change, check that the number of adds/destroys in the plan matches the number of items you changed. A mismatch is the count trap.

---

## 🎓 Exam corner (Terraform Associate 004: objectives 4d, 4e)

1. **True or false:** `for_each` accepts a list of strings directly. → **False** (a map or a set of strings; use `toset()`).
2. A variable is `type = map(string)` with `{ dev = "B1", prod = "P1v3" }`. Which expression returns `"P1v3"`? → `var.sizes["prod"]` (also `var.sizes.prod`). Not `var.sizes[1]`, because maps have no index.
3. Which expression produces a **list**: `[for s in var.x : s]` or `{for s in var.x : s => s}`? → The square brackets.
4. **Choose two:** which are complex types? `object`, `string`, `tuple`, `bool`, `number` → **object, tuple** (plus `list`, `map`, `set`).
5. What does `lookup(var.m, "k", "d")` return when `"k"` is missing? → `"d"`.
6. Which meta-argument creates exactly zero or one instance based on a condition? → `count = cond ? 1 : 0`.

---

## Knowledge check

1. Why can removing an item from the middle of a `count` list be destructive?
2. Can you use `count` and `for_each` on the same resource?
3. How do you reference all IDs of a `for_each` resource as a list?
4. What does `one()` return for an empty list, and when is it useful?
5. Why should you avoid `timestamp()` in resource arguments?
6. What's the difference between a `for` expression and `for_each`?

<details><summary>Answers</summary>

1. Instances are addressed by index. Removing one shifts the indexes, so every later instance is planned for update or replacement.
2. No. They are mutually exclusive.
3. `values(azurerm_x.this)[*].id` or `[for v in azurerm_x.this : v.id]`.
4. `null`. It safely references a conditionally created (`count`) resource.
5. The value changes on every plan, so you get a perpetual diff.
6. A `for` expression only transforms data (it creates nothing). `for_each` is a meta-argument that creates one resource or module instance per item.
</details>
