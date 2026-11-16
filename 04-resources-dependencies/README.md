# Module 04 — Resources, Dependencies, Data Sources & Lifecycle

**Duration:** 3 hours (50 min theory · 2h10 labs) · **Level:** Intermediate
**Exam objectives:** 4a, 4b, 4f

> 📋 **Ticket PLAT-104** — The payments application needs a three-tier network (web/app/data) with least-privilege NSGs. The network team also wants other stacks to *read* this network without owning it.

## Learning objectives

- Build an Azure network: VNet, subnets, NSG, rules, and associations
- Understand **implicit** and **explicit** dependencies and how the graph drives parallelism
- Read existing infrastructure with **data sources**
- Control resource behaviour with the `lifecycle` block: `prevent_destroy`, `ignore_changes`, `create_before_destroy`, and `replace_triggered_by`
- Choose between inline nested blocks and separate association resources

---

## 1. Concepts

### 1.1 Dependencies

```hcl
# IMPLICIT: Terraform sees the reference and orders the operations automatically (preferred)
resource "azurerm_subnet" "web" {
  virtual_network_name = azurerm_virtual_network.main.name   # ← creates a graph edge
}

# EXPLICIT: only when there's a hidden dependency that Terraform cannot see
resource "azurerm_linux_virtual_machine" "app" {
  depends_on = [azurerm_role_assignment.kv_reader]   # the VM's startup script reads Key Vault
}
```

* Terraform runs independent resources **in parallel** (default `-parallelism=10`).
* Destroy happens in **reverse** dependency order.
* Overusing `depends_on` slows plans and can cause unnecessary "known after apply" values. Use it sparingly.

### 1.2 Data sources

Data sources **read** existing objects. They are not managed, so Terraform never creates or deletes them.

```hcl
data "azurerm_client_config" "current" {}            # who am I? tenant_id, object_id, subscription_id
data "azurerm_subscription" "current" {}
data "azurerm_resource_group" "shared" { name = "rg-shared-network" }
data "azurerm_virtual_network" "hub" {
  name                = "vnet-hub"
  resource_group_name = "rg-shared-network"
}
```

Typical uses: referencing shared infrastructure owned by another team, looking up the current tenant or user, and fetching the latest image or a Key Vault secret.

### 1.3 Inline blocks compared with separate resources

Many Azure resources can be configured two ways. **Never mix them for the same object**, because the two will fight each other on every apply.

| Inline | Separate resource (recommended) |
|---|---|
| `security_rule {}` inside `azurerm_network_security_group` | `azurerm_network_security_rule` |
| `subnet {}` inside `azurerm_virtual_network` | `azurerm_subnet` |

Separate resources are easier to add with `for_each`, have smaller blast radius, and can be owned by different teams.

### 1.4 The lifecycle meta-argument

```hcl
lifecycle {
  prevent_destroy       = true                          # plan fails if this resource would be destroyed
  create_before_destroy = true                          # new one first, then delete the old (zero downtime)
  ignore_changes        = [tags["CreatedOn"], tags]     # don't fight external changes to these
  replace_triggered_by  = [azurerm_key_vault_secret.cert.version]  # replace when another object changes
}
```

| Use case | Setting |
|---|---|
| Production database or Key Vault must never be deleted by accident | `prevent_destroy` |
| Azure Policy adds tags, or autoscale changes the instance count | `ignore_changes` |
| Replacing a public IP or certificate without downtime | `create_before_destroy` |
| Restart a VM or container when its config changes | `replace_triggered_by` |

### 1.5 Useful built-in resources

* `terraform_data`: a generic resource that holds values or triggers replacement. It replaces `null_resource`.
* `time_sleep` (from the `hashicorp/time` provider): waits for eventual consistency, for example after an RBAC assignment.

---

## 2. Lab 4.1 — Three-tier network

**Reference solution:** [labs/lab04-network](labs/lab04-network/)

### Target architecture

```text
  rg-<student>-net-dev
  └── vnet-<student>-dev  10.10.0.0/16
      ├── snet-web   10.10.1.0/24   ← nsg-web  (allow 80/443 from Internet, 22 from your IP)
      ├── snet-app   10.10.2.0/24   ← nsg-app  (allow 8080 from snet-web only)
      └── snet-data  10.10.3.0/24   ← nsg-data (allow 1433 from snet-app only)
  └── pip-<student>-web (Standard, static)
```

