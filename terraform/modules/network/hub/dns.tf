# Hub Network Module - Private DNS Zones
#
# This file creates Private DNS zones for Azure PaaS services
# and links them to the hub virtual network.

#------------------------------------------------------------------------------
# Local Variables
#------------------------------------------------------------------------------

locals {
  # AKS private DNS zone must be region-specific
  aks_private_dns_zone_name = coalesce(var.aks_private_dns_zone_name, "privatelink.${var.location}.azmk8s.io")

  # Combine all private DNS zones
  all_private_dns_zones = var.create_private_dns_zones ? concat(var.private_dns_zones, [local.aks_private_dns_zone_name]) : []
}

#------------------------------------------------------------------------------
# Private DNS Zones
#------------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "main" {
  for_each = var.create_private_dns_zones ? toset(var.private_dns_zones) : toset([])

  name                = each.value
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# AKS Private DNS Zone (region-specific)
resource "azurerm_private_dns_zone" "aks" {
  count = var.create_private_dns_zones ? 1 : 0

  name                = local.aks_private_dns_zone_name
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

# AKS Private DNS Zone VNet Link
resource "azurerm_private_dns_zone_virtual_network_link" "aks" {
  count = var.create_private_dns_zones ? 1 : 0

  name                  = "${var.vnet_name}-aks-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.aks[0].name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false

  tags = var.tags
}
