# Naming Conventions Module
# Pattern: {org}-{env}-{region}-{resource-type}-{instance}
#
# This module provides consistent naming for all Azure resources
# following enterprise naming standards.

variable "naming_org" {
  description = "Organization prefix for resource names"
  type        = string
  default     = "contoso"

  validation {
    condition     = can(regex("^[a-z0-9]{2,10}$", var.naming_org))
    error_message = "Organization prefix must be 2-10 lowercase alphanumeric characters."
  }
}

variable "naming_env" {
  description = "Environment identifier (dev, test, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.naming_env)
    error_message = "Environment must be one of: dev, test, prod."
  }
}

variable "naming_region" {
  description = "Azure region short name"
  type        = string
  default     = "eastus"

  validation {
    condition     = can(regex("^[a-z]{4,20}[0-9]?$", var.naming_region))
    error_message = "Region must be a valid Azure region short name."
  }
}

variable "naming_instance" {
  description = "Optional instance identifier for multiple resources of the same type"
  type        = string
  default     = ""

  validation {
    condition     = var.naming_instance == "" || can(regex("^[a-z0-9]{1,10}$", var.naming_instance))
    error_message = "Instance identifier must be 1-10 lowercase alphanumeric characters or empty."
  }
}

# Resource type abbreviations following Azure naming conventions
# Reference: https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations
locals {
  resource_type_abbreviations = {
    # Networking
    virtual_network        = "vnet"
    subnet                 = "snet"
    network_security_group = "nsg"
    route_table            = "rt"
    public_ip              = "pip"
    load_balancer          = "lb"
    application_gateway    = "agw"
    firewall               = "afw"
    firewall_policy        = "afwp"
    bastion                = "bas"
    vpn_gateway            = "vpng"
    private_endpoint       = "pe"
    private_dns_zone       = "pdnsz"
    ddos_protection_plan   = "ddos"
    nat_gateway            = "ng"

    # Compute
    kubernetes_cluster        = "aks"
    virtual_machine           = "vm"
    virtual_machine_scale_set = "vmss"
    availability_set          = "avail"

    # Storage
    storage_account    = "st"
    container_registry = "acr"
    blob_container     = "blob"

    # Databases
    postgresql_server = "psql"
    mysql_server      = "mysql"
    cosmosdb_account  = "cosmos"
    redis_cache       = "redis"

    # Security
    key_vault           = "kv"
    managed_identity    = "id"
    disk_encryption_set = "des"

    # Monitoring
    log_analytics_workspace = "law"
    application_insights    = "ai"
    action_group            = "ag"
    alert_rule              = "ar"

    # Management
    resource_group    = "rg"
    policy_definition = "pd"
    policy_assignment = "pa"
    budget            = "budget"

    # Integration
    service_bus_namespace = "sb"
    event_hub_namespace   = "evh"
    api_management        = "apim"
  }

  # Region abbreviations for shorter names where needed
  region_abbreviations = {
    eastus             = "eus"
    eastus2            = "eus2"
    westus             = "wus"
    westus2            = "wus2"
    westus3            = "wus3"
    centralus          = "cus"
    northcentralus     = "ncus"
    southcentralus     = "scus"
    westcentralus      = "wcus"
    canadacentral      = "cac"
    canadaeast         = "cae"
    brazilsouth        = "brs"
    northeurope        = "neu"
    westeurope         = "weu"
    uksouth            = "uks"
    ukwest             = "ukw"
    francecentral      = "frc"
    francesouth        = "frs"
    germanywestcentral = "gwc"
    norwayeast         = "noe"
    switzerlandnorth   = "chn"
    uaenorth           = "uan"
    southafricanorth   = "san"
    australiaeast      = "aue"
    australiasoutheast = "ause"
    japaneast          = "jpe"
    japanwest          = "jpw"
    koreacentral       = "krc"
    koreasouth         = "krs"
    southeastasia      = "sea"
    eastasia           = "ea"
    centralindia       = "inc"
    southindia         = "ins"
    westindia          = "inw"
  }
}

# Naming function - generates resource name based on type
# Usage: local.name["virtual_network"] or local.name["kubernetes_cluster"]
locals {
  # Base name without instance
  base_name = "${var.naming_org}-${var.naming_env}-${var.naming_region}"

  # Full name with optional instance
  full_name = var.naming_instance != "" ? "${local.base_name}-${var.naming_instance}" : local.base_name

  # Generate names for all resource types
  name = {
    for type, abbrev in local.resource_type_abbreviations :
    type => var.naming_instance != "" ? "${local.base_name}-${abbrev}-${var.naming_instance}" : "${local.base_name}-${abbrev}"
  }

  # Short region abbreviation for resources with length constraints
  region_short = lookup(local.region_abbreviations, var.naming_region, substr(var.naming_region, 0, 4))

  # Short names for resources with strict length limits (e.g., storage accounts - 24 chars max, lowercase, no hyphens)
  name_short = {
    storage_account    = lower(replace("${var.naming_org}${var.naming_env}${local.region_short}st${var.naming_instance}", "-", ""))
    container_registry = lower(replace("${var.naming_org}${var.naming_env}${local.region_short}acr${var.naming_instance}", "-", ""))
    key_vault          = "${var.naming_org}-${var.naming_env}-${local.region_short}-kv${var.naming_instance != "" ? "-${var.naming_instance}" : ""}"
  }
}

# Output the naming configuration for use in other modules
output "naming_prefix" {
  description = "Base naming prefix for resources"
  value       = local.base_name
}

output "resource_names" {
  description = "Map of resource type to generated name"
  value       = local.name
}

output "resource_names_short" {
  description = "Map of resource type to short name (for length-constrained resources)"
  value       = local.name_short
}

output "resource_type_abbreviations" {
  description = "Map of resource types to their abbreviations"
  value       = local.resource_type_abbreviations
}
