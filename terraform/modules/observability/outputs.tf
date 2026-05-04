# Observability Module - Outputs
#
# Output values for use by other modules.

#------------------------------------------------------------------------------
# Log Analytics Workspace Outputs
#------------------------------------------------------------------------------

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

output "log_analytics_workspace_primary_shared_key" {
  description = "Primary shared key of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.primary_shared_key
  sensitive   = true
}

output "log_analytics_workspace_secondary_shared_key" {
  description = "Secondary shared key of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.secondary_shared_key
  sensitive   = true
}

output "log_analytics_workspace_workspace_id" {
  description = "Workspace ID (GUID) of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.workspace_id
}

#------------------------------------------------------------------------------
# Application Insights Outputs
#------------------------------------------------------------------------------

output "app_insights_id" {
  description = "ID of the Application Insights resource"
  value       = azurerm_application_insights.main.id
}

output "app_insights_name" {
  description = "Name of the Application Insights resource"
  value       = azurerm_application_insights.main.name
}

output "app_insights_app_id" {
  description = "Application ID of the Application Insights resource"
  value       = azurerm_application_insights.main.app_id
}

output "app_insights_instrumentation_key" {
  description = "Instrumentation key of the Application Insights resource"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "app_insights_connection_string" {
  description = "Connection string of the Application Insights resource"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

#------------------------------------------------------------------------------
# Action Group Outputs
#------------------------------------------------------------------------------

output "action_group_pagerduty_id" {
  description = "ID of the PagerDuty action group"
  value       = var.create_alerts && var.pagerduty_integration_key != null ? azurerm_monitor_action_group.pagerduty[0].id : null
  sensitive   = true
}

output "action_group_teams_id" {
  description = "ID of the Teams action group"
  value       = var.create_alerts && var.teams_webhook_url != null ? azurerm_monitor_action_group.teams[0].id : null
  sensitive   = true
}

output "action_group_email_id" {
  description = "ID of the email action group"
  value       = var.create_alerts && length(var.alert_email_receivers) > 0 ? azurerm_monitor_action_group.email[0].id : null
}
