# ADR 0001 — State and environment strategy

* **Status:** Accepted
* **Date:** 2026-11-16
* **Deciders:** Platform Engineering

## Context
The landing zone has a hub, N spokes and workloads, deployed to dev and prod. We need isolated blast
radius, separate access for dev and prod pipelines, and a promotion path that applies the same code everywhere.

## Options considered
1. **CLI workspaces** (one backend, `terraform workspace select prod`). Rejected: shared credentials and backend,
   and it is easy to run in the wrong workspace.
2. **One codebase, per-environment tfvars + partial backend config** (`env/<env>.tfvars`, `env/<env>.backend.hcl`).
3. **Directory per environment** calling versioned modules.
4. **HCP Terraform workspaces** per environment (see Module 15).

## Decision
Option 2 for this repository: one root module with per-environment variable files and backend files, and
**separate state keys and separate pipeline identities** per environment. Option 4 is the target once the
organisation adopts HCP Terraform.

## Consequences
* Every `init` must use `-reconfigure -backend-config=env/<env>.backend.hcl` (wrapped in the pipeline).
* Environment differences live **only** in tfvars, never in scattered conditionals.
* Prod-only protections (resource lock, retention, SKUs) are driven by `var.environment` and covered by `terraform test`.
