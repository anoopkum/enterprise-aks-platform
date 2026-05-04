# Hub Network Module - Main Configuration
#
# This module creates the hub virtual network with:
# - Hub VNet with DDoS Protection
# - Azure Firewall with policy rules
# - Azure Bastion for secure access
# - VPN Gateway subnet (optional)
# - Private DNS zones for Azure PaaS services

#------------------------------------------------------------------------------
# DDoS Protection Plan
#------------------------------------------------------------------------------

resource "azurerm_network_ddos_protection_plan" "main" {
  count = var.enable_ddos_protection && var.create_ddos_protection_plan ? 1 : 0

  name                = "${var.vnet_name}-ddos"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

#------------------------------------------------------------------------------
# Hub Virtual Network
#------------------------------------------------------------------------------

resource "azurerm_virtual_network" "hub" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space

  # DDoS Protection - use existing plan ID or newly created one
  dynamic "ddos_protection_plan" {
    for_each = var.enable_ddos_protection ? [1] : []
    content {
      id     = var.ddos_protection_plan_id != null ? var.ddos_protection_plan_id : azurerm_network_ddos_protection_plan.main[0].id
      enable = true
    }
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# Azure Firewall Subnet
# Note: Must be named "AzureFirewallSubnet" - this is an Azure requirement
#------------------------------------------------------------------------------

resource "azurerm_subnet" "firewall" {
  count = var.enable_firewall ? 1 : 0

  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.firewall_subnet_prefix]
}

#------------------------------------------------------------------------------
# Azure Bastion Subnet
# Note: Must be named "AzureBastionSubnet" - this is an Azure requirement
#------------------------------------------------------------------------------

resource "azurerm_subnet" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.bastion_subnet_prefix]
}

#------------------------------------------------------------------------------
# VPN Gateway Subnet
# Note: Must be named "GatewaySubnet" - this is an Azure requirement
#------------------------------------------------------------------------------

resource "azurerm_subnet" "gateway" {
  count = var.enable_vpn_gateway ? 1 : 0

  name                 = "GatewaySubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.gateway_subnet_prefix]
}

#------------------------------------------------------------------------------
# Management Subnet (Optional)
#------------------------------------------------------------------------------

resource "azurerm_subnet" "management" {
  name                 = "ManagementSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.management_subnet_prefix]
}

#------------------------------------------------------------------------------
# Azure Firewall Public IP
#------------------------------------------------------------------------------

resource "azurerm_public_ip" "firewall" {
  count = var.enable_firewall ? 1 : 0

  name                = "${var.vnet_name}-afw-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.firewall_zones

  tags = var.tags
}

#------------------------------------------------------------------------------
# Azure Firewall Policy
#------------------------------------------------------------------------------

resource "azurerm_firewall_policy" "main" {
  count = var.enable_firewall ? 1 : 0

  name                = "${var.vnet_name}-afw-policy"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.firewall_sku_tier

  threat_intelligence_mode = var.firewall_threat_intel_mode

  dns {
    proxy_enabled = true
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# Azure Firewall
#------------------------------------------------------------------------------

resource "azurerm_firewall" "main" {
  count = var.enable_firewall ? 1 : 0

  name                = "${var.vnet_name}-afw"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = var.firewall_sku_name
  sku_tier            = var.firewall_sku_tier
  firewall_policy_id  = azurerm_firewall_policy.main[0].id
  zones               = var.firewall_zones

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall[0].id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# Azure Bastion Public IP
#------------------------------------------------------------------------------

resource "azurerm_public_ip" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name                = "${var.vnet_name}-bas-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]

  tags = var.tags
}

#------------------------------------------------------------------------------
# Azure Bastion Host
#------------------------------------------------------------------------------

resource "azurerm_bastion_host" "main" {
  count = var.enable_bastion ? 1 : 0

  name                = "${var.vnet_name}-bas"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.bastion_sku

  # Standard SKU features
  tunneling_enabled      = var.bastion_sku == "Standard" ? var.bastion_tunneling_enabled : false
  copy_paste_enabled     = var.bastion_copy_paste_enabled
  file_copy_enabled      = var.bastion_sku == "Standard" ? var.bastion_file_copy_enabled : false
  ip_connect_enabled     = var.bastion_sku == "Standard" ? true : false
  shareable_link_enabled = var.bastion_sku == "Standard" ? true : false

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion[0].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# Diagnostic Settings - Azure Firewall
#------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "firewall" {
  count = var.enable_firewall && var.enable_diagnostic_settings ? 1 : 0

  name                       = "${azurerm_firewall.main[0].name}-diag"
  target_resource_id         = azurerm_firewall.main[0].id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AzureFirewallApplicationRule"
  }

  enabled_log {
    category = "AzureFirewallNetworkRule"
  }

  enabled_log {
    category = "AzureFirewallDnsProxy"
  }

  enabled_log {
    category = "AZFWApplicationRule"
  }

  enabled_log {
    category = "AZFWNetworkRule"
  }

  enabled_log {
    category = "AZFWNatRule"
  }

  enabled_log {
    category = "AZFWThreatIntel"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

#------------------------------------------------------------------------------
# Diagnostic Settings - Bastion
#------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "bastion" {
  count = var.enable_bastion && var.enable_diagnostic_settings ? 1 : 0

  name                       = "${azurerm_bastion_host.main[0].name}-diag"
  target_resource_id         = azurerm_bastion_host.main[0].id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "BastionAuditLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

#------------------------------------------------------------------------------
# Diagnostic Settings - Virtual Network
#------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "vnet" {
  count = var.enable_diagnostic_settings ? 1 : 0

  name                       = "${azurerm_virtual_network.hub.name}-diag"
  target_resource_id         = azurerm_virtual_network.hub.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
