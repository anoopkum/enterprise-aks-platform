# Terraform Backend Configuration - Development Environment
#
# OPTION 1: Local Backend (for initial testing)
# Uncomment the local backend block below for quick testing
#
# OPTION 2: Azure Backend (recommended for production)
# Run `bash terraform/scripts/init-backend.sh dev` first, then update values below

# ============================================================================
# LOCAL BACKEND (uncomment for quick testing)
# ============================================================================
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }

# ============================================================================
# AZURE BACKEND (recommended)
# ============================================================================
terraform {
  backend "azurerm" {
    # Storage account details - update these values after running init-backend.sh
    # Run: bash terraform/scripts/init-backend.sh dev
    resource_group_name  = "rg-enterprise-dev-tfstate"
    storage_account_name = "entdevtfstate4750"
    container_name       = "tfstate"
    key                  = "dev/aks-platform.tfstate"

    # Authentication options:
    # 1. Azure CLI (local development): export ARM_USE_CLI=true
    # 2. OIDC (CI/CD): export ARM_USE_OIDC=true
    use_oidc = false # Set to true for CI/CD

    # Subscription and tenant IDs (can also use ARM_SUBSCRIPTION_ID, ARM_TENANT_ID)
    # subscription_id = "27320543-d2ea-4fd5-b361-0145cc56934b"
    # tenant_id       = "e2e605ca-a105-4b19-bcb9-5b1ca2d5ce71"
  }
}
