# Governance Module - Variables
#
# Input variables for governance infrastructure including
# Azure Policy assignments and budget alerts.

#------------------------------------------------------------------------------
# General Configuration
#------------------------------------------------------------------------------

variable "subscription_id" {
  description = "Azure subscription ID for policy assignments"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group for governance resources"
  type        = string
  default     = null
}

variable "location" {
  description = "Azure region for governance resources"
  type        = string
  default     = "eastus"
}

variable "tags" {
  description = "Tags to apply to governance resources"
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# Azure Policy Configuration
#------------------------------------------------------------------------------

variable "enable_policy_assignments" {
  description = "Enable Azure Policy assignments"
  type        = bool
  default     = true
}

variable "allowed_vm_sizes" {
  description = "List of allowed VM sizes for AKS node pools"
  type        = list(string)
  default = [
    "Standard_D2s_v5",
    "Standard_D4s_v5",
    "Standard_D8s_v5",
    "Standard_D16s_v5",
    "Standard_E4s_v5",
    "Standard_E8s_v5",
    "Standard_E16s_v5"
  ]
}

variable "mandatory_tags" {
  description = "List of mandatory tag keys"
  type        = list(string)
  default = [
    "Environment",
    "Owner",
    "CostCenter",
    "Application",
    "ManagedBy"
  ]
}

variable "allowed_locations" {
  description = "List of allowed Azure locations"
  type        = list(string)
  default = [
    "eastus",
    "eastus2",
    "westus2",
    "centralus"
  ]
}

variable "policy_enforcement_mode" {
  description = "Policy enforcement mode (Default or DoNotEnforce)"
  type        = string
  default     = "Default"

  validation {
    condition     = contains(["Default", "DoNotEnforce"], var.policy_enforcement_mode)
    error_message = "Policy enforcement mode must be Default or DoNotEnforce."
  }
}

#------------------------------------------------------------------------------
# Budget Configuration
#------------------------------------------------------------------------------

variable "enable_budget_alerts" {
  description = "Enable Azure Cost Management budget alerts"
  type        = bool
  default     = true
}

variable "monthly_budget" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 10000
}

variable "budget_alert_emails" {
  description = "List of email addresses for budget alerts"
  type        = list(string)
  default     = []
}

variable "budget_start_date" {
  description = "Budget start date (YYYY-MM-DD format, first day of month)"
  type        = string
  default     = null
}
