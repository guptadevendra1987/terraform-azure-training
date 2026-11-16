# Troubleshooting Guide

How to approach any Terraform error:

1. **Read the whole message**, especially the `with <address>` and `on <file> line N` lines.
2. Ask which phase failed: **init** (providers or backend), **validate/plan** (config, types, data sources), or **apply** (the Azure API).
3. For apply errors, the Azure error code (`AuthorizationFailed`, `SkuNotAvailable`…) is the real message. Search for it.
4. Still stuck? `TF_LOG=DEBUG` shows the raw HTTP calls to ARM.

---

## Init errors

| Error | Cause | Fix |
|---|---|---|
| `Failed to query available provider packages` | Network, proxy, or a version constraint that can't be met | Check `HTTPS_PROXY`; relax the constraint; `terraform init -upgrade` |
| `the cached package ... does not match any of the checksums recorded in the dependency lock file` | Lock file created on another OS | `terraform providers lock -platform=windows_amd64 -platform=linux_amd64 -platform=darwin_arm64` |
| `Backend configuration changed` | You switched backend config | `-reconfigure` (new backend) or `-migrate-state` (move state) |
| `Error acquiring the state lock` | Another run is in progress, or a crashed run | Wait, or `terraform force-unlock <ID>` after confirming nobody is running |
| `AuthorizationPermissionMismatch` on the state blob | Missing **Storage Blob Data Contributor**, or role propagation | Assign the role and wait 1–2 minutes |
| `Module not installed` | A new module was added | `terraform init` |

## Plan and validate errors

| Error | Cause | Fix |
|---|---|---|
| `Reference to undeclared resource` | Typo or missing resource | Check the address |
| `Invalid count argument` / `Invalid for_each argument ... known only after apply` | The key or count depends on an attribute created at apply | Use values known at plan time (variables, names, booleans); split into two applies only as a last resort |
| `Unsupported attribute` | Wrong attribute name, or a list/map indexing mistake | Check the provider docs; use `[0]` or `one()` for blocks |
| `Inconsistent conditional result types` | Two branches return different types | Make both branches the same type (`tolist`, `tomap`, an empty `{}` vs `[]`) |
| `Cycle: ...` | Two resources reference each other | Break the cycle with a separate association resource |
| `subscription ID could not be determined` | azurerm v4 needs it | `ARM_SUBSCRIPTION_ID` or `subscription_id` |
| Perpetual diff on every plan | Inline vs separate resources fighting; `timestamp()`; Azure normalising values (case, JSON order) | Pick one style; use `time_static`; match Azure's format; `ignore_changes` as a last resort |

## Apply errors (Azure API)

| Azure error | Cause | Fix |
|---|---|---|
| `AuthorizationFailed` | Your identity lacks the role at that scope | `az role assignment list --assignee <id> --all` |
| `MissingSubscriptionRegistration` | Resource provider not registered | `az provider register -n Microsoft.X` |
| `StorageAccountAlreadyTaken` / `VaultAlreadyExists` / web app name taken | Globally unique name | Random suffix; for a soft-deleted Key Vault, purge it or use a new name |
| `SkuNotAvailable` / `QuotaExceeded` | Region capacity or subscription quota | Another size or region; request quota |
| `RequestDisallowedByPolicy` | Azure Policy deny | Read the policy name in the error; comply or request an exemption |
| `ScopeLocked` | Resource lock | Remove the lock through code (or a privileged admin) |
| `A resource with the ID ... already exists - to be managed via Terraform this resource needs to be imported` | Exists in Azure but not in state | `import` block, or rename |
| `AnotherOperationInProgress` / `RetryableError` | Azure is busy with the same resource (common with subnets and peering) | Re-run apply |
| `403` on Key Vault secret or storage data | RBAC propagation, firewall, or shared keys disabled | `time_sleep`, network rules, `storage_use_azuread = true` |
| `Subnet ... is in use and cannot be deleted` | NIC or private endpoint still attached outside Terraform | Find it: `az network vnet subnet show ... --query ipConfigurations` |

## State problems

| Situation | Recovery |
|---|---|
| Resource deleted in Azure, still in state | `terraform plan` re-creates it, or `terraform state rm` if it is gone for good |
| Resource in Azure, missing from state | `import` block |
| Wrong address after a refactor | `moved` block |
| State corrupted or overwritten | Blob **versioning** → restore the previous version; or `state push` a backup |
| Partial apply after a crash | Re-run `plan`. Terraform records every resource that completed |

## Useful diagnostics

```bash
TF_LOG=DEBUG TF_LOG_PATH=./debug.log terraform apply
grep -i "x-ms-correlation-request-id\|HTTP/1.1 4" debug.log
az monitor activity-log list --correlation-id <id> -o table
terraform state show 'module.x.azurerm_y.z["key"]'
terraform show -json tfplan | jq '.resource_changes[] | select(.change.actions != ["no-op"]) | {address, actions: .change.actions}'
```
