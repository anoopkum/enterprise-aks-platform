# AKS Module - RBAC Configuration
#
# This file creates role assignments for AKS cluster access
# and ACR integration.
#
# NOTE: Network Contributor and Private DNS Zone Contributor role assignments
# for the AKS identity must be created BEFORE the AKS cluster is provisioned.
# These are now handled in the environment's main.tf with explicit depends_on
# to avoid circular dependencies.

#------------------------------------------------------------------------------
# ACR Pull Role Assignment for Kubelet Identity
#------------------------------------------------------------------------------

resource "azurerm_role_assignment" "acr_pull" {
  count = var.enable_role_assignments && var.enable_acr_integration ? 1 : 0

  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = var.kubelet_identity_object_id
}
