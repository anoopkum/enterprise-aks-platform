# Spoke Network Module - Subnets
#
# This file creates dedicated subnets for:
# - AKS nodes
# - AKS internal load balancers
# - Private endpoints
# - Application Gateway

#------------------------------------------------------------------------------
# AKS Subnet
# Large subnet for AKS nodes with service endpoints
#------------------------------------------------------------------------------

resource "azurerm_subnet" "aks" {
  name                 = "AksSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.aks_subnet_prefix]

  service_endpoints = var.aks_subnet_service_endpoints
}

#------------------------------------------------------------------------------
# AKS Internal Load Balancer Subnet
#------------------------------------------------------------------------------

resource "azurerm_subnet" "aks_ilb" {
  name                 = "AksIlbSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.aks_ilb_subnet_prefix]
}

#------------------------------------------------------------------------------
# Private Endpoints Subnet
#------------------------------------------------------------------------------

resource "azurerm_subnet" "private_endpoints" {
  name                 = "PrivateEndpointsSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.private_endpoints_subnet_prefix]

  # Disable private endpoint network policies to allow private endpoints
  private_endpoint_network_policies = "Disabled"
}

#------------------------------------------------------------------------------
# Application Gateway Subnet
#------------------------------------------------------------------------------

resource "azurerm_subnet" "app_gateway" {
  name                 = "AppGatewaySubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.app_gateway_subnet_prefix]
}

#------------------------------------------------------------------------------
# User Defined Route - Forced Tunneling through Azure Firewall
#------------------------------------------------------------------------------

resource "azurerm_route_table" "aks" {
  count = var.enable_forced_tunneling && var.hub_firewall_private_ip != null ? 1 : 0

  name                          = "${var.vnet_name}-aks-rt"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  bgp_route_propagation_enabled = false

  tags = var.tags
}

resource "azurerm_route" "default_to_firewall" {
  count = var.enable_forced_tunneling && var.hub_firewall_private_ip != null ? 1 : 0

  name                   = "default-to-firewall"
  resource_group_name    = var.resource_group_name
  route_table_name       = azurerm_route_table.aks[0].name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.hub_firewall_private_ip
}

resource "azurerm_subnet_route_table_association" "aks" {
  count = var.enable_forced_tunneling && var.hub_firewall_private_ip != null ? 1 : 0

  subnet_id      = azurerm_subnet.aks.id
  route_table_id = azurerm_route_table.aks[0].id
}
