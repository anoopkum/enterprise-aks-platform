# Hub Network Module - Outputs
#
# Output values for use by other modules (spoke network, AKS, etc.)

#------------------------------------------------------------------------------
# Virtual Network Outputs
#------------------------------------------------------------------------------

output "vnet_id" {
  description = "ID of the hub virtual network"
  value       = azurerm_virtual_network.hub.id
}

output "vnet_name" {
  description = "Name of the hub virtual network"
  value       = azurerm_virtual_network.hub.name
}

output "vnet_address_space" {
  description = "Address space of the hub virtual network"
  value       = azurerm_virtual_network.hub.address_space
}

output "vnet_resource_group_name" {
  description = "Resource group name of the hub virtual network"
  value       = azurerm_virtual_network.hub.resource_group_name
}

#------------------------------------------------------------------------------
# Subnet Outputs
#------------------------------------------------------------------------------

output "firewall_subnet_id" {
  description = "ID of the Azure Firewall subnet"
  value       = var.enable_firewall ? azurerm_subnet.firewall[0].id : null
}

output "bastion_subnet_id" {
  description = "ID of the Azure Bastion subnet"
  value       = var.enable_bastion ? azurerm_subnet.bastion[0].id : null
}

output "gateway_subnet_id" {
  description = "ID of the VPN Gateway subnet"
  value       = var.enable_vpn_gateway ? azurerm_subnet.gateway[0].id : null
}

output "management_subnet_id" {
  description = "ID of the management subnet"
  value       = azurerm_subnet.management.id
}

#------------------------------------------------------------------------------
# Azure Firewall Outputs
#------------------------------------------------------------------------------

output "firewall_id" {
  description = "ID of the Azure Firewall"
  value       = var.enable_firewall ? azurerm_firewall.main[0].id : null
}

output "firewall_name" {
  description = "Name of the Azure Firewall"
  value       = var.enable_firewall ? azurerm_firewall.main[0].name : null
}

output "firewall_private_ip" {
  description = "Private IP address of the Azure Firewall (used for UDR)"
  value       = var.enable_firewall ? azurerm_firewall.main[0].ip_configuration[0].private_ip_address : null
}

output "firewall_public_ip" {
  description = "Public IP address of the Azure Firewall"
  value       = var.enable_firewall ? azurerm_public_ip.firewall[0].ip_address : null
}

output "firewall_policy_id" {
  description = "ID of the Azure Firewall Policy"
  value       = var.enable_firewall ? azurerm_firewall_policy.main[0].id : null
}

#------------------------------------------------------------------------------
# Azure Bastion Outputs
#------------------------------------------------------------------------------

output "bastion_id" {
  description = "ID of the Azure Bastion host"
  value       = var.enable_bastion ? azurerm_bastion_host.main[0].id : null
}

output "bastion_name" {
  description = "Name of the Azure Bastion host"
  value       = var.enable_bastion ? azurerm_bastion_host.main[0].name : null
}

output "bastion_dns_name" {
  description = "DNS name of the Azure Bastion host"
  value       = var.enable_bastion ? azurerm_bastion_host.main[0].dns_name : null
}

#------------------------------------------------------------------------------
# DDoS Protection Outputs
#------------------------------------------------------------------------------

output "ddos_protection_plan_id" {
  description = "ID of the DDoS Protection Plan"
  value       = var.enable_ddos_protection && var.create_ddos_protection_plan ? azurerm_network_ddos_protection_plan.main[0].id : var.ddos_protection_plan_id
}

#------------------------------------------------------------------------------
# Private DNS Zone Outputs
#------------------------------------------------------------------------------

output "private_dns_zone_ids" {
  description = "Map of Private DNS zone names to their IDs"
  value       = var.create_private_dns_zones ? { for zone in azurerm_private_dns_zone.main : zone.name => zone.id } : {}
}

output "private_dns_zone_names" {
  description = "List of Private DNS zone names"
  value       = var.create_private_dns_zones ? [for zone in azurerm_private_dns_zone.main : zone.name] : []
}
