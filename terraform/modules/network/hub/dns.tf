# Hub Network Module - Private DNS Zones
#
# This file creates Private DNS zones for Azure PaaS services
# and links them to the hub virtual network.

#------------------------------------------------------------------------------
# Private DNS Zones
#------------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "main" {
  for_each = var.create_private_dns_zones ? toset(var.private_dns_zones) : toset([])

  name                = each.value
  resource_group_name = var.resource_group_name

  tags = var.tags
}

#------------------------------------------------------------------------------
# Private DNS Zone VNet Links - Hub
#------------------------------------------------------------------------------

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  for_each = var.create_private_dns_zones ? toset(var.private_dns_zones) : toset([])

  name                  = "${var.vnet_name}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.main[each.key].name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false

  tags = var.tags
}
