# Data Module - Outputs
#
# Output values for use by other modules.

#------------------------------------------------------------------------------
# ACR Outputs
#------------------------------------------------------------------------------

output "acr_id" {
  description = "ID of the Azure Container Registry"
  value       = azurerm_container_registry.main.id
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.main.name
}

output "acr_login_server" {
  description = "Login server URL of the Azure Container Registry"
  value       = azurerm_container_registry.main.login_server
}

output "acr_admin_username" {
  description = "Admin username of the Azure Container Registry"
  value       = var.acr_admin_enabled ? azurerm_container_registry.main.admin_username : null
  sensitive   = true
}

output "acr_admin_password" {
  description = "Admin password of the Azure Container Registry"
  value       = var.acr_admin_enabled ? azurerm_container_registry.main.admin_password : null
  sensitive   = true
}

output "acr_private_endpoint_id" {
  description = "ID of the ACR private endpoint"
  value       = var.acr_sku == "Premium" ? azurerm_private_endpoint.acr[0].id : null
}

#------------------------------------------------------------------------------
# PostgreSQL Outputs
#------------------------------------------------------------------------------

output "postgresql_server_id" {
  description = "ID of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.main.id
}

output "postgresql_server_name" {
  description = "Name of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.main.name
}

output "postgresql_fqdn" {
  description = "FQDN of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "postgresql_administrator_login" {
  description = "Administrator login of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.main.administrator_login
  sensitive   = true
}

output "postgresql_administrator_password" {
  description = "Administrator password of the PostgreSQL Flexible Server"
  value       = var.postgresql_administrator_password != null ? var.postgresql_administrator_password : random_password.postgresql[0].result
  sensitive   = true
}

output "postgresql_connection_string" {
  description = "Connection string for PostgreSQL (direct)"
  value       = "postgresql://${azurerm_postgresql_flexible_server.main.administrator_login}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/postgres?sslmode=require"
  sensitive   = true
}

output "postgresql_pgbouncer_connection_string" {
  description = "Connection string for PostgreSQL via PgBouncer"
  value       = "postgresql://${azurerm_postgresql_flexible_server.main.administrator_login}@${azurerm_postgresql_flexible_server.main.fqdn}:6432/postgres?sslmode=require"
  sensitive   = true
}

#------------------------------------------------------------------------------
# Storage Account Outputs
#------------------------------------------------------------------------------

output "storage_account_id" {
  description = "ID of the Storage Account"
  value       = var.create_storage_account && var.storage_account_name != null ? azurerm_storage_account.main[0].id : null
}

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = var.create_storage_account && var.storage_account_name != null ? azurerm_storage_account.main[0].name : null
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint of the Storage Account"
  value       = var.create_storage_account && var.storage_account_name != null ? azurerm_storage_account.main[0].primary_blob_endpoint : null
}

output "storage_account_primary_access_key" {
  description = "Primary access key of the Storage Account"
  value       = var.create_storage_account && var.storage_account_name != null ? azurerm_storage_account.main[0].primary_access_key : null
  sensitive   = true
}

output "storage_account_private_endpoint_id" {
  description = "ID of the Storage Account private endpoint"
  value       = var.create_storage_account && var.storage_account_name != null ? azurerm_private_endpoint.storage_blob[0].id : null
}
