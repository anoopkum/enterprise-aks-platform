# Terraform Backend Configuration - Test Environment
#
# State is stored in Azure Storage Account with:
# - GRS replication for durability
# - Blob lease for state locking

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-enterprise-dev-tfstate"
    storage_account_name = "entdevtfstate4750"
    container_name       = "tfstate"
    key                  = "test/aks-platform.tfstate"

    # Authentication via ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID
    use_oidc = false
  }
}
