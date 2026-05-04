# Observability Module - Application Insights
#
# This file creates Application Insights with:
# - Linked to Log Analytics Workspace
# - Sampling configuration for trace volume management

#------------------------------------------------------------------------------
# Application Insights
#------------------------------------------------------------------------------

resource "azurerm_application_insights" "main" {
  name                = var.app_insights_name
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = var.app_insights_application_type

  # Sampling configuration
  sampling_percentage = var.app_insights_sampling_percentage

  # Daily cap
  daily_data_cap_in_gb = var.app_insights_daily_data_cap_in_gb

  tags = var.tags
}
