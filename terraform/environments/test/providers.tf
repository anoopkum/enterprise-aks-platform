# Provider Configuration - Test Environment
#
# This configuration supports multiple authentication methods:
# 1. OIDC (recommended for CI/CD) - Set ARM_USE_OIDC=true
# 2. Service Principal - Set ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID
# 3. Azure CLI - Run 'az login' before terraform commands
# 4. Managed Identity - For Azure-hosted runners

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.75.0, < 4.0.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.45.0, < 3.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0, < 4.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0, < 1.0.0"
    }
  }
}

# Azure Resource Manager Provider
provider "azurerm" {
  features {
    # Key Vault features
    key_vault {
      # Purge soft-deleted key vaults on destroy
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }

    # Resource Group features
    resource_group {
      # Prevent destruction of resource groups with resources
      prevent_deletion_if_contains_resources = true
    }

    # Virtual Machine features
    virtual_machine {
      # Gracefully delete OS disk on VM destroy
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = true
      skip_shutdown_and_force_delete = false
    }

    # Log Analytics features
    log_analytics_workspace {
      permanently_delete_on_destroy = false
    }
  }

  # OIDC authentication is configured via environment variables:
  # ARM_USE_OIDC=true
  # ARM_CLIENT_ID=<service-principal-client-id>
  # ARM_TENANT_ID=<azure-tenant-id>
  # ARM_SUBSCRIPTION_ID=<azure-subscription-id>
  # ARM_OIDC_TOKEN or ARM_OIDC_TOKEN_FILE_PATH (set by GitHub Actions)

  # Skip provider registration if not needed
  skip_provider_registration = false

  # Storage account configuration for data plane operations
  storage_use_azuread = true
}

# Azure Active Directory Provider
provider "azuread" {
  # Uses the same authentication as azurerm
  # OIDC authentication is configured via environment variables
}

# Random Provider (for generating unique names)
provider "random" {}

# Time Provider (for managing time-based resources)
provider "time" {}
