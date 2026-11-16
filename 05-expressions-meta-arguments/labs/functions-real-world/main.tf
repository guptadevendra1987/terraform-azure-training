# Functions in REAL production tasks. No cloud account needed.
#   terraform init && terraform apply -auto-approve && terraform console
#
# Each section is a task a platform engineer really gets.
# Read the TASK, guess which functions you'd use, then read the solution.

terraform {
  required_version = ">= 1.9"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "workload" {
  type    = string
  default = "Payments API"
}

# =============================================================================
# TASK 1: Naming convention.
# "All names must be lowercase, use '-' instead of spaces, and follow
#  <type>-<workload>-<env>-<region-short>. Storage accounts: no dashes, max 24 chars."
# Functions: lower, replace, format, substr, lookup
# =============================================================================
locals {
  region_short = lookup({ centralindia = "cin", southindia = "sin", westindia = "win" }, "centralindia", "unk")

  workload_slug = replace(lower(trimspace(var.workload)), " ", "-") # "Payments API" → "payments-api"

  names = {
    resource_group = format("rg-%s-%s-%s", local.workload_slug, var.environment, local.region_short)
    key_vault      = substr(format("kv-%s-%s-%s", local.workload_slug, var.environment, local.region_short), 0, 24)
    storage        = substr(replace("st${local.workload_slug}${var.environment}${local.region_short}001", "-", ""), 0, 24)
  }
}

# =============================================================================
# TASK 2: Mandatory tags.
# "Every resource needs company tags; teams may add more but must not override 'owner' or 'cost_center'."
# Functions: merge (LATER maps win, so put the mandatory map LAST)
# =============================================================================
locals {
  team_tags = { owner = "someone-else", project = "checkout", cost_center = "WRONG" }

  mandatory_tags = {
    owner       = "payments-team"
    cost_center = "CC-1042"
    environment = var.environment
    managed_by  = "terraform"
  }

  tags = merge(local.team_tags, local.mandatory_tags) # mandatory wins
}

# =============================================================================
# TASK 3: The ops team sends a CSV of VMs. Build them, cleaning bad data.
# Functions: csvdecode, file, trimspace, lower, coalesce, tonumber, toset
# =============================================================================
locals {
  raw_vms = csvdecode(file("${path.module}/data/vms.csv")) # list of maps; every value is a STRING

  vms = {
    for row in local.raw_vms : row.name => {
      role    = row.role
      size    = row.size
      env     = row.environment
      zone    = tonumber(coalesce(row.zone, "1"))     # empty cell → default zone 1
      disk_gb = tonumber(coalesce(row.disk_gb, "64")) # empty cell → default 64 GB
      owner   = lower(trimspace(row.owner_email))     # "  Priya.Sharma@Contoso.com" → "priya.sharma@contoso.com"
    }
    if row.environment == var.environment # only this environment's VMs
  }

  vm_owners = toset([for vm in local.vms : vm.owner]) # unique owners for alert routing
}

resource "terraform_data" "vm" {
  for_each = local.vms
  input    = "vm-${each.key} (${each.value.size}, zone ${each.value.zone}, ${each.value.disk_gb} GB)"
}

# =============================================================================
# TASK 4: The security team publishes approved firewall rules as JSON.
# "Turn them into one NSG rule per (rule, source) with unique priorities starting at 100."
# Functions: jsondecode, flatten, length, tostring, format
# =============================================================================
locals {
  fw = jsondecode(file("${path.module}/data/firewall-rules.json"))

  fw_rules_flat = flatten([
    for r in local.fw.rules : [
      for s in r.sources : { name = r.name, port = tostring(r.port), source = s }
    ]
  ])

  nsg_rules = {
    for i, r in local.fw_rules_flat : format("%s-%02d", r.name, i) => merge(r, { priority = 100 + i * 10 })
  }
}

# =============================================================================
# TASK 5: Plan the IP addresses for a new spoke.
# "/16 for the spoke: web /24, app /24, data /24, private endpoints /26, AKS /20."
# Functions: cidrsubnets, cidrhost, zipmap
# =============================================================================
locals {
  spoke_cidr   = "10.42.0.0/16"
  subnet_names = ["web", "app", "data", "pe", "aks"]

  # newbits: /16+8=/24, /16+8, /16+8, /16+10=/26, /16+4=/20 (cidrsubnets packs them without overlap)
  subnet_cidrs = zipmap(local.subnet_names, cidrsubnets(local.spoke_cidr, 8, 8, 8, 10, 4))

  app_gateway_private_ip = cidrhost(local.subnet_cidrs["web"], 10) # 10th host in the web subnet
}

# =============================================================================
# TASK 6: Per-environment settings from YAML, with defaults.
# "Each environment overrides only what differs from the defaults."
# Functions: yamldecode, merge, try, contains, join
# =============================================================================
locals {
  app_cfg = yamldecode(file("${path.module}/data/app-settings.yaml"))

  effective_settings = merge(
    local.app_cfg.defaults,
    try(local.app_cfg.environments[var.environment], {}) # unknown env → just defaults
  )

  fraud_detection_on = contains(local.effective_settings.feature_flags, "fraud-detection")
}

# =============================================================================
# TASK 7: Generate a cloud-init file for the VM from a template.
# Functions: templatefile, jsonencode, base64encode (Azure custom_data must be base64)
# =============================================================================
locals {
  cloud_init = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    hostname    = "vm-web01"
    packages    = ["nginx", "jq"]
    config_json = jsonencode(local.effective_settings)
  })

  cloud_init_b64 = base64encode(local.cloud_init) # what you pass to custom_data
}

# =============================================================================
# TASK 8: Validate input defensively.
# Functions: can, regex, alltrue, startswith, length
# =============================================================================
variable "allowed_admin_cidrs" {
  type    = list(string)
  default = ["10.250.0.0/16", "203.0.113.10/32"]

  validation {
    condition     = alltrue([for c in var.allowed_admin_cidrs : can(cidrhost(c, 0))])
    error_message = "Every entry must be a valid CIDR (e.g. 10.0.0.0/16)."
  }

  validation {
    condition     = !contains(var.allowed_admin_cidrs, "0.0.0.0/0")
    error_message = "0.0.0.0/0 is not allowed for admin access (security policy SEC-12)."
  }
}

# ----------------------------------------------------------------------------- outputs

output "task1_names" { value = local.names }
output "task2_tags" { value = local.tags }
output "task3_vms" { value = { for k, v in terraform_data.vm : k => v.output } }
output "task3_owners" { value = local.vm_owners }
output "task4_nsg_rules" { value = local.nsg_rules }
output "task5_subnets" { value = local.subnet_cidrs }
output "task5_appgw_ip" { value = local.app_gateway_private_ip }
output "task6_settings" { value = local.effective_settings }
output "task6_fraud" { value = local.fraud_detection_on }
output "task7_cloud_init" { value = local.cloud_init }
