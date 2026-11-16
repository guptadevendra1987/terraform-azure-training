# Module 15 — HCP Terraform (Terraform Cloud)

**Duration:** 2 hours (40 min theory · 1h20 labs) · **Level:** Intermediate → Advanced
**Exam objectives:** 8a, 8b, 8c, 8d (plus 6c, remote state, and 2d)

> HCP Terraform (formerly *Terraform Cloud*) is HashiCorp's managed service for running Terraform: remote state, remote runs, a private registry, policy, and team governance. It is **one full exam objective (8)**. The free tier is enough for every lab here. Check the current plan limits on the HashiCorp pricing page.

> 📋 **Ticket PLAT-115** — Leadership approved HCP Terraform. Migrate a stack, set up projects, teams and secretless Azure credentials as code, and turn on policy and drift detection.

## Learning objectives

- Explain what HCP Terraform adds to the CLI: remote operations, state, VCS integration, governance
- Connect a configuration with `terraform login` and the `cloud` block, and migrate existing state
- Organise work with **organizations → projects → workspaces**, variables, and **variable sets**
- Choose between the **CLI-driven, VCS-driven, and API-driven** workflows
- Use **dynamic provider credentials** (OIDC to Azure, no secrets), **run triggers**, and workspace outputs
- Describe the governance features: teams and permissions, policies (Sentinel/OPA), health assessments (drift detection and continuous validation), the private registry, Explorer, and change requests
- Manage HCP Terraform itself as code with the `tfe` provider

---

## 1. Concepts

### 1.1 What changes when you move to HCP Terraform

| Concern | Terraform CLI + azurerm backend (Modules 06, 12) | HCP Terraform |
|---|---|---|
| State storage and locking | Azure Storage blob + lease | Managed, versioned, locked, encrypted |
| Where plan/apply run | Your laptop or a CI runner | **Remote** on HCP (or your own agents) |
| Secrets for providers | Pipeline secrets / OIDC | Workspace **sensitive variables** or **dynamic credentials** |
| Approvals | Pipeline environments | Run confirmation, team permissions |
| Policy | Checkov/OPA in CI | **Policy sets** (Sentinel or OPA) run between plan and apply |
| Drift detection | A scheduled workflow you build | **Health assessments** built in |
| Module sharing | Git tags | **Private registry** |

### 1.2 Hierarchy

```text
Organization (billing, SSO, teams, policy sets, private registry, variable sets)
└── Project  "payments"           ← permissions and variable sets can be scoped here
    ├── Workspace  payments-network-prod   (its own state, variables, runs, settings)
    └── Workspace  payments-app-prod       ← run trigger from network
```

> **Exam trap:** an *HCP Terraform workspace* is **not** the same thing as a *CLI workspace* (`terraform workspace new`). An HCP workspace is a full unit with its own state, variables, permissions, and run history. Typically you have one per stack per environment.

### 1.3 The three workflows

| Workflow | How runs start | Use for |
|---|---|---|
| **CLI-driven** | `terraform plan/apply` on your machine, executed remotely, with output streamed back | Migration, local iteration with remote state and secrets |
| **VCS-driven** | A push or PR to a connected repo. PRs get **speculative plans** (plan-only), and a merge to the branch triggers plan + apply | The standard GitOps flow for teams |
| **API-driven** | Your pipeline uploads a configuration version through the API | Custom CI/CD integrations |

### 1.4 Connecting: `terraform login` + the `cloud` block

```bash
terraform login              # opens the browser, creates a user API token,
                             # saves it in ~/.terraform.d/credentials.tfrc.json (Windows: %APPDATA%\terraform.d\)
```

```hcl
terraform {
  cloud {
    organization = "contoso-platform"
    workspaces {
      name    = "payments-network-dev"     # one workspace
      project = "payments"
      # or: tags = ["payments", "dev"]     # select among several workspaces with: terraform workspace select
    }
  }
}
```

* The `cloud` block **replaces** a `backend` block. You can't have both. The older `backend "remote"` still works but is legacy.
* Changing from `backend "azurerm"` to `cloud` and running `terraform init` **offers to migrate** the existing state.
* `TF_CLOUD_ORGANIZATION`, `TF_WORKSPACE`, and `TF_CLOUD_PROJECT` environment variables can replace hard-coded values.

### 1.5 Variables and variable sets

| Type | Category | Example |
|---|---|---|
| Terraform variable | `terraform` | `student = "dg"` (fills `variable "student"`) |
| Environment variable | `env` | `ARM_SUBSCRIPTION_ID`, `TFC_AZURE_PROVIDER_AUTH` |
| Sensitive flag | either | Write-only in the UI/API, and never shown again |

**Variable sets** share variables across many workspaces. They can be global (the whole organization), assigned to a **project**, or assigned to individual workspaces. If the same key is defined at more than one level, the more specific one wins (workspace beats variable set). Within variable sets, priority sets can be configured to override workspace values.

### 1.6 Dynamic provider credentials (OIDC to Azure)

