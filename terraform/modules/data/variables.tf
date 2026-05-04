# Data Module - Variables
#
# Input variables for data infrastructure including
# ACR, PostgreSQL, and Storage accounts.

#------------------------------------------------------------------------------
# General Configuration
#------------------------------------------------------------------------------

variable "resource_group_name" {
  description = "Name of the resource group where data resources will be created"
  type        = string
}

variable "location" {
  description = "Azure region for data resources"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all data resources"
  type        = map(string)
  default     = {}
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

#------------------------------------------------------------------------------
# Azure Container Registry Configuration
#------------------------------------------------------------------------------

variable "acr_name" {
  description = "Name of the Azure Container Registry"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9]{5,50}$", var.acr_name))
    error_message = "ACR name must be 5-50 alphanumeric characters."
  }
}

variable "acr_sku" {
  description = "SKU for Azure Container Registry"
  type        = string
  default     = "Premium"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "ACR SKU must be Basic, Standard, or Premium."
  }
}

variable "acr_admin_enabled" {
  description = "Enable admin user for ACR"
  type        = bool
  default     = false
}

variable "acr_public_network_access_enabled" {
  description = "Enable public network access to ACR"
  type        = bool
  default     = false
}

variable "acr_geo_replications" {
  description = "List of regions for ACR geo-replication (Premium SKU only)"
  type        = list(string)
  default     = []
}

variable "acr_retention_policy_days" {
  description = "Number of days to retain untagged manifests"
  type        = number
  default     = 7
}

variable "acr_trust_policy_enabled" {
  description = "Enable content trust policy for image signing"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# PostgreSQL Configuration
#------------------------------------------------------------------------------

variable "postgresql_server_name" {
  description = "Name of the PostgreSQL Flexible Server"
  type        = string
}

variable "postgresql_sku_name" {
  description = "SKU name for PostgreSQL Flexible Server"
  type        = string
  default     = "GP_Standard_D4s_v3"
}

variable "postgresql_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15"

  validation {
    condition     = contains(["11", "12", "13", "14", "15", "16"], var.postgresql_version)
    error_message = "PostgreSQL version must be 11, 12, 13, 14, 15, or 16."
  }
}

variable "postgresql_storage_mb" {
  description = "Storage size in MB for PostgreSQL"
  type        = number
  default     = 32768
}

variable "postgresql_ha_enabled" {
  description = "Enable zone-redundant high availability"
  type        = bool
  default     = true
}

variable "postgresql_backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 35

  validation {
    condition     = var.postgresql_backup_retention_days >= 7 && var.postgresql_backup_retention_days <= 35
    error_message = "Backup retention must be between 7 and 35 days."
  }
}

variable "postgresql_geo_redundant_backup_enabled" {
  description = "Enable geo-redundant backups"
  type        = bool
  default     = true
}

variable "postgresql_administrator_login" {
  description = "Administrator login for PostgreSQL"
  type        = string
  default     = "pgadmin"
}

variable "postgresql_administrator_password" {
  description = "Administrator password for PostgreSQL (if not using Azure AD auth)"
  type        = string
  default     = null
  sensitive   = true
}

variable "postgresql_delegated_subnet_id" {
  description = "ID of the delegated subnet for PostgreSQL (for VNet integration)"
  type        = string
  default     = null
}

variable "postgresql_private_dns_zone_id" {
  description = "ID of the private DNS zone for PostgreSQL"
  type        = string
  default     = null
}

#------------------------------------------------------------------------------
# Storage Account Configuration
#------------------------------------------------------------------------------

variable "storage_account_name" {
  description = "Name of the Storage Account"
  type        = string
  default     = null

  validation {
    condition     = var.storage_account_name == null || can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must be 3-24 lowercase alphanumeric characters."
  }
}

variable "storage_account_tier" {
  description = "Storage account tier"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.storage_account_tier)
    error_message = "Storage account tier must be Standard or Premium."
  }
}

variable "storage_account_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "GRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.storage_account_replication_type)
    error_message = "Invalid replication type."
  }
}

variable "storage_account_public_network_access_enabled" {
  description = "Enable public network access to storage account"
  type        = bool
  default     = false
}

variable "create_storage_account" {
  description = "Create a storage account for application data"
  type        = bool
  default     = true
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
  description = "Enable diagnostic settings for data resources"
  type        = bool
  default     = true
}
