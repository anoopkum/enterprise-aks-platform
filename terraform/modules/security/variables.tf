# Security Module - Variables
#
# Input variables for security infrastructure including
# Key Vault, managed identities, and private endpoints.

#------------------------------------------------------------------------------
# General Configuration
#------------------------------------------------------------------------------

variable "resource_group_name" {
  description = "Name of the resource group where security resources will be created"
  type        = string
}

variable "location" {
  description = "Azure region for security resources"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all security resources"
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# Key Vault Configuration
#------------------------------------------------------------------------------

variable "key_vault_name" {
  description = "Name of the Key Vault"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.key_vault_name))
    error_message = "Key Vault name must be 3-24 characters, start with a letter, and contain only alphanumeric characters and hyphens."
  }
}

variable "key_vault_sku" {
  description = "SKU for Key Vault (standard or premium)"
  type        = string
  default     = "premium"

  validation {
    condition     = contains(["standard", "premium"], var.key_vault_sku)
    error_message = "Key Vault SKU must be standard or premium."
  }
}

variable "key_vault_soft_delete_retention_days" {
  description = "Number of days to retain soft-deleted Key Vault items"
  type        = number
  default     = 90

  validation {
    condition     = var.key_vault_soft_delete_retention_days >= 7 && var.key_vault_soft_delete_retention_days <= 90
    error_message = "Soft delete retention must be between 7 and 90 days."
  }
}

variable "key_vault_purge_protection_enabled" {
  description = "Enable purge protection for Key Vault"
  type        = bool
  default     = true
}

variable "key_vault_enable_rbac_authorization" {
  description = "Enable RBAC authorization for Key Vault (recommended over access policies)"
  type        = bool
  default     = true
}

variable "key_vault_public_network_access_enabled" {
  description = "Enable public network access to Key Vault"
  type        = bool
  default     = false
}

variable "key_vault_network_acls_default_action" {
  description = "Default action for Key Vault network ACLs"
  type        = string
  default     = "Deny"

  validation {
    condition     = contains(["Allow", "Deny"], var.key_vault_network_acls_default_action)
    error_message = "Network ACLs default action must be Allow or Deny."
  }
}

variable "key_vault_network_acls_bypass" {
  description = "Services that can bypass Key Vault network ACLs"
  type        = string
  default     = "AzureServices"

  validation {
    condition     = contains(["None", "AzureServices"], var.key_vault_network_acls_bypass)
    error_message = "Network ACLs bypass must be None or AzureServices."
  }
}

#------------------------------------------------------------------------------
# Private Endpoint Configuration
#------------------------------------------------------------------------------

variable "private_endpoint_subnet_id" {
  description = "ID of the subnet for private endpoints"
  type        = string
}

variable "private_dns_zone_ids" {
  description = "Map of Private DNS zone names to their IDs"
  type        = map(string)
  default     = {}
}

variable "create_key_vault_private_endpoint" {
  description = "Create a private endpoint for Key Vault"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Managed Identity Configuration
#------------------------------------------------------------------------------

variable "create_aks_identity" {
  description = "Create a user-assigned managed identity for AKS control plane"
  type        = bool
  default     = true
}

variable "aks_identity_name" {
  description = "Name of the AKS control plane managed identity"
  type        = string
  default     = null
}

variable "create_kubelet_identity" {
  description = "Create a user-assigned managed identity for kubelet"
  type        = bool
  default     = true
}

variable "kubelet_identity_name" {
  description = "Name of the kubelet managed identity"
  type        = string
  default     = null
}

#------------------------------------------------------------------------------
# Key Vault Access Configuration
#------------------------------------------------------------------------------

variable "aks_identity_key_vault_permissions" {
  description = "Key Vault permissions for AKS identity"
  type = object({
    secret_permissions      = list(string)
    certificate_permissions = list(string)
    key_permissions         = list(string)
  })
  default = {
    secret_permissions      = ["Get", "List"]
    certificate_permissions = ["Get", "List"]
    key_permissions         = ["Get", "List"]
  }
}

variable "admin_object_ids" {
  description = "Object IDs of users/groups/service principals that should have admin access to Key Vault"
  type        = list(string)
  default     = []
}

#------------------------------------------------------------------------------
# Log Analytics Configuration
#------------------------------------------------------------------------------

variable "log_analytics_workspace_id" {
  description = "ID of Log Analytics Workspace for diagnostic settings"
  type        = string
  default     = null
}

variable "enable_diagnostic_settings" {
  description = "Enable diagnostic settings for security resources"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Role Assignment Configuration
#------------------------------------------------------------------------------

variable "enable_role_assignments" {
  description = "Enable role assignments (requires Microsoft.Authorization/roleAssignments/write permission)"
  type        = bool
  default     = true
}
