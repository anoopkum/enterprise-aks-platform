# Spoke Network Module - Variables
#
# Input variables for the spoke network infrastructure including
# VNet, subnets, peering, NSGs, and UDRs.

#------------------------------------------------------------------------------
# General Configuration
#------------------------------------------------------------------------------

variable "resource_group_name" {
  description = "Name of the resource group where spoke network resources will be created"
  type        = string
}

variable "location" {
  description = "Azure region for spoke network resources"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all spoke network resources"
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# Virtual Network Configuration
#------------------------------------------------------------------------------

variable "vnet_name" {
  description = "Name of the spoke virtual network"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the spoke virtual network"
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

#------------------------------------------------------------------------------
# Subnet Configuration
#------------------------------------------------------------------------------

variable "aks_subnet_prefix" {
  description = "Address prefix for the AKS subnet"
  type        = string
  default     = "10.1.0.0/22"

  validation {
    condition     = can(cidrhost(var.aks_subnet_prefix, 0))
    error_message = "AKS subnet prefix must be a valid CIDR block."
  }
}

variable "aks_ilb_subnet_prefix" {
  description = "Address prefix for the AKS internal load balancer subnet"
  type        = string
  default     = "10.1.4.0/24"

  validation {
    condition     = can(cidrhost(var.aks_ilb_subnet_prefix, 0))
    error_message = "AKS ILB subnet prefix must be a valid CIDR block."
  }
}

variable "private_endpoints_subnet_prefix" {
  description = "Address prefix for the private endpoints subnet"
  type        = string
  default     = "10.1.5.0/24"

  validation {
    condition     = can(cidrhost(var.private_endpoints_subnet_prefix, 0))
    error_message = "Private endpoints subnet prefix must be a valid CIDR block."
  }
}

variable "app_gateway_subnet_prefix" {
  description = "Address prefix for the Application Gateway subnet"
  type        = string
  default     = "10.1.6.0/24"

  validation {
    condition     = can(cidrhost(var.app_gateway_subnet_prefix, 0))
    error_message = "Application Gateway subnet prefix must be a valid CIDR block."
  }
}

#------------------------------------------------------------------------------
# Hub Network Configuration (for peering)
#------------------------------------------------------------------------------

variable "hub_vnet_id" {
  description = "ID of the hub virtual network for peering"
  type        = string
}

variable "hub_vnet_name" {
  description = "Name of the hub virtual network"
  type        = string
}

variable "hub_resource_group_name" {
  description = "Resource group name of the hub virtual network"
  type        = string
}

variable "hub_firewall_private_ip" {
  description = "Private IP address of the Azure Firewall in the hub (for UDR)"
  type        = string
  default     = null
}

#------------------------------------------------------------------------------
# VNet Peering Configuration
#------------------------------------------------------------------------------

variable "enable_gateway_transit" {
  description = "Enable gateway transit on the hub peering (allows spoke to use hub's VPN gateway)"
  type        = bool
  default     = false
}

variable "use_remote_gateways" {
  description = "Use remote gateways from the hub network"
  type        = bool
  default     = false
}

variable "allow_forwarded_traffic" {
  description = "Allow forwarded traffic between hub and spoke"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Private DNS Zone Configuration
#------------------------------------------------------------------------------

variable "private_dns_zone_ids" {
  description = "Map of Private DNS zone names to their IDs for VNet linking"
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# Network Security Configuration
#------------------------------------------------------------------------------

variable "enable_forced_tunneling" {
  description = "Enable forced tunneling through Azure Firewall"
  type        = bool
  default     = true
}

variable "enable_nsg" {
  description = "Enable Network Security Groups on subnets"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Service Endpoints Configuration
#------------------------------------------------------------------------------

variable "aks_subnet_service_endpoints" {
  description = "Service endpoints to enable on the AKS subnet"
  type        = list(string)
  default = [
    "Microsoft.ContainerRegistry",
    "Microsoft.KeyVault",
    "Microsoft.Storage"
  ]
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
  description = "Enable diagnostic settings for spoke network resources"
  type        = bool
  default     = true
}
