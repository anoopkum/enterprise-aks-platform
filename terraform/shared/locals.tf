# Common Local Values
#
# This module provides shared local values and configurations
# used across all environments and modules.

# Azure region configurations
locals {
  # Primary and secondary regions for disaster recovery
  azure_regions = {
    primary = {
      name       = "eastus"
      display    = "East US"
      paired     = "westus"
      zone_count = 3
    }
    secondary = {
      name       = "westus2"
      display    = "West US 2"
      paired     = "westcentralus"
      zone_count = 3
    }
  }

  # Availability zones for HA deployments
  availability_zones = ["1", "2", "3"]

  # Common CIDR blocks
  network_cidrs = {
    hub = {
      vnet       = "10.0.0.0/16"
      firewall   = "10.0.1.0/26"
      bastion    = "10.0.2.0/26"
      gateway    = "10.0.3.0/27"
      management = "10.0.4.0/24"
    }
    spoke = {
      vnet              = "10.1.0.0/16"
      aks               = "10.1.0.0/22" # 1024 IPs for AKS nodes
      aks_ilb           = "10.1.4.0/24" # Internal load balancers
      private_endpoints = "10.1.5.0/24" # Private endpoints
      app_gateway       = "10.1.6.0/24" # Application Gateway
    }
    kubernetes = {
      service_cidr   = "10.2.0.0/16"   # Kubernetes services
      dns_service_ip = "10.2.0.10"     # Kubernetes DNS
      pod_cidr       = "10.244.0.0/16" # Pod network (Azure CNI Overlay)
    }
  }

  # VM SKU configurations by workload type
  vm_skus = {
    system = {
      small  = "Standard_D2s_v5"
      medium = "Standard_D4s_v5"
      large  = "Standard_D8s_v5"
    }
    user = {
      small  = "Standard_D4s_v5"
      medium = "Standard_D8s_v5"
      large  = "Standard_D16s_v5"
    }
    spot = {
      small  = "Standard_D4s_v5"
      medium = "Standard_D8s_v5"
      large  = "Standard_D16s_v5"
    }
    memory_optimized = {
      small  = "Standard_E4s_v5"
      medium = "Standard_E8s_v5"
      large  = "Standard_E16s_v5"
    }
    compute_optimized = {
      small  = "Standard_F4s_v2"
      medium = "Standard_F8s_v2"
      large  = "Standard_F16s_v2"
    }
  }

  # Environment-specific configurations
  environment_configs = {
    dev = {
      # Node pool sizing
      system_node_count_min = 1
      system_node_count_max = 3
      user_node_count_min   = 1
      user_node_count_max   = 5
      spot_node_count_min   = 0
      spot_node_count_max   = 3

      # VM sizes (smaller for cost savings)
      system_vm_size = local.vm_skus.system.small
      user_vm_size   = local.vm_skus.user.small
      spot_vm_size   = local.vm_skus.spot.small

      # Storage and retention
      log_retention_days    = 30
      backup_retention_days = 7

      # High availability
      zone_redundant = false

      # Cost controls
      enable_spot_pools = true
      auto_shutdown     = true
    }

    test = {
      # Node pool sizing (production-like for testing)
      system_node_count_min = 2
      system_node_count_max = 4
      user_node_count_min   = 2
      user_node_count_max   = 10
      spot_node_count_min   = 0
      spot_node_count_max   = 5

      # VM sizes
      system_vm_size = local.vm_skus.system.medium
      user_vm_size   = local.vm_skus.user.medium
      spot_vm_size   = local.vm_skus.spot.medium

      # Storage and retention
      log_retention_days    = 60
      backup_retention_days = 14

      # High availability
      zone_redundant = true

      # Cost controls
      enable_spot_pools = true
      auto_shutdown     = false
    }

    prod = {
      # Node pool sizing (full production capacity)
      system_node_count_min = 2
      system_node_count_max = 5
      user_node_count_min   = 3
      user_node_count_max   = 20
      spot_node_count_min   = 0
      spot_node_count_max   = 10

      # VM sizes
      system_vm_size = local.vm_skus.system.medium
      user_vm_size   = local.vm_skus.user.medium
      spot_vm_size   = local.vm_skus.spot.medium

      # Storage and retention
      log_retention_days    = 90
      backup_retention_days = 35

      # High availability
      zone_redundant = true

      # Cost controls
      enable_spot_pools = true
      auto_shutdown     = false
    }
  }

  # Kubernetes version configuration
  kubernetes_config = {
    version                = "1.28"
    automatic_channel      = "patch"
    maintenance_window_day = "Sunday"
    maintenance_window_hours = {
      start = 2
      end   = 6
    }
  }

  # Private DNS zone names for Azure services
  private_dns_zones = {
    acr           = "privatelink.azurecr.io"
    key_vault     = "privatelink.vaultcore.azure.net"
    postgresql    = "privatelink.postgres.database.azure.com"
    storage_blob  = "privatelink.blob.core.windows.net"
    storage_file  = "privatelink.file.core.windows.net"
    storage_queue = "privatelink.queue.core.windows.net"
    storage_table = "privatelink.table.core.windows.net"
    aks_api       = "privatelink.azmk8s.io"
    cosmos        = "privatelink.documents.azure.com"
    redis         = "privatelink.redis.cache.windows.net"
    service_bus   = "privatelink.servicebus.windows.net"
    event_hub     = "privatelink.servicebus.windows.net"
  }

  # Azure Firewall required FQDNs for AKS
  aks_required_fqdns = {
    management = [
      "*.hcp.*.azmk8s.io",
      "mcr.microsoft.com",
      "*.data.mcr.microsoft.com",
      "management.azure.com",
      "login.microsoftonline.com",
      "packages.microsoft.com",
      "acs-mirror.azureedge.net"
    ]
    monitoring = [
      "dc.services.visualstudio.com",
      "*.ods.opinsights.azure.com",
      "*.oms.opinsights.azure.com",
      "*.monitoring.azure.com"
    ]
    policy = [
      "data.policy.core.windows.net",
      "store.policy.core.windows.net"
    ]
    security = [
      "*.blob.core.windows.net",
      "*.table.core.windows.net"
    ]
  }

  # Common Kubernetes labels
  kubernetes_labels = {
    system = {
      "node-type"     = "system"
      "workload-type" = "critical"
    }
    user = {
      "node-type"     = "user"
      "workload-type" = "general"
    }
    spot = {
      "node-type"     = "spot"
      "workload-type" = "interruptible"
    }
  }

  # Common Kubernetes taints
  kubernetes_taints = {
    system = "CriticalAddonsOnly=true:NoSchedule"
    spot   = "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
  }
}

# Outputs for use in other modules
output "azure_regions" {
  description = "Azure region configurations"
  value       = local.azure_regions
}

output "availability_zones" {
  description = "Available zones for HA deployments"
  value       = local.availability_zones
}

output "network_cidrs" {
  description = "Network CIDR configurations"
  value       = local.network_cidrs
}

output "vm_skus" {
  description = "VM SKU configurations by workload type"
  value       = local.vm_skus
}

output "environment_configs" {
  description = "Environment-specific configurations"
  value       = local.environment_configs
}

output "kubernetes_config" {
  description = "Kubernetes version and maintenance configuration"
  value       = local.kubernetes_config
}

output "private_dns_zones" {
  description = "Private DNS zone names for Azure services"
  value       = local.private_dns_zones
}

output "aks_required_fqdns" {
  description = "Required FQDNs for AKS operation"
  value       = local.aks_required_fqdns
}

output "kubernetes_labels" {
  description = "Common Kubernetes node labels"
  value       = local.kubernetes_labels
}

output "kubernetes_taints" {
  description = "Common Kubernetes node taints"
  value       = local.kubernetes_taints
}
