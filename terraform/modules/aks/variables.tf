# AKS Module - Variables
#
# Input variables for Azure Kubernetes Service cluster configuration.

#------------------------------------------------------------------------------
# General Configuration
#------------------------------------------------------------------------------

variable "resource_group_name" {
  description = "Name of the resource group where AKS resources will be created"
  type        = string
}

variable "location" {
  description = "Azure region for AKS resources"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all AKS resources"
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# Cluster Configuration
#------------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
  default     = "1.28"
}

variable "sku_tier" {
  description = "SKU tier for the AKS cluster (Free or Standard)"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Free", "Standard"], var.sku_tier)
    error_message = "SKU tier must be Free or Standard."
  }
}

variable "automatic_channel_upgrade" {
  description = "Automatic upgrade channel for the AKS cluster"
  type        = string
  default     = "patch"

  validation {
    condition     = contains(["none", "patch", "rapid", "stable", "node-image"], var.automatic_channel_upgrade)
    error_message = "Automatic channel upgrade must be none, patch, rapid, stable, or node-image."
  }
}

#------------------------------------------------------------------------------
# Network Configuration
#------------------------------------------------------------------------------

variable "vnet_subnet_id" {
  description = "ID of the subnet for AKS nodes"
  type        = string
}

variable "network_plugin" {
  description = "Network plugin for AKS (azure or kubenet)"
  type        = string
  default     = "azure"

  validation {
    condition     = contains(["azure", "kubenet", "none"], var.network_plugin)
    error_message = "Network plugin must be azure, kubenet, or none."
  }
}

variable "network_plugin_mode" {
  description = "Network plugin mode (overlay for Azure CNI Overlay)"
  type        = string
  default     = "overlay"

  validation {
    condition     = var.network_plugin_mode == null || contains(["overlay"], var.network_plugin_mode)
    error_message = "Network plugin mode must be overlay or null."
  }
}

variable "network_policy" {
  description = "Network policy for AKS (azure, calico, or cilium)"
  type        = string
  default     = "azure"

  validation {
    condition     = var.network_policy == null || contains(["azure", "calico", "cilium"], var.network_policy)
    error_message = "Network policy must be azure, calico, cilium, or null."
  }
}

variable "service_cidr" {
  description = "CIDR for Kubernetes services"
  type        = string
  default     = "10.2.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for Kubernetes DNS service"
  type        = string
  default     = "10.2.0.10"
}

variable "pod_cidr" {
  description = "CIDR for pods (used with Azure CNI Overlay)"
  type        = string
  default     = "10.244.0.0/16"
}

variable "outbound_type" {
  description = "Outbound routing type (loadBalancer or userDefinedRouting)"
  type        = string
  default     = "userDefinedRouting"

  validation {
    condition     = contains(["loadBalancer", "userDefinedRouting", "managedNATGateway", "userAssignedNATGateway"], var.outbound_type)
    error_message = "Outbound type must be loadBalancer, userDefinedRouting, managedNATGateway, or userAssignedNATGateway."
  }
}

#------------------------------------------------------------------------------
# Private Cluster Configuration
#------------------------------------------------------------------------------

variable "private_cluster_enabled" {
  description = "Enable private cluster mode"
  type        = bool
  default     = true
}

variable "private_dns_zone_id" {
  description = "ID of the private DNS zone for the AKS API server"
  type        = string
  default     = null
}

variable "private_cluster_public_fqdn_enabled" {
  description = "Enable public FQDN for private cluster (for authorized IP access)"
  type        = bool
  default     = true
}

variable "api_server_authorized_ip_ranges" {
  description = "List of authorized IP ranges for API server access"
  type        = list(string)
  default     = []
}

#------------------------------------------------------------------------------
# Identity Configuration
#------------------------------------------------------------------------------

variable "identity_type" {
  description = "Identity type for AKS (SystemAssigned or UserAssigned)"
  type        = string
  default     = "UserAssigned"

  validation {
    condition     = contains(["SystemAssigned", "UserAssigned"], var.identity_type)
    error_message = "Identity type must be SystemAssigned or UserAssigned."
  }
}

variable "user_assigned_identity_id" {
  description = "ID of the user-assigned managed identity for AKS control plane"
  type        = string
  default     = null
}

