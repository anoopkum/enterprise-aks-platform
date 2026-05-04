# Test Environment - Variables
#
# Input variables for the test environment configuration.

#------------------------------------------------------------------------------
# General Configuration
#------------------------------------------------------------------------------

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "org" {
  description = "Organization prefix for resource names"
  type        = string
  default     = "contoso"
}

#------------------------------------------------------------------------------
# Tagging Configuration
#------------------------------------------------------------------------------

variable "owner_email" {
  description = "Owner email for resource tagging"
  type        = string
}

variable "cost_center" {
  description = "Cost center for billing allocation"
  type        = string
}

#------------------------------------------------------------------------------
# Network Configuration
#------------------------------------------------------------------------------

variable "hub_vnet_address_space" {
  description = "Address space for hub VNet"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "spoke_vnet_address_space" {
  description = "Address space for spoke VNet"
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

#------------------------------------------------------------------------------
# AKS Configuration
#------------------------------------------------------------------------------

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "aks_admin_group_ids" {
  description = "Azure AD group IDs for AKS admin access"
  type        = list(string)
  default     = []
}

variable "api_server_authorized_ip_ranges" {
  description = "Authorized IP ranges for AKS API server access"
  type        = list(string)
  default     = []
}

#------------------------------------------------------------------------------
# Budget Configuration
#------------------------------------------------------------------------------

variable "monthly_budget" {
  description = "Monthly budget in USD"
  type        = number
  default     = 10000
}

variable "budget_alert_emails" {
  description = "Email addresses for budget alerts"
  type        = list(string)
  default     = []
}
