# Observability Module - Log Analytics Workspace
#
# This file creates Log Analytics Workspace with:
# - 90-day retention
# - Container Insights solution
# - Archive configuration for compliance

#------------------------------------------------------------------------------
# Log Analytics Workspace
#------------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "main" {
  name                = var.log_analytics_workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_analytics_retention_in_days
  daily_quota_gb      = var.log_analytics_daily_quota_gb

  tags = var.tags
}

#------------------------------------------------------------------------------
# Container Insights Solution
#------------------------------------------------------------------------------

resource "azurerm_log_analytics_solution" "container_insights" {
  solution_name         = "ContainerInsights"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# Log Analytics Data Export (for long-term archive)
# Note: Requires a storage account - configure separately if needed
#------------------------------------------------------------------------------

# Uncomment and configure if you need data export to storage
# resource "azurerm_log_analytics_data_export_rule" "archive" {
#   name                    = "${var.log_analytics_workspace_name}-archive"
#   resource_group_name     = var.resource_group_name
#   workspace_resource_id   = azurerm_log_analytics_workspace.main.id
#   destination_resource_id = var.archive_storage_account_id
#   table_names             = ["ContainerLog", "KubeEvents", "KubePodInventory"]
#   enabled                 = true
# }
