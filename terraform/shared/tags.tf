# Tagging Standards Module
#
# This module defines mandatory tags for all Azure resources
# to ensure consistent governance, cost allocation, and compliance.

variable "tag_environment" {
  description = "Environment name (dev, test, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.tag_environment)
    error_message = "Environment must be one of: dev, test, prod."
  }
}

variable "tag_owner" {
  description = "Owner email address or team name"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.tag_owner)) || can(regex("^[a-zA-Z0-9-]+$", var.tag_owner))
    error_message = "Owner must be a valid email address or team name."
  }
}

variable "tag_cost_center" {
  description = "Cost center code for billing allocation"
  type        = string

  validation {
    condition     = can(regex("^[A-Z]{2,4}-[0-9]{4,8}$", var.tag_cost_center))
    error_message = "Cost center must follow pattern: XX-NNNN (e.g., CC-12345)."
  }
}

variable "tag_application" {
  description = "Application or project name"
  type        = string

  validation {
    condition     = length(var.tag_application) >= 3 && length(var.tag_application) <= 50
    error_message = "Application name must be between 3 and 50 characters."
  }
}

variable "tag_repository" {
  description = "Source code repository URL"
  type        = string
  default     = ""

  validation {
    condition     = var.tag_repository == "" || can(regex("^https://", var.tag_repository))
    error_message = "Repository must be a valid HTTPS URL or empty."
  }
}

variable "tag_managed_by" {
  description = "Tool or process managing this resource"
  type        = string
  default     = "terraform"

  validation {
    condition     = contains(["terraform", "pulumi", "arm", "bicep", "manual"], var.tag_managed_by)
    error_message = "ManagedBy must be one of: terraform, pulumi, arm, bicep, manual."
  }
}

variable "additional_tags" {
  description = "Additional custom tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Generate mandatory tags with current timestamp
locals {
  # Mandatory tags that must be applied to all resources
  mandatory_tags = {
    Environment = var.tag_environment
    Owner       = var.tag_owner
    CostCenter  = var.tag_cost_center
    Application = var.tag_application
    ManagedBy   = var.tag_managed_by
    Repository  = var.tag_repository
    CreatedDate = formatdate("YYYY-MM-DD", timestamp())
  }

  # Combined tags (mandatory + additional)
  all_tags = merge(local.mandatory_tags, var.additional_tags)

  # Tags without timestamp (for resources that shouldn't update on every apply)
  stable_tags = {
    Environment = var.tag_environment
    Owner       = var.tag_owner
    CostCenter  = var.tag_cost_center
    Application = var.tag_application
    ManagedBy   = var.tag_managed_by
    Repository  = var.tag_repository
  }

  # Environment-specific tag values for common scenarios
  environment_config = {
    dev = {
      criticality         = "Low"
      data_classification = "Internal"
      backup_policy       = "None"
      support_hours       = "Business"
    }
    test = {
      criticality         = "Medium"
      data_classification = "Internal"
      backup_policy       = "Daily"
      support_hours       = "Business"
    }
    prod = {
      criticality         = "High"
      data_classification = "Confidential"
      backup_policy       = "Hourly"
      support_hours       = "24x7"
    }
  }

  # Extended tags including environment-specific values
  extended_tags = merge(
    local.all_tags,
    local.environment_config[var.tag_environment]
  )
}

# Outputs for use in other modules
output "mandatory_tags" {
  description = "Mandatory tags to apply to all resources"
  value       = local.mandatory_tags
}

output "stable_tags" {
  description = "Mandatory tags without timestamp (prevents unnecessary updates)"
  value       = local.stable_tags
}

output "all_tags" {
  description = "All tags including additional custom tags"
  value       = local.all_tags
}

output "extended_tags" {
  description = "Extended tags including environment-specific metadata"
  value       = local.extended_tags
}

output "tag_keys" {
  description = "List of mandatory tag keys for policy enforcement"
  value       = keys(local.mandatory_tags)
}
