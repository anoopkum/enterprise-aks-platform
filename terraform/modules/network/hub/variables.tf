# Hub Network Module - Variables
#
# Input variables for the hub network infrastructure including
# VNet, Azure Firewall, Bastion, and Private DNS zones.

#------------------------------------------------------------------------------
# General Configuration
#------------------------------------------------------------------------------

variable "resource_group_name" {
  description = "Name of the resource group where hub network resources will be created"
  type        = string
}

variable "location" {
  description = "Azure region for hub network resources"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all hub network resources"
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# Virtual Network Configuration
#------------------------------------------------------------------------------

variable "vnet_name" {
  description = "Name of the hub virtual network"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the hub virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

#------------------------------------------------------------------------------
# Subnet Configuration
#------------------------------------------------------------------------------

variable "firewall_subnet_prefix" {
  description = "Address prefix for the Azure Firewall subnet (must be /26 or larger)"
  type        = string
  default     = "10.0.1.0/26"

  validation {
    condition     = can(cidrhost(var.firewall_subnet_prefix, 0))
    error_message = "Firewall subnet prefix must be a valid CIDR block."
  }
}

variable "bastion_subnet_prefix" {
  description = "Address prefix for the Azure Bastion subnet (must be /26 or larger)"
  type        = string
  default     = "10.0.2.0/26"

  validation {
    condition     = can(cidrhost(var.bastion_subnet_prefix, 0))
    error_message = "Bastion subnet prefix must be a valid CIDR block."
  }
}

variable "gateway_subnet_prefix" {
  description = "Address prefix for the VPN Gateway subnet (must be /27 or larger)"
  type        = string
  default     = "10.0.3.0/27"

  validation {
    condition     = can(cidrhost(var.gateway_subnet_prefix, 0))
    error_message = "Gateway subnet prefix must be a valid CIDR block."
  }
}

variable "management_subnet_prefix" {
  description = "Address prefix for the management subnet (optional)"
  type        = string
  default     = "10.0.4.0/24"

  validation {
    condition     = can(cidrhost(var.management_subnet_prefix, 0))
    error_message = "Management subnet prefix must be a valid CIDR block."
  }
}

#------------------------------------------------------------------------------
# DDoS Protection Configuration
#------------------------------------------------------------------------------

variable "enable_ddos_protection" {
  description = "Enable DDoS Protection Standard for the hub VNet"
  type        = bool
  default     = false
}

variable "ddos_protection_plan_id" {
  description = "ID of an existing DDoS Protection Plan (if not creating a new one)"
  type        = string
  default     = null
}

variable "create_ddos_protection_plan" {
  description = "Create a new DDoS Protection Plan (only if enable_ddos_protection is true)"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Azure Firewall Configuration
#------------------------------------------------------------------------------

variable "enable_firewall" {
  description = "Enable Azure Firewall in the hub network"
  type        = bool
  default     = true
}

variable "firewall_sku_name" {
  description = "SKU name for Azure Firewall (AZFW_VNet or AZFW_Hub)"
  type        = string
  default     = "AZFW_VNet"

  validation {
    condition     = contains(["AZFW_VNet", "AZFW_Hub"], var.firewall_sku_name)
    error_message = "Firewall SKU name must be AZFW_VNet or AZFW_Hub."
  }
}

variable "firewall_sku_tier" {
  description = "SKU tier for Azure Firewall (Standard or Premium)"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_sku_tier)
    error_message = "Firewall SKU tier must be Standard or Premium."
  }
}

variable "firewall_zones" {
  description = "Availability zones for Azure Firewall"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "firewall_threat_intel_mode" {
  description = "Threat intelligence mode for Azure Firewall (Off, Alert, Deny)"
  type        = string
  default     = "Alert"

  validation {
    condition     = contains(["Off", "Alert", "Deny"], var.firewall_threat_intel_mode)
    error_message = "Threat intelligence mode must be Off, Alert, or Deny."
  }
}

#------------------------------------------------------------------------------
# Azure Bastion Configuration
#------------------------------------------------------------------------------

variable "enable_bastion" {
  description = "Enable Azure Bastion in the hub network"
  type        = bool
  default     = true
}

variable "bastion_sku" {
  description = "SKU for Azure Bastion (Basic or Standard)"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard"], var.bastion_sku)
    error_message = "Bastion SKU must be Basic or Standard."
  }
}

variable "bastion_tunneling_enabled" {
  description = "Enable native client tunneling for Azure Bastion (requires Standard SKU)"
  type        = bool
  default     = true
}

variable "bastion_copy_paste_enabled" {
  description = "Enable copy/paste for Azure Bastion"
  type        = bool
  default     = true
}

variable "bastion_file_copy_enabled" {
  description = "Enable file copy for Azure Bastion (requires Standard SKU)"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# VPN Gateway Configuration
#------------------------------------------------------------------------------

variable "enable_vpn_gateway" {
  description = "Enable VPN Gateway in the hub network"
  type        = bool
  default     = false
}

variable "vpn_gateway_sku" {
  description = "SKU for VPN Gateway"
  type        = string
  default     = "VpnGw1AZ"
}

variable "vpn_gateway_type" {
  description = "Type of VPN Gateway (Vpn or ExpressRoute)"
  type        = string
  default     = "Vpn"

  validation {
    condition     = contains(["Vpn", "ExpressRoute"], var.vpn_gateway_type)
    error_message = "Gateway type must be Vpn or ExpressRoute."
  }
}

#------------------------------------------------------------------------------
# Private DNS Zones Configuration
#------------------------------------------------------------------------------

variable "private_dns_zones" {
  description = "List of Private DNS zone names to create in the hub"
  type        = list(string)
  default = [
    "privatelink.azurecr.io",
    "privatelink.vaultcore.azure.net",
    "privatelink.postgres.database.azure.com",
    "privatelink.blob.core.windows.net",
    "privatelink.azmk8s.io"
  ]
}

variable "create_private_dns_zones" {
  description = "Create Private DNS zones in the hub network"
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
  description = "Enable diagnostic settings for hub network resources"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain logs in Log Analytics"
  type        = number
  default     = 30
}
