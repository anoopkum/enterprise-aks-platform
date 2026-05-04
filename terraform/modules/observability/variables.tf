# Observability Module - Variables
#
# Input variables for observability infrastructure including
# Log Analytics, Application Insights, and Azure Monitor alerts.

#------------------------------------------------------------------------------
# General Configuration
#------------------------------------------------------------------------------

variable "resource_group_name" {
  description = "Name of the resource group where observability resources will be created"
  type        = string
}

variable "location" {
  description = "Azure region for observability resources"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all observability resources"
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# Log Analytics Workspace Configuration
#------------------------------------------------------------------------------

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  type        = string
}

variable "log_analytics_sku" {
  description = "SKU for Log Analytics Workspace"
  type        = string
  default     = "PerGB2018"
}

variable "log_analytics_retention_in_days" {
  description = "Retention period in days for Log Analytics data"
  type        = number
  default     = 90

  validation {
    condition     = var.log_analytics_retention_in_days >= 30 && var.log_analytics_retention_in_days <= 730
    error_message = "Retention must be between 30 and 730 days."
  }
}

variable "log_analytics_daily_quota_gb" {
  description = "Daily quota in GB for Log Analytics (-1 for unlimited)"
  type        = number
  default     = -1
}

#------------------------------------------------------------------------------
# Application Insights Configuration
#------------------------------------------------------------------------------

variable "app_insights_name" {
  description = "Name of the Application Insights resource"
  type        = string
}

variable "app_insights_application_type" {
  description = "Application type for Application Insights"
  type        = string
  default     = "web"

  validation {
    condition     = contains(["web", "ios", "java", "MobileCenter", "Node.JS", "other", "phone", "store"], var.app_insights_application_type)
    error_message = "Invalid application type."
  }
}

variable "app_insights_sampling_percentage" {
  description = "Sampling percentage for Application Insights (0-100)"
  type        = number
  default     = 100

  validation {
    condition     = var.app_insights_sampling_percentage >= 0 && var.app_insights_sampling_percentage <= 100
    error_message = "Sampling percentage must be between 0 and 100."
  }
}

variable "app_insights_daily_data_cap_in_gb" {
  description = "Daily data cap in GB for Application Insights"
  type        = number
  default     = 100
}

#------------------------------------------------------------------------------
# Alert Configuration
#------------------------------------------------------------------------------

variable "create_alerts" {
  description = "Create Azure Monitor alerts"
  type        = bool
  default     = true
}

variable "alert_action_group_name" {
  description = "Name of the action group for alerts"
  type        = string
  default     = "platform-alerts"
}

variable "alert_email_receivers" {
  description = "List of email addresses for alert notifications"
  type = list(object({
    name          = string
    email_address = string
  }))
  default = []
}

variable "pagerduty_integration_key" {
  description = "PagerDuty integration key for Sev0 alerts"
  type        = string
  default     = null
  sensitive   = true
}

variable "teams_webhook_url" {
  description = "Microsoft Teams webhook URL for Sev1-3 alerts"
  type        = string
  default     = null
  sensitive   = true
}

#------------------------------------------------------------------------------
# AKS Cluster Configuration (for alerts)
#------------------------------------------------------------------------------

variable "aks_cluster_id" {
  description = "ID of the AKS cluster for monitoring"
  type        = string
  default     = null
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster for alert scoping"
  type        = string
  default     = null
}