variable "kubelet_identity_client_id" {
  description = "Client ID of the kubelet managed identity"
  type        = string
  default     = null
}

variable "kubelet_identity_object_id" {
  description = "Object ID of the kubelet managed identity"
  type        = string
  default     = null
}

variable "kubelet_identity_id" {
  description = "Resource ID of the kubelet managed identity"
  type        = string
  default     = null
}

#------------------------------------------------------------------------------
# Azure AD Integration
#------------------------------------------------------------------------------

variable "azure_rbac_enabled" {
  description = "Enable Azure RBAC for Kubernetes authorization"
  type        = bool
  default     = true
}

variable "local_account_disabled" {
  description = "Disable local accounts (enforce Azure AD authentication)"
  type        = bool
  default     = true
}

variable "azure_ad_admin_group_ids" {
  description = "List of Azure AD group object IDs for cluster admin access"
  type        = list(string)
  default     = []
}

#------------------------------------------------------------------------------
# System Node Pool Configuration
#------------------------------------------------------------------------------

variable "system_node_pool" {
  description = "Configuration for the system node pool"
  type = object({
    name                         = string
    vm_size                      = string
    node_count                   = number
    min_count                    = number
    max_count                    = number
    availability_zones           = list(string)
    os_disk_size_gb              = number
    os_disk_type                 = string
    only_critical_addons_enabled = bool
    node_labels                  = optional(map(string), {})
    node_taints                  = optional(list(string), [])
  })
  default = {
    name                         = "system"
    vm_size                      = "Standard_D4s_v5"
    node_count                   = 2
    min_count                    = 2
    max_count                    = 5
    availability_zones           = ["1", "2", "3"]
    os_disk_size_gb              = 128
    os_disk_type                 = "Ephemeral"
    only_critical_addons_enabled = true
    node_labels                  = {}
    node_taints                  = []
  }
}

#------------------------------------------------------------------------------
# User Node Pools Configuration
#------------------------------------------------------------------------------

variable "user_node_pools" {
  description = "Map of user node pool configurations"
  type = map(object({
    name               = string
    vm_size            = string
    node_count         = number
    min_count          = number
    max_count          = number
    availability_zones = list(string)
    os_disk_size_gb    = number
    os_disk_type       = string
    priority           = optional(string, "Regular")
    eviction_policy    = optional(string, null)
    spot_max_price     = optional(number, null)
    node_labels        = optional(map(string), {})
    node_taints        = optional(list(string), [])
  }))
  default = {}
}

#------------------------------------------------------------------------------
# Addons Configuration
#------------------------------------------------------------------------------

variable "azure_policy_enabled" {
  description = "Enable Azure Policy addon"
  type        = bool
  default     = true
}

variable "oms_agent_enabled" {
  description = "Enable OMS agent (Container Insights) addon"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "ID of Log Analytics Workspace for Container Insights"
  type        = string
  default     = null
}

variable "key_vault_secrets_provider_enabled" {
  description = "Enable Key Vault Secrets Provider addon"
  type        = bool
  default     = true
}

variable "secret_rotation_enabled" {
  description = "Enable secret rotation for Key Vault Secrets Provider"
  type        = bool
  default     = true
}

variable "secret_rotation_interval" {
  description = "Secret rotation interval (e.g., 2m)"
  type        = string
  default     = "2m"
}

variable "workload_identity_enabled" {
  description = "Enable Workload Identity"
  type        = bool
  default     = true
}

variable "oidc_issuer_enabled" {
  description = "Enable OIDC issuer"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# ACR Integration
#------------------------------------------------------------------------------

variable "acr_id" {
  description = "ID of Azure Container Registry for AcrPull role assignment"
  type        = string
  default     = null
}

variable "enable_acr_integration" {
  description = "Enable ACR integration (AcrPull role assignment)"
  type        = bool
  default     = true
}

variable "enable_role_assignments" {
  description = "Enable role assignments (requires Microsoft.Authorization/roleAssignments/write permission)"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Maintenance Window
#------------------------------------------------------------------------------

variable "maintenance_window" {
  description = "Maintenance window configuration"
  type = object({
    allowed = list(object({
      day   = string
      hours = list(number)
    }))
  })
  default = {
    allowed = [
      {
        day   = "Sunday"
        hours = [2, 3, 4, 5]
      }
    ]
  }
}
