# Module 08 — Compute & PaaS Workloads

**Duration:** 2.5 hours (30 min theory · 2h labs) · **Level:** Intermediate
**Exam objectives:** 4b, 4f

> 📋 **Ticket PLAT-108** — The catalog team needs a Linux web tier and the payments team an App Service that reads Blob Storage. Security says: no passwords, no keys, no connection strings.

## Learning objectives

- Deploy a Linux VM with SSH keys, cloud-init, a managed identity, and auto-shutdown
- Understand why **provisioners are a last resort**, and the alternatives (cloud-init, extensions, images, configuration management)
- Deploy an App Service (Linux) with Application Insights, diagnostic settings, and identity-based access to storage
- Use managed identities and RBAC instead of connection strings and keys
- Size per environment with lookup maps

---

## 1. Concepts

### 1.1 VM building blocks in Azure

```text
Resource Group
├── VNet / Subnet ── NSG
├── Public IP (Standard, static) ── NIC ── VM ── OS disk (managed)
│                                         ├── identity (SystemAssigned / UserAssigned)
│                                         ├── custom_data (cloud-init)
│                                         └── boot diagnostics
└── Auto-shutdown schedule
```

`azurerm_linux_virtual_machine` / `azurerm_windows_virtual_machine` replace the legacy `azurerm_virtual_machine`. Don't use the legacy resource in new code.

### 1.2 Configuring the OS: preference order

| Option | When | Notes |
|---|---|---|
| **Golden image** (Packer + Azure Compute Gallery) | Production fleets | Fast boot, immutable |
| **cloud-init** (`custom_data`) | Linux bootstrap | Runs once on first boot |
| **VM extensions** (`azurerm_virtual_machine_extension`) | Agents (AMA, Defender), CustomScript | Managed by Azure |
| Ansible / DSC / Chef | Ongoing configuration | Separate tool, run after Terraform |
| **Provisioners** (`remote-exec`, `local-exec`) | Last resort | Not in the plan, not idempotent, need network access, and failure taints the resource |

```hcl
# Shown only so you can recognise it. Avoid this pattern.
resource "terraform_data" "bootstrap" {
  triggers_replace = [azurerm_linux_virtual_machine.vm.id]
  provisioner "local-exec" {
    command = "echo VM ${azurerm_linux_virtual_machine.vm.name} created >> deployments.log"
  }
}
```

### 1.3 Managed identities

| Type | Lifecycle | Use |
|---|---|---|
| System-assigned | Tied to the resource; deleted with it | One app, one identity |
| User-assigned (`azurerm_user_assigned_identity`) | Independent | Shared by many resources, or needed **before** the resource exists (for example, Key Vault access at boot) |

Pattern: **identity + `azurerm_role_assignment` + no secrets in app settings.**

### 1.4 App Service resources (azurerm v4)

| Resource | Purpose |
|---|---|
| `azurerm_service_plan` | Compute (SKU, OS) |
| `azurerm_linux_web_app` / `azurerm_windows_web_app` | The app |
| `azurerm_linux_web_app_slot` | Deployment slots (staging) |
| `azurerm_linux_function_app` | Functions |
| `azurerm_app_service_virtual_network_swift_connection` | VNet integration |

---

## 2. Lab 8.1 — Linux web server with cloud-init

**Reference solution:** [labs/lab08-linux-vm](labs/lab08-linux-vm/)

### Step 1 — Create an SSH key (if you don't have one)

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

### Step 2 — Write the cloud-init template (`cloud-init.tftpl`)

```yaml
#cloud-config
hostname: ${hostname}
package_update: true
packages:
%{ for p in packages ~}
  - ${p}
%{ endfor ~}
write_files:
  - path: /var/www/html/index.html
    permissions: "0644"
    content: |
      <html><body><h1>Hello from ${hostname}</h1><p>Deployed by Terraform for ${owner}</p></body></html>
runcmd:
  - systemctl enable --now nginx
```

### Step 3 — The VM (key parts)

```hcl
resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "vm-${local.name}"
  size                  = var.vm_size                     # Standard_B2s
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.vm.id]
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.tftpl", {
    hostname = "web01"
    owner    = var.student
    packages = ["nginx", "jq"]
  }))

  identity { type = "SystemAssigned" }
  boot_diagnostics {}
}
```

Copy the network, NIC, public IP, and auto-shutdown parts from the reference solution, or write them yourself using what you learned in Module 04.

> Find image values with: `az vm image list --publisher Canonical --offer ubuntu-24_04-lts --all -o table | head`

### Step 4 — Deploy and test

```bash
terraform init
terraform apply -var="student=dg" -var="admin_source_ip=$(curl -s ifconfig.me)"
curl $(terraform output -raw website_url)          # wait 1-2 min for cloud-init
$(terraform output -raw ssh_command)               # then: sudo cloud-init status --long
```

### Step 5 — Experiments

