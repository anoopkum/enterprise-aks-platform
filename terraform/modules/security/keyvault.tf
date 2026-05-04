# Security Module - Key Vault
#
# This file creates Azure Key Vault with:
# - Premium SKU with HSM-backed keys
# - Purge protection and soft delete
# - Private endpoint (no public access)
# - RBAC authorization

#------------------------------------------------------------------------------
# Data Sources
#------------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

#------------------------------------------------------------------------------
# Key Vault
#------------------------------------------------------------------------------

resource "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  sku_name = var.key_vault_sku

  # Security settings
  enabled_for_deployment          = false
  enabled_for_disk_encryption     = false
  enabled_for_template_deployment = false
  enable_rbac_authorization       = var.key_vault_enable_rbac_authorization
  purge_protection_enabled        = var.key_vault_purge_protection_enabled
  soft_delete_retention_days      = var.key_vault_soft_delete_retention_days

  # Network settings
  public_network_access_enabled = var.key_vault_public_network_access_enabled

  network_acls {
    default_action = var.key_vault_network_acls_default_action
    bypass         = var.key_vault_network_acls_bypass
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# Key Vault Private Endpoint
#------------------------------------------------------------------------------

resource "azurerm_private_endpoint" "key_vault" {
  count = var.create_key_vault_private_endpoint ? 1 : 0

  name                = "${var.key_vault_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.key_vault_name}-psc"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = lookup(var.private_dns_zone_ids, "privatelink.vaultcore.azure.net", null) != null ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = [var.private_dns_zone_ids["privatelink.vaultcore.azure.net"]]
    }
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# Key Vault RBAC Role Assignments - Admin Access
#------------------------------------------------------------------------------

resource "azurerm_role_assignment" "key_vault_admin" {
  for_each = var.key_vault_enable_rbac_authorization ? toset(var.admin_object_ids) : toset([])

  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = each.value
}

#------------------------------------------------------------------------------
# Key Vault RBAC Role Assignments - AKS Identity
#------------------------------------------------------------------------------

resource "azurerm_role_assignment" "aks_secrets_user" {
  count = var.key_vault_enable_rbac_authorization && var.create_aks_identity ? 1 : 0

  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.aks[0].principal_id
}

resource "azurerm_role_assignment" "kubelet_secrets_user" {
  count = var.key_vault_enable_rbac_authorization && var.create_kubelet_identity ? 1 : 0

  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.kubelet[0].principal_id
}

#------------------------------------------------------------------------------
# Key Vault Diagnostic Settings
#------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  count = var.enable_diagnostic_settings ? 1 : 0

  name                       = "${azurerm_key_vault.main.name}-diag"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_log {
    category = "AzurePolicyEvaluationDetails"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