```text
HCP run (plan phase) ──▶ issues a JWT: sub = organization:ORG:project:PROJ:workspace:WS:run_phase:plan
                     ──▶ Entra ID matches a federated credential on the app registration
                     ──▶ short-lived Azure token ──▶ azurerm provider. No client secret is stored anywhere.
```

Workspace environment variables: `TFC_AZURE_PROVIDER_AUTH=true` and `TFC_AZURE_RUN_CLIENT_ID=<app client id>` (optionally separate plan/apply identities: `TFC_AZURE_PLAN_CLIENT_ID` / `TFC_AZURE_APPLY_CLIENT_ID`), plus `ARM_SUBSCRIPTION_ID` and `ARM_TENANT_ID`.

### 1.7 Governance and collaboration features (objective 8b)

| Feature | What it does |
|---|---|
| **Teams and permissions** | Organization-, project-, and workspace-level access: read, plan, write, admin (plus custom). SSO/SAML on paid tiers |
| **Policy sets** (Sentinel or OPA) | Evaluated after plan, before apply. Enforcement levels: *advisory* (warn), *soft-mandatory* (can be overridden by authorised users), *hard-mandatory* (blocks) |
| **Run tasks** | Call external tools (cost, security scanners) during a run |
| **Cost estimation** | Shows the monthly cost delta in the run |
| **Health assessments** | Scheduled **drift detection** and **continuous validation** (re-evaluates `check` blocks and conditions) |
| **Private registry** | Publish internal modules and providers with versions |
| **Explorer** | Organization-wide view of workspaces, providers, modules, Terraform versions, and drift |
| **Change requests** | Track required follow-up changes on workspaces (for example, "upgrade the provider") |
| **Run triggers** | Queue a run in workspace B when workspace A applies successfully |
| **Agents** | Run Terraform inside your private network (for private endpoints, on-premises) |
| **Workspace Terraform version** | Set per workspace, and upgrade deliberately in the workspace settings |

---

## 2. Lab 15.1 — CLI-driven workflow and state migration (30 min)

**Reference solution:** [labs/lab15-cloud-block](labs/lab15-cloud-block/)

### Step 1 — Create an account and organization

