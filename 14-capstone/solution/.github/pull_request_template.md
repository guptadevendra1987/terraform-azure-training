## Ticket
PLAT-___

## What & why
<!-- One paragraph. Link the ADR if this changes a design decision. -->

## Plan summary (paste from the CI comment)
| Environment | Add | Change | Destroy |
|---|---|---|---|
| dev  | | | |
| prod | | | |

## Review checklist
- [ ] Every `destroy` / `-/+ replace` is explained below (data stores replaced = do not merge)
- [ ] No unexpected changes to resources this PR does not touch (drift?)
- [ ] No secrets in code, tfvars, outputs or plan
- [ ] fmt / validate / tflint / checkov / terraform test all green
- [ ] Cost impact reviewed
- [ ] Naming and tagging standards followed

## Risk & rollback
- Risk: low / medium / high, because ...
- Rollback: `git revert` of this PR + pipeline apply (data restore needed? yes/no)
