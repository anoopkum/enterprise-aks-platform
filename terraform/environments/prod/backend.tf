# Terraform Backend Configuration - Production Environment
#
# State is stored in Azure Storage Account with:
# - GRS replication for durability
# - Blob lease for state locking
# - OIDC authentication for CI/CD pipelines
#
# Prerequisites:
# 1. Run `make init-backend ENV=prod` to create the storage account
# 2. Configure OIDC federation in Azure AD for GitHub Actions

terraform {
  backend "azurerm" {
    # Storage account details - update these values after running init-backend.sh
    resource_group_name  = "contoso-prod-eastus-rg-tfstate"
    storage_account_name = "contosoprodeustfstate"
    container_name       = "tfstate"
    key                  = "prod/aks-platform.tfstate"

    # OIDC authentication (recommended for CI/CD)
    # Set ARM_USE_OIDC=true in environment
    use_oidc = true

    # Subscription and tenant IDs
    # These can also be set via environment variables:
    # ARM_SUBSCRIPTION_ID, ARM_TENANT_ID
    # subscription_id = "00000000-0000-0000-0000-000000000000"
    # tenant_id       = "00000000-0000-0000-0000-000000000000"

    # State locking is automatically enabled via blob lease
    # Lock timeout defaults to infinite; operations will wait for lock release
  }
}
