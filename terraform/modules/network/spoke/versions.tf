# Terraform and Provider Version Constraints
# Spoke Network Module

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.75.0, < 4.0.0"
    }
  }
}
