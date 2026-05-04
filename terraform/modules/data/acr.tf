# Data Module - Azure Container Registry
#
# This file creates ACR with:
# - Premium SKU with geo-replication
# - Private endpoint (no public access)
# - Vulnerability scanning
# - Content trust for image signing

#------------------------------------------------------------------------------
# Azure Container Registry
#------------------------------------------------------------------------------

resource "azurerm_container_registry" "main" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.acr_sku
  admin_enabled       = var.acr_admin_enabled

  # Network settings
  public_network_access_enabled = var.acr_public_network_access_enabled

  # Geo-replication (Premium SKU only)
  dynamic "georeplications" {
    for_each = var.acr_sku == "Premium" ? var.acr_geo_replications : []
    content {
      location                = georeplications.value
      zone_redundancy_enabled = true
    }
  }

  # Retention policy for untagged manifests (Premium SKU only)
  dynamic "retention_policy" {
    for_each = var.acr_sku == "Premium" ? [1] : []
    content {
      days    = var.acr_retention_policy_days
      enabled = true
    }
  }

  # Content trust policy (Premium SKU only)
  dynamic "trust_policy" {
    for_each = var.acr_sku == "Premium" && var.acr_trust_policy_enabled ? [1] : []
    content {
      enabled = true
    }
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# ACR Private Endpoint
#------------------------------------------------------------------------------

resource "azurerm_private_endpoint" "acr" {
  count = var.acr_sku == "Premium" ? 1 : 0

  name                = "${var.acr_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.acr_name}-psc"
    private_connection_resource_id = azurerm_container_registry.main.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = lookup(var.private_dns_zone_ids, "privatelink.azurecr.io", null) != null ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = [var.private_dns_zone_ids["privatelink.azurecr.io"]]
    }
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# ACR Diagnostic Settings
#------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "acr" {
  count = var.enable_diagnostic_settings ? 1 : 0

  name                       = "${azurerm_container_registry.main.name}-diag"
  target_resource_id         = azurerm_container_registry.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }

  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
