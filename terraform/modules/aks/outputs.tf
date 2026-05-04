# AKS Module - Outputs
#
# Output values for use by other modules and configurations.

#------------------------------------------------------------------------------
# Cluster Outputs
#------------------------------------------------------------------------------

output "cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.id
}

output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "cluster_private_fqdn" {
  description = "Private FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.private_fqdn
}

output "cluster_portal_fqdn" {
  description = "Portal FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.portal_fqdn
}

output "kubernetes_version" {
  description = "Kubernetes version of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.kubernetes_version
}

output "node_resource_group" {
  description = "Name of the node resource group"
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}

output "node_resource_group_id" {
  description = "ID of the node resource group"
  value       = azurerm_kubernetes_cluster.main.node_resource_group_id
}

#------------------------------------------------------------------------------
# Identity Outputs
#------------------------------------------------------------------------------

output "cluster_identity_principal_id" {
  description = "Principal ID of the AKS cluster identity"
  value       = azurerm_kubernetes_cluster.main.identity[0].principal_id
}

output "cluster_identity_tenant_id" {
  description = "Tenant ID of the AKS cluster identity"
  value       = azurerm_kubernetes_cluster.main.identity[0].tenant_id
}

output "kubelet_identity_client_id" {
  description = "Client ID of the kubelet identity"
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].client_id
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet identity"
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

output "kubelet_identity_user_assigned_identity_id" {
  description = "User assigned identity ID of the kubelet identity"
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].user_assigned_identity_id
}

#------------------------------------------------------------------------------
# OIDC Outputs
#------------------------------------------------------------------------------

output "oidc_issuer_url" {
  description = "OIDC issuer URL for Workload Identity"
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

#------------------------------------------------------------------------------
# Network Outputs
#------------------------------------------------------------------------------

output "network_profile" {
  description = "Network profile of the AKS cluster"
  value = {
    network_plugin      = azurerm_kubernetes_cluster.main.network_profile[0].network_plugin
    network_plugin_mode = azurerm_kubernetes_cluster.main.network_profile[0].network_plugin_mode
    network_policy      = azurerm_kubernetes_cluster.main.network_profile[0].network_policy
    service_cidr        = azurerm_kubernetes_cluster.main.network_profile[0].service_cidr
    dns_service_ip      = azurerm_kubernetes_cluster.main.network_profile[0].dns_service_ip
    pod_cidr            = azurerm_kubernetes_cluster.main.network_profile[0].pod_cidr
  }
}

#------------------------------------------------------------------------------
# Kubeconfig Outputs
#------------------------------------------------------------------------------

output "kube_config_raw" {
  description = "Raw kubeconfig for the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "kube_admin_config_raw" {
  description = "Raw admin kubeconfig for the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.kube_admin_config_raw
  sensitive   = true
}

output "host" {
  description = "Kubernetes API server host"
  value       = azurerm_kubernetes_cluster.main.kube_config[0].host
  sensitive   = true
}

output "client_certificate" {
  description = "Client certificate for Kubernetes API"
  value       = azurerm_kubernetes_cluster.main.kube_config[0].client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Client key for Kubernetes API"
  value       = azurerm_kubernetes_cluster.main.kube_config[0].client_key
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate for Kubernetes API"
  value       = azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate
  sensitive   = true
}

#------------------------------------------------------------------------------
# Node Pool Outputs
#------------------------------------------------------------------------------

output "system_node_pool_name" {
  description = "Name of the system node pool"
  value       = azurerm_kubernetes_cluster.main.default_node_pool[0].name
}

output "user_node_pool_ids" {
  description = "Map of user node pool names to their IDs"
  value       = { for k, v in azurerm_kubernetes_cluster_node_pool.user : k => v.id }
}

#------------------------------------------------------------------------------
# Key Vault Secrets Provider Outputs
#------------------------------------------------------------------------------

output "key_vault_secrets_provider_identity" {
  description = "Identity of the Key Vault Secrets Provider"
  value       = var.key_vault_secrets_provider_enabled ? azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity : null
}
