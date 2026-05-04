# AKS Module - Main Configuration
#
# This module creates the Azure Kubernetes Service cluster with:
# - Private cluster mode with authorized IP ranges
# - Azure CNI Overlay network plugin
# - Azure AD integration with RBAC
# - System and user node pools
# - Workload Identity and OIDC issuer

#------------------------------------------------------------------------------
# AKS Cluster
#------------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  # Private cluster configuration
  private_cluster_enabled             = var.private_cluster_enabled
  private_dns_zone_id                 = var.private_cluster_enabled ? var.private_dns_zone_id : null
  private_cluster_public_fqdn_enabled = var.private_cluster_enabled ? var.private_cluster_public_fqdn_enabled : null

  # API server authorized IP ranges (for developer/CI-CD access)
  api_server_access_profile {
    authorized_ip_ranges = length(var.api_server_authorized_ip_ranges) > 0 ? var.api_server_authorized_ip_ranges : null
  }

  # Identity configuration
  dynamic "identity" {
    for_each = var.identity_type == "SystemAssigned" ? [1] : []
    content {
      type = "SystemAssigned"
    }
  }

  dynamic "identity" {
    for_each = var.identity_type == "UserAssigned" ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = [var.user_assigned_identity_id]
    }
  }

  # Kubelet identity (for pulling images from ACR)
  dynamic "kubelet_identity" {
    for_each = var.kubelet_identity_client_id != null ? [1] : []
    content {
      client_id                 = var.kubelet_identity_client_id
      object_id                 = var.kubelet_identity_object_id
      user_assigned_identity_id = var.kubelet_identity_id
    }
  }

  # System node pool (default)
  default_node_pool {
    name                         = var.system_node_pool.name
    vm_size                      = var.system_node_pool.vm_size
    node_count                   = var.system_node_pool.node_count
    min_count                    = var.system_node_pool.min_count
    max_count                    = var.system_node_pool.max_count
    zones                        = var.system_node_pool.availability_zones
    os_disk_size_gb              = var.system_node_pool.os_disk_size_gb
    os_disk_type                 = var.system_node_pool.os_disk_type
    vnet_subnet_id               = var.vnet_subnet_id
    only_critical_addons_enabled = var.system_node_pool.only_critical_addons_enabled
    enable_auto_scaling          = true
    node_labels                  = var.system_node_pool.node_labels
    temporary_name_for_rotation  = "systemtemp"

    upgrade_settings {
      max_surge                     = "33%"
      drain_timeout_in_minutes      = 30
      node_soak_duration_in_minutes = 0
    }
  }

  # Network configuration
  network_profile {
    network_plugin      = var.network_plugin
    network_plugin_mode = var.network_plugin == "azure" ? var.network_plugin_mode : null
    network_policy      = var.network_policy
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    pod_cidr            = var.network_plugin == "azure" && var.network_plugin_mode == "overlay" ? var.pod_cidr : null
    outbound_type       = var.outbound_type
    load_balancer_sku   = "standard"
  }

  # Azure AD integration
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = var.azure_rbac_enabled
    admin_group_object_ids = var.azure_ad_admin_group_ids
  }

  # Disable local accounts (enforce Azure AD)
  local_account_disabled = var.local_account_disabled

  # Automatic upgrade
  automatic_channel_upgrade = var.automatic_channel_upgrade

  # Maintenance window
  dynamic "maintenance_window" {
    for_each = var.maintenance_window != null ? [var.maintenance_window] : []
    content {
      dynamic "allowed" {
        for_each = maintenance_window.value.allowed
        content {
          day   = allowed.value.day
          hours = allowed.value.hours
        }
      }
    }
  }

  # Workload Identity and OIDC
  workload_identity_enabled = var.workload_identity_enabled
  oidc_issuer_enabled       = var.oidc_issuer_enabled

  # Azure Policy addon
  azure_policy_enabled = var.azure_policy_enabled

  # Container Insights (OMS agent)
  dynamic "oms_agent" {
    for_each = var.oms_agent_enabled && var.log_analytics_workspace_id != null ? [1] : []
    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  # Key Vault Secrets Provider
  dynamic "key_vault_secrets_provider" {
    for_each = var.key_vault_secrets_provider_enabled ? [1] : []
    content {
      secret_rotation_enabled  = var.secret_rotation_enabled
      secret_rotation_interval = var.secret_rotation_interval
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      # Ignore changes to node count as it's managed by autoscaler
      default_node_pool[0].node_count,
      # Ignore changes to kubernetes version during upgrades
      kubernetes_version,
    ]
  }
}

#------------------------------------------------------------------------------
# Diagnostic Settings
#------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "aks" {
  count = var.log_analytics_workspace_id != null ? 1 : 0

  name                       = "${azurerm_kubernetes_cluster.main.name}-diag"
  target_resource_id         = azurerm_kubernetes_cluster.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-audit"
  }

  enabled_log {
    category = "kube-audit-admin"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "kube-scheduler"
  }

  enabled_log {
    category = "cluster-autoscaler"
  }

  enabled_log {
    category = "guard"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
