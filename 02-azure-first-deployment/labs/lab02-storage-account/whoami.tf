# "Who is Terraform right now?" Shows the identity the azurerm provider logged in with.
#   Logged in with az login → client_id = 04b07795-8ddb-461a-bbee-02f9e1bf7b46 (the Azure CLI's own app ID)
#                              object_id = YOUR user's object ID
#   Using a service principal → client_id = the service principal's appId
data "azurerm_client_config" "current" {}

output "terraform_identity" {
  description = "The identity Terraform used for this run."
  value = {
    client_id       = data.azurerm_client_config.current.client_id
    object_id       = data.azurerm_client_config.current.object_id
    tenant_id       = data.azurerm_client_config.current.tenant_id
    subscription_id = data.azurerm_client_config.current.subscription_id
  }
}
