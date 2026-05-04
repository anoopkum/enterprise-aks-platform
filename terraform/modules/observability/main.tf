# Observability Module - Main Configuration
#
# This module creates observability infrastructure including:
# - Log Analytics Workspace with Container Insights
# - Application Insights for APM
# - Azure Monitor alerts and action groups
#
# Resources are defined in separate files:
# - log_analytics.tf: Log Analytics Workspace and solutions
# - app_insights.tf: Application Insights
# - alerts.tf: Action groups and metric alerts

# This file serves as the module entry point.
# All resources are defined in their respective files.