### Step 1 — Providers and variables

Reuse `providers.tf` from Module 03. `variables.tf`:

```hcl
variable "student"     { type = string }
variable "location"    {
  type    = string
  default = "centralindia"
}
variable "environment" {
  type    = string
  default = "dev"
}
variable "address_space" {
  type    = string
  default = "10.10.0.0/16"
}
variable "admin_source_ip" {
  type        = string
  description = "Your public IP for SSH (find it: curl ifconfig.me)."
}
```

> `curl -s ifconfig.me` (bash) or `(Invoke-RestMethod ifconfig.me)` (PowerShell) prints your public IP.

### Step 2 — Data sources and locals (`main.tf`)

```hcl
data "azurerm_client_config" "current" {}

locals {
  suffix = "${var.student}-${var.environment}"
  tags = {
    course      = "tf-azure-training"
    owner       = var.student
    environment = var.environment
    deployed_by = data.azurerm_client_config.current.object_id
  }
}

resource "azurerm_resource_group" "net" {
  name     = "rg-${var.student}-net-${var.environment}"
  location = var.location
  tags     = local.tags
}
```

### Step 3 — VNet and subnets

```hcl
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.suffix}"
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name
  address_space       = [var.address_space]
  tags                = local.tags
}

resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.net.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.address_space, 8, 1)]   # 10.10.1.0/24
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.net.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.address_space, 8, 2)]   # 10.10.2.0/24
}

resource "azurerm_subnet" "data" {
  name                 = "snet-data"
  resource_group_name  = azurerm_resource_group.net.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.address_space, 8, 3)]   # 10.10.3.0/24
  service_endpoints    = ["Microsoft.Sql", "Microsoft.Storage"]
}
```

> Try it in `terraform console`: `cidrsubnet("10.10.0.0/16", 8, 1)` returns `"10.10.1.0/24"`.

### Step 4 — NSGs and rules (separate resources)

```hcl
resource "azurerm_network_security_group" "web" {
  name                = "nsg-${local.suffix}-web"
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name
  tags                = local.tags
}

resource "azurerm_network_security_rule" "web_http" {
  name                        = "Allow-HTTP-HTTPS-Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.net.name
  network_security_group_name = azurerm_network_security_group.web.name
}

resource "azurerm_network_security_rule" "web_ssh" {
  name                        = "Allow-SSH-From-Admin"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.admin_source_ip
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.net.name
  network_security_group_name = azurerm_network_security_group.web.name
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}
```

Now **write the app and data NSGs yourself**:

* `nsg-…-app` allows TCP 8080 from `azurerm_subnet.web.address_prefixes[0]`
* `nsg-…-data` allows TCP 1433 from `azurerm_subnet.app.address_prefixes[0]`
* Associate each with its subnet

(Feeling repetitive? Good. Module 05 replaces all of this with one `for_each`.)

### Step 5 — Public IP with lifecycle rules

```hcl
resource "azurerm_public_ip" "web" {
  name                = "pip-${local.suffix}-web"
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.tags

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [tags["created_on"]]
  }
}
```

### Step 6 — Outputs

```hcl
output "vnet_id"    { value = azurerm_virtual_network.main.id }
output "subnet_ids" {
  value = {
    web  = azurerm_subnet.web.id
    app  = azurerm_subnet.app.id
    data = azurerm_subnet.data.id
  }
}
output "public_ip"  { value = azurerm_public_ip.web.ip_address }
```

### Step 7 — Deploy and watch the parallelism

```bash
terraform init
terraform apply -var="student=dg" -var="admin_source_ip=$(curl -s ifconfig.me)"
```

Watch the output: the three subnets are created **at the same time**, and the NSG associations wait for both the subnet and the NSG.

```bash
terraform graph | grep -v "meta" > graph.dot     # visualise it
az network vnet subnet list -g rg-dg-net-dev --vnet-name vnet-dg-dev -o table
az network nsg rule list -g rg-dg-net-dev --nsg-name nsg-dg-dev-web -o table
```

---

## 3. Lab 4.2 — Lifecycle experiments (40 min)

Do each experiment, observe the result, then revert.

