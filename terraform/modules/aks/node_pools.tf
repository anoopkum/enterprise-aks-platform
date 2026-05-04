# AKS Module - Node Pools
#
# This file creates additional node pools for user workloads
# including regular and spot node pools.

#------------------------------------------------------------------------------
# User Node Pools
#------------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  for_each = var.user_node_pools

  name                  = each.value.name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = each.value.vm_size
  node_count            = each.value.node_count
  min_count             = each.value.min_count
  max_count             = each.value.max_count
  zones                 = each.value.availability_zones
  os_disk_size_gb       = each.value.os_disk_size_gb
  os_disk_type          = each.value.os_disk_type
  vnet_subnet_id        = var.vnet_subnet_id
  enable_auto_scaling   = true

  # Spot instance configuration
  priority        = each.value.priority
  eviction_policy = each.value.priority == "Spot" ? each.value.eviction_policy : null
  spot_max_price  = each.value.priority == "Spot" ? each.value.spot_max_price : null

  # Node labels and taints
  node_labels = each.value.node_labels
  node_taints = each.value.node_taints

  # Upgrade settings
  upgrade_settings {
    max_surge                     = "33%"
    drain_timeout_in_minutes      = 30
    node_soak_duration_in_minutes = 0
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      # Ignore changes to node count as it's managed by autoscaler
      node_count,
    ]
  }
}
