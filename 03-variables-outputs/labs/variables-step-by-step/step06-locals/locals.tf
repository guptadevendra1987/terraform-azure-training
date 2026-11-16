# A local is a NAMED CALCULATION inside your configuration.
#
#   variable = the customer's ORDER         (comes from outside, the caller can change it)
#   local    = the kitchen's PREPARATION    (worked out inside, nobody outside can change it)
#   output   = the DISH served              (what you hand back)
#
# Use locals to: avoid repeating the same expression, build names and tags once,
# and give a complicated expression a readable name.

locals {
  # "Payments API" → "payments-api"
  app_slug = replace(lower(var.app_name), " ", "-")

  # Built ONCE, used by every resource
  name_prefix = "${local.app_slug}-${var.environment}"

  is_prod = var.environment == "prod"

  # Company tags are merged LAST, so a team can't override them
  tags = merge(var.extra_tags, {
    app         = local.app_slug
    environment = var.environment
    managed_by  = "terraform"
  })
}
