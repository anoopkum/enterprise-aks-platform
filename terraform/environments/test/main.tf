# Test Environment - Main Configuration
#
# This file composes all modules for the test environment with
# production-like settings for testing.

locals {
  environment = "test"
  region      = var.location
  org         = var.org

  common_tags = {
    Environment = local.environment
    Owner       = var.owner_email
    CostCenter  = var.cost_center
    Application = "enterprise-aks-platform"
    ManagedBy   = "terraform"
    Repository  = "https://github.com/${var.org}/aks-platform"
  }
}

#------------------------------------------------------------------------------
# Resource Groups
#------------------------------------------------------------------------------

resource "azurerm_resource_group" "hub" {
  name     = "${local.org}-${local.environment}-${local.region}-rg-hub"
  location = local.region
  tags     = local.common_tags
}

resource "azurerm_resource_group" "spoke" {
  name     = "${local.org}-${local.environment}-${local.region}-rg-spoke"
  location = local.region
  tags     = local.common_tags
}

resource "azurerm_resource_group" "aks" {
  name     = "${local.org}-${local.environment}-${local.region}-rg-aks"
  location = local.region
  tags     = local.common_tags
}

resource "azurerm_resource_group" "security" {
  name     = "${local.org}-${local.environment}-${local.region}-rg-security"
  location = local.region
  tags     = local.common_tags
}

resource "azurerm_resource_group" "data" {
  name     = "${local.org}-${local.environment}-${local.region}-rg-data"
  location = local.region
  tags     = local.common_tags
}

resource "azurerm_resource_group" "observability" {
  name     = "${local.org}-${local.environment}-${local.region}-rg-observability"
  location = local.region
  tags     = local.common_tags
}

#------------------------------------------------------------------------------
# Observability Module
#------------------------------------------------------------------------------

module "observability" {
  source = "../../modules/observability"

  resource_group_name          = azurerm_resource_group.observability.name
  location                     = local.region
  log_analytics_workspace_name = "${local.org}-${local.environment}-${local.region}-law"
  app_insights_name            = "${local.org}-${local.environment}-${local.region}-ai"

  # Test: 60-day retention
  log_analytics_retention_in_days = 60

  # Alerts enabled
  create_alerts         = true
  alert_email_receivers = [for email in var.budget_alert_emails : { name = split("@", email)[0], email_address = email }]

  tags = local.common_tags
}

#------------------------------------------------------------------------------
# Hub Network Module
#------------------------------------------------------------------------------

module "hub_network" {
  source = "../../modules/network/hub"

  resource_group_name = azurerm_resource_group.hub.name
  location            = local.region
  vnet_name           = "${local.org}-${local.environment}-${local.region}-vnet-hub"
  vnet_address_space  = var.hub_vnet_address_space

  # Test: DDoS protection disabled for cost
  enable_ddos_protection = false

  # Enable Firewall and Bastion
  enable_firewall = true
  enable_bastion  = true
  bastion_sku     = "Standard"

  # VPN Gateway disabled
  enable_vpn_gateway = false

  # Private DNS zones
  create_private_dns_zones = true

  # Diagnostic settings
  log_analytics_workspace_id = module.observability.log_analytics_workspace_id
  enable_diagnostic_settings = true

  tags = local.common_tags
}

#------------------------------------------------------------------------------
# Spoke Network Module
#------------------------------------------------------------------------------

module "spoke_network" {
  source = "../../modules/network/spoke"

  resource_group_name = azurerm_resource_group.spoke.name
  location            = local.region
  vnet_name           = "${local.org}-${local.environment}-${local.region}-vnet-spoke"
  vnet_address_space  = var.spoke_vnet_address_space

  # Hub network configuration
  hub_vnet_id             = module.hub_network.vnet_id
  hub_vnet_name           = module.hub_network.vnet_name
  hub_resource_group_name = azurerm_resource_group.hub.name
  hub_firewall_private_ip = module.hub_network.firewall_private_ip

  # Private DNS zones
  private_dns_zone_ids = module.hub_network.private_dns_zone_ids

  # Network security
  enable_forced_tunneling = true
  enable_nsg              = true

  # Diagnostic settings
  log_analytics_workspace_id = module.observability.log_analytics_workspace_id
  enable_diagnostic_settings = true

  tags = local.common_tags
}

#------------------------------------------------------------------------------
# Security Module
#------------------------------------------------------------------------------

module "security" {
  source = "../../modules/security"

  resource_group_name = azurerm_resource_group.security.name
  location            = local.region
  key_vault_name      = "${local.org}-${local.environment}-kv"

