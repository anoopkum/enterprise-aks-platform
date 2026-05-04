# AKS Module - RBAC Configuration
#
# This file creates role assignments for AKS cluster access
# and ACR integration.

#------------------------------------------------------------------------------
# ACR Pull Role Assignment for Kubelet Identity
#------------------------------------------------------------------------------

resource "azurerm_role_assignment" "acr_pull" {
  count = var.acr_id != null ? 1 : 0

  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = var.kubelet_identity_object_id
}

#------------------------------------------------------------------------------
# Network Contributor Role for AKS Identity on Subnet
# Required for AKS to manage load balancers and route tables
#------------------------------------------------------------------------------

resource "azurerm_role_assignment" "network_contributor" {
  count = var.identity_type == "UserAssigned" ? 1 : 0

  scope                = var.vnet_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id
}

#------------------------------------------------------------------------------
# Private DNS Zone Contributor for AKS Identity
# Required for AKS to manage DNS records in private DNS zone
#------------------------------------------------------------------------------

resource "azurerm_role_assignment" "private_dns_contributor" {
  count = var.private_cluster_enabled && var.identity_type == "UserAssigned" ? 1 : 0

  scope                = var.private_dns_zone_id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id
}
