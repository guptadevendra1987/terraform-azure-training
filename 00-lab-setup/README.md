# Module 00 — Lab Environment Setup

**Duration:** complete before Day 1 (about 45 minutes) · **Type:** pre-work

By the end of this module, each student has:

- [ ] Terraform CLI (>= 1.9)
- [ ] Azure CLI (>= 2.60), logged in to the training subscription
- [ ] VS Code with the HashiCorp Terraform extension
- [ ] Git
- [ ] (Optional, used on Days 4–5) TFLint, Checkov, and the Azure Export for Terraform tool (`aztfexport`)
- [ ] A budget alert on the subscription
- [ ] A passing result from `scripts/check-prereqs.ps1` or `scripts/check-prereqs.sh`

---

## 1. Azure subscription options

| Option | Good for | Notes |
|---|---|---|
| **Azure Free Account** (USD 200 credit for 30 days) | Individual learners | Some VM SKUs and regions are limited by quota |
| **Visual Studio / MSDN subscription** | Corporate learners | Monthly credit, Owner rights |
| **Shared corporate training subscription** | Classroom delivery | The trainer gives each student **Contributor** + **User Access Administrator** (needed for Module 10 RBAC labs). Students are isolated by the `student` variable |

> **Trainer note:** for a classroom, create one subscription and one Entra ID security group `sg-tf-training-students`, then assign it *Contributor* and *User Access Administrator* at subscription scope. Remove the group after the course.

---

## 2. Install the tools

### Windows (PowerShell as Administrator)

```powershell
winget install --id Hashicorp.Terraform -e
winget install --id Microsoft.AzureCLI -e
winget install --id Microsoft.VisualStudioCode -e
winget install --id Git.Git -e

# Optional (Days 4-5)
winget install --id TerraformLinters.tflint -e
pip install checkov
winget install --id Microsoft.Azure.AztfExport -e
```

Close and reopen the terminal so the PATH change takes effect.

### macOS (Homebrew)

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform azure-cli git tflint checkov aztfexport
brew install --cask visual-studio-code
```

### Linux (Ubuntu/Debian)

```bash
# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform git

# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# TFLint + Checkov (optional)
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
pip install checkov
```

### No local install? Use Azure Cloud Shell

[https://shell.azure.com](https://shell.azure.com) already has Terraform, the Azure CLI, and Git, and you are logged in automatically. Use the built-in `code` editor. This works for every lab except the VS Code-specific tips.

### Version manager (recommended for professionals)

Real projects pin different Terraform versions. Use **tfenv** (Linux/macOS) or **tfswitch**:

```bash
tfswitch 1.17.2        # or: tfenv install 1.17.2 && tfenv use 1.17.2
```

---

## 3. Configure VS Code

Install these extensions:

| Extension | Why |
|---|---|
| **HashiCorp Terraform** (`hashicorp.terraform`) | Syntax highlighting, IntelliSense, format on save |
| **Azure Account / Azure Resources** | Browse what you deployed |
| **GitLens** (optional) | Git history |

Add to your VS Code `settings.json`:

```json
{
  "[terraform]": {
    "editor.defaultFormatter": "hashicorp.terraform",
    "editor.formatOnSave": true
  },
  "[terraform-vars]": {
    "editor.defaultFormatter": "hashicorp.terraform",
    "editor.formatOnSave": true
  }
}
```

---

## 4. Log in to Azure

```bash
az login                                   # opens a browser
az account list -o table                   # list subscriptions
az account set --subscription "<SUBSCRIPTION_ID_OR_NAME>"
az account show -o table                   # confirm the active subscription
```

Terraform's AzureRM provider **v4** requires a subscription ID. Export it once per terminal session:

```powershell
# PowerShell
$env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)
```

```bash
# bash/zsh
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

> Tip: add the export line to your PowerShell `$PROFILE` or `~/.bashrc` for the duration of the course.

### Authentication methods you will use in this course

> New to service principals, roles and scopes? Module 02 explains them with diagrams: open [02-azure-first-deployment/visual-guide.html](../02-azure-first-deployment/visual-guide.html) in your browser.

| Method | Where | Module |
|---|---|---|
| Azure CLI (`az login`) | Your laptop | 01–11 |
| Service principal + client secret | Legacy CI systems (demonstrated, not recommended) | 02 |
| Managed identity | Self-hosted runners / VMs in Azure | 12 |
| **OIDC workload identity federation** | GitHub Actions / Azure DevOps (no secrets) | 12 |

---

## 5. Register resource providers (one-time per subscription)

New subscriptions sometimes lack providers that the labs need:

```bash
for ns in Microsoft.Network Microsoft.Compute Microsoft.Storage Microsoft.KeyVault \
          Microsoft.Web Microsoft.OperationalInsights Microsoft.Insights Microsoft.ManagedIdentity; do
  az provider register --namespace $ns
done
```

---

## 6. Create a cost budget alert

```bash
SUB_ID=$(az account show --query id -o tsv)
az consumption budget create \
  --budget-name tf-training-budget \
  --amount 20 --category cost --time-grain monthly \
  --start-date $(date +%Y-%m-01) --end-date 2027-12-31 \
  --notifications '{"Actual_GreaterThan_80_Percent":{"enabled":true,"operator":"GreaterThan","threshold":80,"contactEmails":["you@example.com"]}}' \
  --scope "/subscriptions/$SUB_ID"
```

(You can also do this in the Portal: **Cost Management → Budgets → Add**.)

---

## 7. Verify your setup

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File .\00-lab-setup\scripts\check-prereqs.ps1
```

```bash
# macOS / Linux / Cloud Shell
bash ./00-lab-setup/scripts/check-prereqs.sh
```

Expected output (the versions may be newer):

```
[OK]   terraform   1.17.2
[OK]   az          2.67.0
[OK]   git         2.47.0
[OK]   Azure login: Training-Sub (xxxxxxxx-....)
[OK]   ARM_SUBSCRIPTION_ID is set
[WARN] tflint not found (needed on Day 5)
```

---

## 8. Helper scripts in this folder

| Script | Purpose | Used in |
|---|---|---|
| [scripts/check-prereqs.ps1](scripts/check-prereqs.ps1) / [.sh](scripts/check-prereqs.sh) | Verify tools and Azure login | Setup |
| [scripts/bootstrap-backend.ps1](scripts/bootstrap-backend.ps1) / [.sh](scripts/bootstrap-backend.sh) | Create the storage account for remote state | Module 06 onward |
| [scripts/cleanup.ps1](scripts/cleanup.ps1) / [.sh](scripts/cleanup.sh) | Delete every resource group tagged `course=tf-azure-training` (optionally only yours) | End of each day |

---

## 9. Working folder

Create a personal folder **outside** this repo where you type the labs:

```bash
mkdir -p ~/tf-labs && cd ~/tf-labs
```

Keep this repository open in a second VS Code window as the reference.