1. Change a value in the cloud-init template (for example, the `<h1>` text) and plan. Why does the VM get **replaced**? (`custom_data` forces a new resource.) Discuss `lifecycle { ignore_changes = [custom_data] }` and its trade-offs.
2. Change `vm_size` to `Standard_B1ms`. Is it in-place? (Yes: the VM is deallocated and resized, so expect downtime.)
3. Try `vm_size = "Standard_D4s_v5"`. The variable validation blocks it.
4. Mark the VM tainted manually: `terraform taint` is deprecated, so use `terraform apply -replace=azurerm_linux_virtual_machine.vm`.

### Step 6 — Challenge: scale out

Convert the single VM into a **VM Scale Set** (`azurerm_linux_virtual_machine_scale_set`) with 2 instances behind a Standard Load Balancer (`azurerm_lb`, backend pool, health probe on port 80, LB rule). Point the browser at the LB IP and refresh: the hostname should alternate. (Hint: put `$(hostname)` in the page through `runcmd`.)

---

## 3. Lab 8.2 — App Service with monitoring and managed identity

**Reference solution:** [labs/lab08-app-service](labs/lab08-app-service/)

### Architecture

```text
rg-dg-web-dev
├── log-dg-web-dev     (Log Analytics)  ◀── diagnostic settings ── app
├── appi-dg-web-dev    (App Insights, workspace-based)
├── asp-dg-web-dev     (Plan: B1 in dev, P0v3 in prod via lookup map)
├── app-dg-web-dev-xx  (Linux Web App, Node 20, HTTPS only, SystemAssigned identity)
└── stdgwebxxxxx       (Storage, shared keys DISABLED)
        └── role: Storage Blob Data Reader → app identity
```

### Key techniques to type and understand

**Environment-based sizing**

```hcl
locals {
  sku = { dev = "B1", prod = "P0v3" }
}
sku_name = lookup(local.sku, var.environment, "B1")
```

**Secret-free access**

```hcl
resource "azurerm_role_assignment" "app_blob_reader" {
  scope                = azurerm_storage_account.app.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}
```

**Shared keys disabled** means the provider must use Entra ID for storage data-plane calls:

```hcl
provider "azurerm" {
  features {}
  storage_use_azuread = true
}
```

**Diagnostic settings**

```hcl
resource "azurerm_monitor_diagnostic_setting" "app" {
  target_resource_id         = azurerm_linux_web_app.app.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.app.id
  enabled_log { category = "AppServiceHTTPLogs" }
  enabled_metric { category = "AllMetrics" }
}
```

> Find the valid log categories for any resource: `az monitor diagnostic-settings categories list --resource <id> -o table`

### Deploy and verify

```bash
terraform apply -var="student=dg"
curl -I $(terraform output -raw app_url)
az role assignment list --assignee $(terraform output -raw app_principal_id) --all -o table
```

Plan with `-var="environment=prod"` (don't apply). Note the plan SKU change and `always_on = true`.

### Challenge

1. Add a **staging slot** (`azurerm_linux_web_app_slot`) and a slot swap using `azurerm_web_app_active_slot`.
2. Add **VNet integration**: a subnet delegated to `Microsoft.Web/serverFarms` + `virtual_network_subnet_id` on the web app.

---

## 4. Clean up

```bash
terraform destroy -var="student=dg" -var="admin_source_ip=1.1.1.1"   # lab08-linux-vm
terraform destroy -var="student=dg"                                  # lab08-app-service
```

---


## 🏭 In production

* **Golden images (Packer) + cloud-init** for VMs. Configuration drift inside VMs is not Terraform's job (use Ansible, DSC or Azure Machine Configuration).
* **Identity first:** a managed identity plus an RBAC role is the default design review answer. Connection strings need an exception.
* **Every resource sends diagnostics** to the central Log Analytics workspace, usually enforced by a `DeployIfNotExists` policy.
* **Auto-shutdown and small SKUs in dev,** with sizes driven by a per-environment lookup map so prod sizing is reviewed in one place.


## 🎓 Exam corner

1. **True or false:** Provisioners are the recommended way to configure VMs. → **False** (last resort).
2. Which meta-argument handles a dependency Terraform can't see through references? → `depends_on`.
3. What does `self` refer to in a postcondition? → The resource's own attributes.

## 5. Knowledge check

1. Why is `cloud-init` better than `remote-exec`?
2. What happens to a VM when `custom_data` changes?
3. System-assigned or user-assigned identity: which one do you need if a VM must read Key Vault during its first boot?
4. How does an App Service read a storage blob without a connection string?
5. Why must `storage_use_azuread = true` be set when `shared_access_key_enabled = false`?

<details><summary>Answers</summary>

1. cloud-init runs inside the VM at boot, needs no inbound SSH from the Terraform runner, and its failure doesn't taint the resource. `remote-exec` is outside the plan and fragile.
2. The VM is replaced (destroyed and re-created).
3. User-assigned. You can grant its role **before** the VM exists, so there's no race at boot.
4. A managed identity plus a data-plane RBAC role (Storage Blob Data Reader), using `DefaultAzureCredential` in the app SDK.
5. The provider would otherwise use the account keys to read blob and queue properties, and those calls fail with 403.
</details>
