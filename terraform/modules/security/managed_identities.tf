# Security Module - Managed Identities
#
# This file creates user-assigned managed identities for:
# - AKS control plane
# - Kubelet (node pool identity)

#------------------------------------------------------------------------------
# AKS Control Plane Identity
#------------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "aks" {
  count = var.create_aks_identity ? 1 : 0

  name                = var.aks_identity_name != null ? var.aks_identity_name : "${var.key_vault_name}-aks-id"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

#------------------------------------------------------------------------------
# Kubelet Identity
#------------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "kubelet" {
  count = var.create_kubelet_identity ? 1 : 0

  name                = var.kubelet_identity_name != null ? var.kubelet_identity_name : "${var.key_vault_name}-kubelet-id"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

#------------------------------------------------------------------------------
# Role Assignment - AKS Identity can manage Kubelet Identity
# Required for AKS to assign the kubelet identity to node pools
#------------------------------------------------------------------------------

resource "azurerm_role_assignment" "aks_kubelet_identity_operator" {
  count = var.create_aks_identity && var.create_kubelet_identity ? 1 : 0

  scope                = azurerm_user_assigned_identity.kubelet[0].id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.aks[0].principal_id
}
