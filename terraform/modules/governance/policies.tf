# Governance Module - Azure Policy Assignments
#
# This file creates Azure Policy assignments for:
# - Allowed VM sizes for AKS node pools
# - Mandatory tags on all resources
# - Private endpoints required for PaaS services
# - Encryption at rest and in transit

#------------------------------------------------------------------------------
# Data Sources
#------------------------------------------------------------------------------

data "azurerm_subscription" "current" {}

#------------------------------------------------------------------------------
# Policy Assignment - Allowed VM Sizes
#------------------------------------------------------------------------------

resource "azurerm_subscription_policy_assignment" "allowed_vm_sizes" {
  count = var.enable_policy_assignments ? 1 : 0

  name                 = "allowed-vm-sizes"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/cccc23c7-8427-4f53-ad12-b6a63eb452b3"
  display_name         = "Allowed virtual machine size SKUs"
  description          = "Restricts VM sizes to approved SKUs for cost control"
  enforce              = var.policy_enforcement_mode == "Default" ? true : false

  parameters = jsonencode({
    listOfAllowedSKUs = {
      value = var.allowed_vm_sizes
    }
  })
}

#------------------------------------------------------------------------------
# Policy Assignment - Require Tag on Resources
#------------------------------------------------------------------------------

resource "azurerm_subscription_policy_assignment" "require_tag_environment" {
  count = var.enable_policy_assignments ? 1 : 0

  name                 = "require-tag-environment"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
  display_name         = "Require Environment tag on resources"
  description          = "Enforces the Environment tag on all resources"
  enforce              = var.policy_enforcement_mode == "Default" ? true : false

  parameters = jsonencode({
    tagName = {
      value = "Environment"
    }
  })
}

resource "azurerm_subscription_policy_assignment" "require_tag_owner" {
  count = var.enable_policy_assignments ? 1 : 0

  name                 = "require-tag-owner"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
  display_name         = "Require Owner tag on resources"
  description          = "Enforces the Owner tag on all resources"
  enforce              = var.policy_enforcement_mode == "Default" ? true : false

  parameters = jsonencode({
    tagName = {
      value = "Owner"
    }
  })
}

resource "azurerm_subscription_policy_assignment" "require_tag_costcenter" {
  count = var.enable_policy_assignments ? 1 : 0

  name                 = "require-tag-costcenter"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
  display_name         = "Require CostCenter tag on resources"
  description          = "Enforces the CostCenter tag on all resources"
  enforce              = var.policy_enforcement_mode == "Default" ? true : false

  parameters = jsonencode({
    tagName = {
      value = "CostCenter"
    }
  })
}

#------------------------------------------------------------------------------
# Policy Assignment - Allowed Locations
#------------------------------------------------------------------------------

resource "azurerm_subscription_policy_assignment" "allowed_locations" {
  count = var.enable_policy_assignments ? 1 : 0

  name                 = "allowed-locations"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
  display_name         = "Allowed locations"
  description          = "Restricts resource deployment to approved regions"
  enforce              = var.policy_enforcement_mode == "Default" ? true : false

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = var.allowed_locations
    }
  })
}

#------------------------------------------------------------------------------
# Policy Assignment - Storage Account Secure Transfer
#------------------------------------------------------------------------------

resource "azurerm_subscription_policy_assignment" "storage_secure_transfer" {
  count = var.enable_policy_assignments ? 1 : 0

  name                 = "storage-secure-transfer"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9"
  display_name         = "Secure transfer to storage accounts should be enabled"
  description          = "Audit requirement of Secure transfer in your storage account"
  enforce              = var.policy_enforcement_mode == "Default" ? true : false
}

#------------------------------------------------------------------------------
# Policy Assignment - Key Vault Purge Protection
#------------------------------------------------------------------------------

resource "azurerm_subscription_policy_assignment" "keyvault_purge_protection" {
  count = var.enable_policy_assignments ? 1 : 0

  name                 = "keyvault-purge-protection"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/0b60c0b2-2dc2-4e1c-b5c9-abbed971de53"
  display_name         = "Key vaults should have purge protection enabled"
  description          = "Audit Key Vaults for purge protection"
  enforce              = var.policy_enforcement_mode == "Default" ? true : false
}

#------------------------------------------------------------------------------
# Policy Assignment - AKS Azure Policy Addon
#------------------------------------------------------------------------------

resource "azurerm_subscription_policy_assignment" "aks_azure_policy" {
  count = var.enable_policy_assignments ? 1 : 0

  name                 = "aks-azure-policy-addon"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/0a15ec92-a229-4763-bb14-0ea34a568f8d"
  display_name         = "Azure Policy Add-on for Kubernetes service (AKS) should be installed"
  description          = "Audit AKS clusters for Azure Policy addon"
  enforce              = var.policy_enforcement_mode == "Default" ? true : false
}

#------------------------------------------------------------------------------
# Policy Assignment - AKS Private Cluster
#------------------------------------------------------------------------------

resource "azurerm_subscription_policy_assignment" "aks_private_cluster" {
  count = var.enable_policy_assignments ? 1 : 0

  name                 = "aks-private-cluster"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/040732e8-d947-40b8-95d6-854c95024bf8"
  display_name         = "Azure Kubernetes Service Private Clusters should be enabled"
  description          = "Audit AKS clusters for private cluster configuration"
  enforce              = var.policy_enforcement_mode == "Default" ? true : false
}
