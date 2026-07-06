# Terraform and Provider Version Constraints
# AKS Module

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.75.0, < 4.80.1"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.45.0, < 3.0.0"
    }
  }
}
