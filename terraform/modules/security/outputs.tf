# Security Module - Outputs
#
# Output values for use by other modules (AKS, data, etc.)

#------------------------------------------------------------------------------
# Key Vault Outputs
#------------------------------------------------------------------------------

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "key_vault_resource_group_name" {
  description = "Resource group name of the Key Vault"
  value       = azurerm_key_vault.main.resource_group_name
}

output "key_vault_tenant_id" {
  description = "Tenant ID of the Key Vault"
  value       = azurerm_key_vault.main.tenant_id
}

#------------------------------------------------------------------------------
# Key Vault Private Endpoint Outputs
#------------------------------------------------------------------------------

output "key_vault_private_endpoint_id" {
  description = "ID of the Key Vault private endpoint"
  value       = var.create_key_vault_private_endpoint ? azurerm_private_endpoint.key_vault[0].id : null
}

output "key_vault_private_ip_address" {
  description = "Private IP address of the Key Vault private endpoint"
  value       = var.create_key_vault_private_endpoint ? azurerm_private_endpoint.key_vault[0].private_service_connection[0].private_ip_address : null
}

#------------------------------------------------------------------------------
# AKS Identity Outputs
#------------------------------------------------------------------------------

output "aks_identity_id" {
  description = "ID of the AKS control plane managed identity"
  value       = var.create_aks_identity ? azurerm_user_assigned_identity.aks[0].id : null
}

output "aks_identity_principal_id" {
  description = "Principal ID of the AKS control plane managed identity"
  value       = var.create_aks_identity ? azurerm_user_assigned_identity.aks[0].principal_id : null
}

output "aks_identity_client_id" {
  description = "Client ID of the AKS control plane managed identity"
  value       = var.create_aks_identity ? azurerm_user_assigned_identity.aks[0].client_id : null
}

output "aks_identity_name" {
  description = "Name of the AKS control plane managed identity"
  value       = var.create_aks_identity ? azurerm_user_assigned_identity.aks[0].name : null
}

#------------------------------------------------------------------------------
# Kubelet Identity Outputs
#------------------------------------------------------------------------------

output "kubelet_identity_id" {
  description = "ID of the kubelet managed identity"
  value       = var.create_kubelet_identity ? azurerm_user_assigned_identity.kubelet[0].id : null
}

output "kubelet_identity_principal_id" {
  description = "Principal ID of the kubelet managed identity"
  value       = var.create_kubelet_identity ? azurerm_user_assigned_identity.kubelet[0].principal_id : null
}

output "kubelet_identity_client_id" {
  description = "Client ID of the kubelet managed identity"
  value       = var.create_kubelet_identity ? azurerm_user_assigned_identity.kubelet[0].client_id : null
}

output "kubelet_identity_name" {
  description = "Name of the kubelet managed identity"
  value       = var.create_kubelet_identity ? azurerm_user_assigned_identity.kubelet[0].name : null
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet managed identity (same as principal_id)"
  value       = var.create_kubelet_identity ? azurerm_user_assigned_identity.kubelet[0].principal_id : null
}

#------------------------------------------------------------------------------
# Private Endpoint Configuration Outputs
#------------------------------------------------------------------------------

output "private_endpoint_subresources" {
  description = "Map of Azure service types to their private endpoint subresource names"
  value       = local.private_endpoint_subresources
}

output "private_dns_zones_map" {
  description = "Map of Azure service types to their private DNS zone names"
  value       = local.private_dns_zones
}
