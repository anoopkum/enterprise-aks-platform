# Data Module - Azure Storage Account
#
# This file creates Storage Account with:
# - GRS replication
# - Versioning and soft delete
# - Private endpoint
# - Lifecycle policies

#------------------------------------------------------------------------------
# Azure Storage Account
#------------------------------------------------------------------------------

resource "azurerm_storage_account" "main" {
  count = var.create_storage_account && var.storage_account_name != null ? 1 : 0

  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.location

  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication_type
  account_kind             = "StorageV2"

  # Security settings
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = var.storage_account_public_network_access_enabled

  # Blob properties
  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# Storage Account Private Endpoint
#------------------------------------------------------------------------------

resource "azurerm_private_endpoint" "storage_blob" {
  count = var.create_storage_account && var.storage_account_name != null ? 1 : 0

  name                = "${var.storage_account_name}-blob-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.storage_account_name}-blob-psc"
    private_connection_resource_id = azurerm_storage_account.main[0].id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = lookup(var.private_dns_zone_ids, "privatelink.blob.core.windows.net", null) != null ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = [var.private_dns_zone_ids["privatelink.blob.core.windows.net"]]
    }
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# Storage Account Lifecycle Policy
#------------------------------------------------------------------------------

resource "azurerm_storage_management_policy" "main" {
  count = var.create_storage_account && var.storage_account_name != null ? 1 : 0

  storage_account_id = azurerm_storage_account.main[0].id

  rule {
    name    = "move-to-cool"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = 30
      }
    }
  }

  rule {
    name    = "move-to-archive"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_archive_after_days_since_modification_greater_than = 90
      }
    }
  }

  rule {
    name    = "delete-old-versions"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      version {
        delete_after_days_since_creation = 365
      }
    }
  }
}

#------------------------------------------------------------------------------
# Storage Account Diagnostic Settings
#------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "storage" {
  count = var.create_storage_account && var.storage_account_name != null && var.enable_diagnostic_settings && var.log_analytics_workspace_id != null ? 1 : 0

  name                       = "${azurerm_storage_account.main[0].name}-diag"
  target_resource_id         = "${azurerm_storage_account.main[0].id}/blobServices/default"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
    enabled  = true
  }
}
