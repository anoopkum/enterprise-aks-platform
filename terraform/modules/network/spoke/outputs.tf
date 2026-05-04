# Spoke Network Module - Outputs
#
# Output values for use by other modules (AKS, security, etc.)

#------------------------------------------------------------------------------
# Virtual Network Outputs
#------------------------------------------------------------------------------

output "vnet_id" {
  description = "ID of the spoke virtual network"
  value       = azurerm_virtual_network.spoke.id
}

output "vnet_name" {
  description = "Name of the spoke virtual network"
  value       = azurerm_virtual_network.spoke.name
}

output "vnet_address_space" {
  description = "Address space of the spoke virtual network"
  value       = azurerm_virtual_network.spoke.address_space
}

output "vnet_resource_group_name" {
  description = "Resource group name of the spoke virtual network"
  value       = azurerm_virtual_network.spoke.resource_group_name
}

#------------------------------------------------------------------------------
# Subnet Outputs
#------------------------------------------------------------------------------

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = azurerm_subnet.aks.id
}

output "aks_subnet_name" {
  description = "Name of the AKS subnet"
  value       = azurerm_subnet.aks.name
}

output "aks_subnet_address_prefix" {
  description = "Address prefix of the AKS subnet"
  value       = azurerm_subnet.aks.address_prefixes[0]
}

output "aks_ilb_subnet_id" {
  description = "ID of the AKS internal load balancer subnet"
  value       = azurerm_subnet.aks_ilb.id
}

output "aks_ilb_subnet_name" {
  description = "Name of the AKS internal load balancer subnet"
  value       = azurerm_subnet.aks_ilb.name
}

output "private_endpoints_subnet_id" {
  description = "ID of the private endpoints subnet"
  value       = azurerm_subnet.private_endpoints.id
}

output "private_endpoints_subnet_name" {
  description = "Name of the private endpoints subnet"
  value       = azurerm_subnet.private_endpoints.name
}

output "app_gateway_subnet_id" {
  description = "ID of the Application Gateway subnet"
  value       = azurerm_subnet.app_gateway.id
}

output "app_gateway_subnet_name" {
  description = "Name of the Application Gateway subnet"
  value       = azurerm_subnet.app_gateway.name
}

#------------------------------------------------------------------------------
# Subnet IDs Map (for convenience)
#------------------------------------------------------------------------------

output "subnet_ids" {
  description = "Map of subnet names to their IDs"
  value = {
    aks               = azurerm_subnet.aks.id
    aks_ilb           = azurerm_subnet.aks_ilb.id
    private_endpoints = azurerm_subnet.private_endpoints.id
    app_gateway       = azurerm_subnet.app_gateway.id
  }
}

#------------------------------------------------------------------------------
# Network Security Group Outputs
#------------------------------------------------------------------------------

output "aks_nsg_id" {
  description = "ID of the AKS subnet NSG"
  value       = var.enable_nsg ? azurerm_network_security_group.aks[0].id : null
}

output "private_endpoints_nsg_id" {
  description = "ID of the private endpoints subnet NSG"
  value       = var.enable_nsg ? azurerm_network_security_group.private_endpoints[0].id : null
}

output "app_gateway_nsg_id" {
  description = "ID of the Application Gateway subnet NSG"
  value       = var.enable_nsg ? azurerm_network_security_group.app_gateway[0].id : null
}

#------------------------------------------------------------------------------
# Route Table Outputs
#------------------------------------------------------------------------------

output "aks_route_table_id" {
  description = "ID of the AKS subnet route table"
  value       = var.enable_forced_tunneling && var.hub_firewall_private_ip != null ? azurerm_route_table.aks[0].id : null
}

#------------------------------------------------------------------------------
# VNet Peering Outputs
#------------------------------------------------------------------------------

output "spoke_to_hub_peering_id" {
  description = "ID of the spoke-to-hub VNet peering"
  value       = azurerm_virtual_network_peering.spoke_to_hub.id
}

output "hub_to_spoke_peering_id" {
  description = "ID of the hub-to-spoke VNet peering"
  value       = azurerm_virtual_network_peering.hub_to_spoke.id
}
