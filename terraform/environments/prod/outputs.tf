# Production Environment - Outputs
#
# Output values for the production environment.

#------------------------------------------------------------------------------
# Resource Group Outputs
#------------------------------------------------------------------------------

output "resource_groups" {
  description = "Map of resource group names"
  value = {
    hub           = azurerm_resource_group.hub.name
    spoke         = azurerm_resource_group.spoke.name
    aks           = azurerm_resource_group.aks.name
    security      = azurerm_resource_group.security.name
    data          = azurerm_resource_group.data.name
    observability = azurerm_resource_group.observability.name
  }
}

#------------------------------------------------------------------------------
# Network Outputs
#------------------------------------------------------------------------------

output "hub_vnet_id" {
  description = "ID of the hub VNet"
  value       = module.hub_network.vnet_id
}

output "spoke_vnet_id" {
  description = "ID of the spoke VNet"
  value       = module.spoke_network.vnet_id
}

output "firewall_private_ip" {
  description = "Private IP of the Azure Firewall"
  value       = module.hub_network.firewall_private_ip
}

#------------------------------------------------------------------------------
# AKS Outputs
#------------------------------------------------------------------------------

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = module.aks.cluster_id
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.cluster_name
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = module.aks.cluster_fqdn
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL for Workload Identity"
  value       = module.aks.oidc_issuer_url
}

output "aks_node_resource_group" {
  description = "Name of the AKS node resource group"
  value       = module.aks.node_resource_group
}

#------------------------------------------------------------------------------
# Security Outputs
#------------------------------------------------------------------------------

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = module.security.key_vault_id
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = module.security.key_vault_uri
}

#------------------------------------------------------------------------------
# Data Outputs
#------------------------------------------------------------------------------

output "acr_login_server" {
  description = "Login server of the ACR"
  value       = module.data.acr_login_server
}

output "postgresql_fqdn" {
  description = "FQDN of the PostgreSQL server"
  value       = module.data.postgresql_fqdn
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = module.data.storage_account_name
}

#------------------------------------------------------------------------------
# Observability Outputs
#------------------------------------------------------------------------------

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = module.observability.log_analytics_workspace_id
}

output "app_insights_connection_string" {
  description = "Connection string for Application Insights"
  value       = module.observability.app_insights_connection_string
  sensitive   = true
}