Sign up at [app.terraform.io](https://app.terraform.io) and create an organization, for example `contoso-<initials>`.

### Step 2 — Log in from the CLI

```bash
terraform login
# Token for app.terraform.io: ****  → Retrieved token for user <you>
```

### Step 3 — Start locally, then migrate

```bash
mkdir ~/tf-labs/lab15 && cd ~/tf-labs/lab15
cp <course>/15-hcp-terraform/labs/lab15-cloud-block/main.tf .
# 1. Comment out the cloud { } block. Apply locally first so you have local state:
terraform init && terraform apply -var="student=dg"
# 2. Uncomment the cloud block and set your organization, then:
terraform init
# "Do you wish to proceed? ... migrate your existing state to HCP Terraform"  → yes
```

Open the workspace in the browser and look at **States**: your local state is now there. Delete the local `terraform.tfstate*` files.

### Step 4 — Make the remote run work

The plan now runs on HCP Terraform's machines, so your `az login` **doesn't apply** there. Configure the workspace:

* **Variables** → Terraform variable `student = dg`
* Azure credentials: either the dynamic credentials from Lab 15.2 (recommended), or, for a quick test only, env variables `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET` (sensitive), `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`

```bash
terraform plan        # streams: "Running plan in HCP Terraform. Output will stream here..."
terraform apply       # the confirmation happens in your terminal, and the run also shows in the UI
```

### Step 5 — Observe

* **Runs** tab: every plan and apply with its logs, who triggered it, and duration
* **States** tab: versions with diffs (roll back by downloading a previous version)
* **Settings → Locking**: lock the workspace manually and try `terraform plan`
* **Settings → General**: execution mode (Remote / Local / Agent), Terraform version, auto-apply

---

## 3. Lab 15.2 — HCP Terraform as code with the `tfe` provider (40 min)

**Reference solution:** [labs/lab15-hcp-as-code](labs/lab15-hcp-as-code/)

Platform teams don't click through the UI for 200 workspaces. They manage HCP Terraform **with Terraform**. This one configuration creates:

```text
Project  tf-azure-training-dg
├── Workspace dg-network-dev   (auto-apply, optional VCS-driven)
│        │  run trigger
│        ▼
├── Workspace dg-app-dev       (manual confirmation)
├── Variable set (project-scoped): location, student,
│        TFC_AZURE_PROVIDER_AUTH, TFC_AZURE_RUN_CLIENT_ID, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID
├── Team dg-app-developers → "write" on the project
└── Policy set (Sentinel): every resource group must have an owner tag (soft-mandatory)

Entra ID: app registration + 4 federated credentials (network/app × plan/apply) + Contributor role
```

```bash
cd labs/lab15-hcp-as-code
export TFE_TOKEN=<an org owner or team token>        # or rely on `terraform login`
terraform init
terraform apply -var="organization=<org>" -var="student=dg"
```

Look at the federated credential subjects in the Entra ID portal (`organization:<org>:project:tf-azure-training-dg:workspace:dg-network-dev:run_phase:plan`), and compare them with the GitHub subjects in Module 12.

> **Policy sets** and some team features depend on your HCP Terraform plan. If the apply reports a feature as unavailable, remove those resources and treat them as a reading exercise.

### Test the setup

1. Point the Lab 15.1 configuration at `dg-network-dev` (update the `cloud` block), add an output `subnet_ids`, and apply. Use **only** the dynamic credentials this time, with no `ARM_CLIENT_SECRET`.
2. Watch **dg-app-dev** get a run queued automatically (the run trigger).
3. Remove the `owner` tag in the configuration and plan. The **policy check** fails as soft-mandatory, and a user with permission can override it.

---

## 4. Lab 15.3 — Consume another workspace's outputs (10 min)

**Reference solution:** [labs/lab15-consumer-outputs](labs/lab15-consumer-outputs/)

```hcl
data "tfe_outputs" "network" {                 # preferred: output read access only
  organization = "contoso-dg"
  workspace    = "dg-network-dev"
}
# data.tfe_outputs.network.values.subnet_ids   (values are marked sensitive)

data "terraform_remote_state" "network" {      # classic, and still on the exam
  backend = "remote"
  config = {
    organization = "contoso-dg"
    workspaces   = { name = "dg-network-dev" }
  }
}
```

---

## 5. Lab 15.4 — VCS-driven workflow (demo, 15 min)

1. **Organization settings → Providers → VCS providers → GitHub**: connect it, and note the **OAuth token ID**.
2. Re-apply Lab 15.2 with `-var="github_repo=<you>/tf-azure-cicd-demo" -var="github_oauth_token_id=ot-..."`.
3. Open a PR that changes `infra/network`. HCP Terraform posts a **speculative plan** status check on the PR.
4. Merge. A run starts automatically and auto-applies (because `auto_apply = true` on network), then the run trigger queues **app**.

---

## 6. Clean up

```bash
# In the lab15-cloud-block workspace:
terraform destroy -var="student=dg"
# Then remove HCP objects and the Entra app:
cd labs/lab15-hcp-as-code && terraform destroy -var="organization=<org>" -var="student=dg"
```

---

## 🏭 In production

* **Workspace = stack × environment** (`payments-network-prod`). Never one giant workspace.
* **Projects map to teams or business units**. Grant team access at the project level so new workspaces inherit it.
* **Variable sets for shared settings** (tenant, subscription IDs, tags). Dynamic credentials everywhere, and no static cloud secrets in workspaces.
* **The platform team owns the `tfe` configuration** ("workspace vending"): a new app team gets its project, workspaces, team, and credentials through a pull request.
* **Policies start as advisory**, move to soft-mandatory, then hard-mandatory, once teams have had time to comply.
* **Pin `terraform_version`** per workspace, and upgrade deliberately (use Explorer to find stragglers).

---

## 🎓 Exam corner (objective 8)

1. **True or false:** The `cloud` block and a `backend` block can be used together. → **False.**
2. Where does `terraform login` store the API token by default? → `credentials.tfrc.json` in the user's Terraform config directory.
3. Which workflow gives pull requests a speculative plan automatically? → **VCS-driven.**
4. **Choose two:** features that help govern changes before apply: policy sets / run triggers / cost estimation / workspace tags / the private registry → **policy sets, cost estimation** (both evaluate the plan before apply).
5. Which enforcement level can an authorised user override? → **soft-mandatory.**
6. What connects workspaces so that an apply in one queues a run in another? → **Run triggers.**
7. How do you share variables with all workspaces in a project? → A **variable set** scoped to the project.
8. What does a health assessment detect? → **Drift** and failing **continuous validation** checks (`check` blocks and conditions).
9. **True or false:** In remote execution mode, `terraform plan` on your laptop runs the plan on HCP Terraform and streams the output. → **True.**
10. Which feature lets runs reach resources on a private network? → **HCP Terraform agents.**

---

## Knowledge check

1. What's the difference between a CLI workspace and an HCP Terraform workspace?
2. Your plan works locally but fails in HCP Terraform with "unable to build authorizer". Why?
3. Why prefer `tfe_outputs` over `terraform_remote_state` for cross-workspace data?
4. How would you onboard 20 new application teams to HCP Terraform in a repeatable way?

<details><summary>Answers</summary>

1. A CLI workspace is just another state file for the same configuration and backend. An HCP workspace is a full unit with its own state, variables, permissions, settings, VCS connection, and run history.
2. The run executes remotely, where your `az login` doesn't exist. Configure dynamic credentials (or env vars) on the workspace.
3. It needs only permission to read outputs, not the whole state, which may contain secrets.
4. A platform-owned `tfe` configuration (workspace vending) driven by a map of teams: one project per team, standard workspaces, a team, project access, variable sets, dynamic credentials, and policy sets, all created through a pull request.
</details>
