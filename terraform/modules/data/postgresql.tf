# Data Module - Azure PostgreSQL Flexible Server
#
# This file creates PostgreSQL with:
# - Zone-redundant high availability
# - Private endpoint (no public access)
# - Automated backups with geo-redundant storage
# - PgBouncer connection pooling

#------------------------------------------------------------------------------
# Random Password for PostgreSQL Admin
#------------------------------------------------------------------------------

resource "random_password" "postgresql" {
  count = var.postgresql_administrator_password == null ? 1 : 0

  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

#------------------------------------------------------------------------------
# Azure PostgreSQL Flexible Server
#------------------------------------------------------------------------------

resource "azurerm_postgresql_flexible_server" "main" {
  name                = var.postgresql_server_name
  resource_group_name = var.resource_group_name
  location            = var.location

  # SKU and version
  sku_name   = var.postgresql_sku_name
  version    = var.postgresql_version
  storage_mb = var.postgresql_storage_mb

  # Administrator credentials
  administrator_login    = var.postgresql_administrator_login
  administrator_password = var.postgresql_administrator_password != null ? var.postgresql_administrator_password : random_password.postgresql[0].result

  # High availability
  dynamic "high_availability" {
    for_each = var.postgresql_ha_enabled ? [1] : []
    content {
      mode                      = "ZoneRedundant"
      standby_availability_zone = "2"
    }
  }

  # Backup configuration
  backup_retention_days        = var.postgresql_backup_retention_days
  geo_redundant_backup_enabled = var.postgresql_geo_redundant_backup_enabled

  # Network configuration (VNet integration)
  delegated_subnet_id = var.postgresql_delegated_subnet_id
  private_dns_zone_id = var.postgresql_private_dns_zone_id

  # Availability zone
  zone = "1"

  tags = var.tags

  lifecycle {
    ignore_changes = [
      # Ignore password changes after initial creation
      administrator_password,
      # Ignore zone changes during HA failover
      zone,
      high_availability[0].standby_availability_zone,
    ]
  }
}

#------------------------------------------------------------------------------
# PostgreSQL Server Configuration - SSL/TLS (MEDIUM: AZU-0026)
#------------------------------------------------------------------------------

resource "azurerm_postgresql_flexible_server_configuration" "require_secure_transport" {
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "ON"
}

resource "azurerm_postgresql_flexible_server_configuration" "ssl_min_protocol_version" {
  name      = "ssl_min_protocol_version"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "TLSv1.2"
}

#------------------------------------------------------------------------------
# PostgreSQL Server Configuration - PgBouncer
#------------------------------------------------------------------------------

resource "azurerm_postgresql_flexible_server_configuration" "pgbouncer_enabled" {
  name      = "pgbouncer.enabled"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "true"
}

resource "azurerm_postgresql_flexible_server_configuration" "pgbouncer_default_pool_size" {
  name      = "pgbouncer.default_pool_size"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "50"
}

resource "azurerm_postgresql_flexible_server_configuration" "pgbouncer_min_pool_size" {
  name      = "pgbouncer.min_pool_size"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "10"
}

resource "azurerm_postgresql_flexible_server_configuration" "pgbouncer_max_client_conn" {
  name      = "pgbouncer.max_client_conn"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "5000"
}

#------------------------------------------------------------------------------
# PostgreSQL Server Configuration - Performance
#------------------------------------------------------------------------------

resource "azurerm_postgresql_flexible_server_configuration" "log_checkpoints" {
  name      = "log_checkpoints"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "log_connections" {
  name      = "log_connections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "log_disconnections" {
  name      = "log_disconnections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

#------------------------------------------------------------------------------
# PostgreSQL Diagnostic Settings
#------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "postgresql" {
  count = var.enable_diagnostic_settings && var.log_analytics_workspace_id != null ? 1 : 0

  name                       = "${azurerm_postgresql_flexible_server.main.name}-diag"
  target_resource_id         = azurerm_postgresql_flexible_server.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "PostgreSQLLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