**A. prevent_destroy**

```hcl
resource "azurerm_virtual_network" "main" {
  # ...
  lifecycle { prevent_destroy = true }
}
```

Run `terraform destroy`. Read the error: `Instance cannot be destroyed`. Remove the lifecycle block afterwards.

**B. ignore_changes against external tagging**

```bash
az network public-ip update -g rg-dg-net-dev -n pip-dg-dev-web --set tags.created_on=2026-01-01
terraform plan     # no change, because the tag is ignored
az network public-ip update -g rg-dg-net-dev -n pip-dg-dev-web --set tags.team=ops
terraform plan     # Terraform wants to remove "team"
```

**C. create_before_destroy**

Change the public IP's `zones` to `["1"]` and apply. Watch the order: create the new IP, then destroy the old one. Why must the name differ? (Hint: Azure names are unique within a resource group. Use a `random_id` suffix or `name_prefix`-style patterns.) **Expect an error**, and discuss how to fix it.

**D. replace_triggered_by**

```hcl
resource "terraform_data" "nsg_version" {
  input = "v1"
}

resource "azurerm_network_security_group" "web" {
  # ...
  lifecycle {
    replace_triggered_by = [terraform_data.nsg_version]
  }
}
```

Change `"v1"` to `"v2"` and plan. The NSG is marked for replacement.

---

## 4. Lab 4.3 — Data sources: consume shared infrastructure (20 min)

Pretend another team owns the network. In a **new folder** `lab04-consumer`:

```hcl
data "azurerm_virtual_network" "shared" {
  name                = "vnet-dg-dev"
  resource_group_name = "rg-dg-net-dev"
}

data "azurerm_subnet" "app" {
  name                 = "snet-app"
  virtual_network_name = data.azurerm_virtual_network.shared.name
  resource_group_name  = data.azurerm_virtual_network.shared.resource_group_name
}

output "app_subnet_id"   { value = data.azurerm_subnet.app.id }
output "vnet_dns"        { value = data.azurerm_virtual_network.shared.dns_servers }
```

Run `terraform apply`. Data sources appear as `<= read` in the plan, and nothing is created.

---

## 5. Clean up

```bash
terraform destroy -var="student=dg" -var="admin_source_ip=1.1.1.1"
```

---


## 🏭 In production

* **Separate rule resources beat inline blocks** once more than one team touches an NSG.
* **Read, don't own:** consume shared infrastructure through data sources. The network team keeps ownership, and you keep a small blast radius.
* **`prevent_destroy` on data stores** (databases, storage with data, Key Vaults) in prod stacks.
* **`ignore_changes` is a scalpel, not a hammer.** Ignore only attributes another system legitimately owns (tags added by policy, autoscale instance counts), and leave a comment explaining why.


## 🎓 Exam corner

1. **True or false:** A `data` block can create resources if they don't exist. → **False.**
2. How do you reference a data source attribute? → `data.<TYPE>.<NAME>.<ATTRIBUTE>`.
3. Which dependency type does Terraform infer from references? → **Implicit.**
4. Which lifecycle argument makes plan fail if a resource would be destroyed? → `prevent_destroy`.
5. **Choose two** valid uses of `-target`: routine deployments / recovering from errors / working around a provider bug in an emergency / speeding up every CI run → **recovering from errors, emergency workaround** (it is for exceptional cases).

## 6. Knowledge check

1. When do you need `depends_on`?
2. What happens if you define `security_rule {}` inline **and** `azurerm_network_security_rule` for the same NSG?
3. What does `ignore_changes = all` do, and when is it dangerous?
4. A data source refers to a resource group that doesn't exist yet. What happens during plan?
5. What does `cidrsubnet("10.0.0.0/16", 4, 2)` return?

<details><summary>Answers</summary>

1. Only when a dependency is not visible through references. Examples are RBAC propagation, or a VM extension that needs a firewall rule which it doesn't reference.
2. A perpetual diff. Each apply removes the rules that the other method created.
3. Terraform ignores every argument after creation. It is dangerous because real config changes are silently ignored.
4. Plan fails, because data sources are read during plan (unless they depend on values only known after apply).
5. `10.0.32.0/20` (4 new bits give /20, and the 3rd network of that size starts at offset 2 × 16 = 32).
</details>