  # Private endpoint
  private_endpoint_subnet_id = module.spoke_network.private_endpoints_subnet_id
  private_dns_zone_ids       = module.hub_network.private_dns_zone_ids

  # Managed identities
  create_aks_identity     = true
  create_kubelet_identity = true

  # Diagnostic settings
  log_analytics_workspace_id = module.observability.log_analytics_workspace_id
  enable_diagnostic_settings = true

  tags = local.common_tags
}

#------------------------------------------------------------------------------
# Data Module
#------------------------------------------------------------------------------

module "data" {
  source = "../../modules/data"

  resource_group_name = azurerm_resource_group.data.name
  location            = local.region

  # ACR - Premium for production-like testing
  acr_name = "${local.org}${local.environment}acr"
  acr_sku  = "Premium"

  # PostgreSQL - production-like settings
  postgresql_server_name           = "${local.org}-${local.environment}-${local.region}-psql"
  postgresql_sku_name              = "GP_Standard_D2s_v3"
  postgresql_ha_enabled            = true
  postgresql_backup_retention_days = 14

  # Private endpoints
  private_endpoint_subnet_id = module.spoke_network.private_endpoints_subnet_id
  private_dns_zone_ids       = module.hub_network.private_dns_zone_ids

  # Storage account
  create_storage_account = true
  storage_account_name   = "${local.org}${local.environment}st"

  # Diagnostic settings
  log_analytics_workspace_id = module.observability.log_analytics_workspace_id
  enable_diagnostic_settings = true

  tags = local.common_tags
}

#------------------------------------------------------------------------------
# AKS Module
#------------------------------------------------------------------------------

module "aks" {
  source = "../../modules/aks"

  resource_group_name = azurerm_resource_group.aks.name
  location            = local.region
  cluster_name        = "${local.org}-${local.environment}-${local.region}-aks"
  dns_prefix          = "${local.org}-${local.environment}-aks"
  kubernetes_version  = var.kubernetes_version

  # Test: Standard tier
  sku_tier = "Standard"

  # Network configuration
  vnet_subnet_id = module.spoke_network.aks_subnet_id

  # Private cluster with authorized IPs
  private_cluster_enabled             = true
  private_dns_zone_id                 = module.hub_network.private_dns_zone_ids["privatelink.azmk8s.io"]
  private_cluster_public_fqdn_enabled = true
  api_server_authorized_ip_ranges     = var.api_server_authorized_ip_ranges

  # Identity
  identity_type              = "UserAssigned"
  user_assigned_identity_id  = module.security.aks_identity_id
  kubelet_identity_client_id = module.security.kubelet_identity_client_id
  kubelet_identity_object_id = module.security.kubelet_identity_principal_id
  kubelet_identity_id        = module.security.kubelet_identity_id

  # Azure AD integration
  azure_rbac_enabled       = true
  local_account_disabled   = true
  azure_ad_admin_group_ids = var.aks_admin_group_ids

  # Test: production-like node pools
  system_node_pool = {
    name                         = "system"
    vm_size                      = "Standard_D4s_v5"
    node_count                   = 2
    min_count                    = 2
    max_count                    = 4
    availability_zones           = ["1", "2", "3"]
    os_disk_size_gb              = 128
    os_disk_type                 = "Ephemeral"
    only_critical_addons_enabled = true
    node_labels                  = {}
    node_taints                  = []
  }

  user_node_pools = {
    user = {
      name               = "user"
      vm_size            = "Standard_D4s_v5"
      node_count         = 2
      min_count          = 2
      max_count          = 10
      availability_zones = ["1", "2", "3"]
      os_disk_size_gb    = 256
      os_disk_type       = "Ephemeral"
      node_labels = {
        "workload-type" = "general"
      }
      node_taints = []
    }
  }

  # Addons
  azure_policy_enabled               = true
  oms_agent_enabled                  = true
  log_analytics_workspace_id         = module.observability.log_analytics_workspace_id
  key_vault_secrets_provider_enabled = true
  workload_identity_enabled          = true
  oidc_issuer_enabled                = true

  # ACR integration
  acr_id = module.data.acr_id

  tags = local.common_tags
}

#------------------------------------------------------------------------------
# Governance Module
#------------------------------------------------------------------------------

module "governance" {
  source = "../../modules/governance"

  subscription_id = var.subscription_id

  # Test: audit mode
  enable_policy_assignments = true
  policy_enforcement_mode   = "DoNotEnforce"

  # Budget
  enable_budget_alerts = length(var.budget_alert_emails) > 0
  monthly_budget       = var.monthly_budget
  budget_alert_emails  = var.budget_alert_emails

  tags = local.common_tags
}
