# Observability Module - Azure Monitor Alerts
#
# This file creates action groups and metric alerts for:
# - Node CPU/memory utilization
# - Pod restart count
# - API server availability
# - Cluster autoscaler status

#------------------------------------------------------------------------------
# Action Group - PagerDuty (Sev0)
#------------------------------------------------------------------------------

resource "azurerm_monitor_action_group" "pagerduty" {
  count = var.create_alerts && var.pagerduty_integration_key != null ? 1 : 0

  name                = "${var.alert_action_group_name}-pagerduty"
  resource_group_name = var.resource_group_name
  short_name          = "pagerduty"

  dynamic "email_receiver" {
    for_each = var.alert_email_receivers
    content {
      name          = email_receiver.value.name
      email_address = email_receiver.value.email_address
    }
  }

  webhook_receiver {
    name                    = "pagerduty"
    service_uri             = "https://events.pagerduty.com/integration/${var.pagerduty_integration_key}/enqueue"
    use_common_alert_schema = true
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# Action Group - Teams (Sev1-3)
#------------------------------------------------------------------------------

resource "azurerm_monitor_action_group" "teams" {
  count = var.create_alerts && var.teams_webhook_url != null ? 1 : 0

  name                = "${var.alert_action_group_name}-teams"
  resource_group_name = var.resource_group_name
  short_name          = "teams"

  dynamic "email_receiver" {
    for_each = var.alert_email_receivers
    content {
      name          = email_receiver.value.name
      email_address = email_receiver.value.email_address
    }
  }

  webhook_receiver {
    name                    = "teams"
    service_uri             = var.teams_webhook_url
    use_common_alert_schema = true
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# Action Group - Email Only (Default)
#------------------------------------------------------------------------------

resource "azurerm_monitor_action_group" "email" {
  count = var.create_alerts && length(var.alert_email_receivers) > 0 ? 1 : 0

  name                = "${var.alert_action_group_name}-email"
  resource_group_name = var.resource_group_name
  short_name          = "email"

  dynamic "email_receiver" {
    for_each = var.alert_email_receivers
    content {
      name          = email_receiver.value.name
      email_address = email_receiver.value.email_address
    }
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# Metric Alert - Node CPU Utilization
#------------------------------------------------------------------------------

resource "azurerm_monitor_metric_alert" "node_cpu" {
  count = var.create_alerts && var.aks_cluster_id != null ? 1 : 0

  name                = "${var.aks_cluster_name}-node-cpu-high"
  resource_group_name = var.resource_group_name
  scopes              = [var.aks_cluster_id]
  description         = "Alert when node CPU utilization exceeds 80%"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_cpu_usage_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  dynamic "action" {
    for_each = var.teams_webhook_url != null ? [1] : []
    content {
      action_group_id = azurerm_monitor_action_group.teams[0].id
    }
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# Metric Alert - Node Memory Utilization
#------------------------------------------------------------------------------

resource "azurerm_monitor_metric_alert" "node_memory" {
  count = var.create_alerts && var.aks_cluster_id != null ? 1 : 0

  name                = "${var.aks_cluster_name}-node-memory-high"
  resource_group_name = var.resource_group_name
  scopes              = [var.aks_cluster_id]
  description         = "Alert when node memory utilization exceeds 80%"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_memory_working_set_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  dynamic "action" {
    for_each = var.teams_webhook_url != null ? [1] : []
    content {
      action_group_id = azurerm_monitor_action_group.teams[0].id
    }
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# Metric Alert - Pod Restart Count
#------------------------------------------------------------------------------

resource "azurerm_monitor_metric_alert" "pod_restarts" {
  count = var.create_alerts && var.aks_cluster_id != null ? 1 : 0

  name                = "${var.aks_cluster_name}-pod-restarts-high"
  resource_group_name = var.resource_group_name
  scopes              = [var.aks_cluster_id]
  description         = "Alert when pod restart count exceeds threshold"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Insights.Container/pods"
    metric_name      = "restartingContainerCount"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 5
  }

  dynamic "action" {
    for_each = var.teams_webhook_url != null ? [1] : []
    content {
      action_group_id = azurerm_monitor_action_group.teams[0].id
    }
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# Metric Alert - Cluster Autoscaler Unschedulable Pods
#------------------------------------------------------------------------------

resource "azurerm_monitor_metric_alert" "unschedulable_pods" {
  count = var.create_alerts && var.aks_cluster_id != null ? 1 : 0

  name                = "${var.aks_cluster_name}-unschedulable-pods"
  resource_group_name = var.resource_group_name
  scopes              = [var.aks_cluster_id]
  description         = "Alert when there are unschedulable pods for extended period"
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Insights.Container/pods"
    metric_name      = "podCount"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 0

    dimension {
      name     = "phase"
      operator = "Include"
      values   = ["Pending"]
    }
  }

  dynamic "action" {
    for_each = var.pagerduty_integration_key != null ? [1] : []
    content {
      action_group_id = azurerm_monitor_action_group.pagerduty[0].id
    }
  }

  tags = var.tags
}
