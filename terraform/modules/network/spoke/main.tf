# Spoke Network Module - Main Configuration
#
# This module creates the spoke virtual network with:
# - Spoke VNet with dedicated subnets
# - VNet peering with hub network
# - Network Security Groups
# - User Defined Routes for forced tunneling

#------------------------------------------------------------------------------
# Spoke Virtual Network
#------------------------------------------------------------------------------

resource "azurerm_virtual_network" "spoke" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space

  tags = var.tags
}

#------------------------------------------------------------------------------
# Diagnostic Settings - Virtual Network
#------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "vnet" {
  count = var.enable_diagnostic_settings && var.log_analytics_workspace_id != null ? 1 : 0

  name                       = "${azurerm_virtual_network.spoke.name}-diag"
  target_resource_id         = azurerm_virtual_network.spoke.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
