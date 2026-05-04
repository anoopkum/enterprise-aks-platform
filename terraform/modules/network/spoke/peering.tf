# Spoke Network Module - VNet Peering
#
# This file creates bidirectional VNet peering between hub and spoke
# with gateway transit configuration.

#------------------------------------------------------------------------------
# VNet Peering - Spoke to Hub
#------------------------------------------------------------------------------

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "${var.vnet_name}-to-hub"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = var.hub_vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = var.allow_forwarded_traffic
  use_remote_gateways          = var.use_remote_gateways
}

#------------------------------------------------------------------------------
# VNet Peering - Hub to Spoke
#------------------------------------------------------------------------------

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "hub-to-${var.vnet_name}"
  resource_group_name       = var.hub_resource_group_name
  virtual_network_name      = var.hub_vnet_name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = var.allow_forwarded_traffic
  allow_gateway_transit        = var.enable_gateway_transit
}

#------------------------------------------------------------------------------
# Private DNS Zone VNet Links - Spoke
#------------------------------------------------------------------------------

resource "azurerm_private_dns_zone_virtual_network_link" "spoke" {
  for_each = var.private_dns_zone_ids

  name                  = "${var.vnet_name}-link"
  resource_group_name   = var.hub_resource_group_name
  private_dns_zone_name = each.key
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false

  tags = var.tags
}
