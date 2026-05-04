# Terraform Troubleshooting Guide

This document captures common errors encountered during development and their resolutions.

---

## Error 1: Unsupported argument `auto_scaling_enabled`

**Module:** `terraform/modules/aks`

**Error Message:**
```
Error: Unsupported argument

  on main.tf line 70, in resource "azurerm_kubernetes_cluster" "main":
  70:     auto_scaling_enabled         = true

An argument named "auto_scaling_enabled" is not expected here.
```

**Cause:**
The argument name `auto_scaling_enabled` is not recognized by the AzureRM provider version being used. The correct argument name is `enable_auto_scaling`.

**Resolution:**
Change `auto_scaling_enabled` to `enable_auto_scaling` in both:
- `azurerm_kubernetes_cluster.main.default_node_pool`
- `azurerm_kubernetes_cluster_node_pool.user`

**Before:**
```hcl
default_node_pool {
  auto_scaling_enabled = true
}
```

**After:**
```hcl
default_node_pool {
  enable_auto_scaling = true
}
```

---

## Error 2: Unsupported argument `automatic_upgrade_channel`

**Module:** `terraform/modules/aks`

**Error Message:**
```
Error: Unsupported argument

  on main.tf line 103, in resource "azurerm_kubernetes_cluster" "main":
 103:   automatic_upgrade_channel = var.automatic_channel_upgrade

An argument named "automatic_upgrade_channel" is not expected here.
```

**Cause:**
The argument name was incorrectly specified. The correct argument name is `automatic_channel_upgrade` (not `automatic_upgrade_channel`).

**Resolution:**
Change `automatic_upgrade_channel` to `automatic_channel_upgrade`.

**Before:**
```hcl
automatic_upgrade_channel = var.automatic_channel_upgrade
```

**After:**
```hcl
automatic_channel_upgrade = var.automatic_channel_upgrade
```

---

## Error 3: Deprecated argument `disable_bgp_route_propagation`

**Module:** `terraform/modules/network/spoke`

**Warning Message:**
```
Warning: Argument is deprecated

  with azurerm_route_table.aks,
  on subnets.tf line 69, in resource "azurerm_route_table" "aks":
  69:   disable_bgp_route_propagation = true

The property `disable_bgp_route_propagation` has been superseded by the property 
`bgp_route_propagation_enabled` and will be removed in v4.0 of the AzureRM Provider.
```

**Cause:**
The `disable_bgp_route_propagation` argument is deprecated and will be removed in AzureRM provider v4.0.

**Resolution:**
Replace `disable_bgp_route_propagation = true` with `bgp_route_propagation_enabled = false`.

**Before:**
```hcl
resource "azurerm_route_table" "aks" {
  disable_bgp_route_propagation = true
}
```

**After:**
```hcl
resource "azurerm_route_table" "aks" {
  bgp_route_propagation_enabled = false
}
```

---

## Error 4: Deprecated argument `skip_provider_registration`

**Module:** `terraform/environments/*/providers.tf`

**Warning Message:**
```
Warning: "skip_provider_registration" is deprecated

skip_provider_registration = false
```

**Cause:**
The `skip_provider_registration` argument is deprecated in newer versions of the AzureRM provider.

**Resolution:**
This is a cosmetic warning and does not affect functionality. The argument can be safely removed if desired, as the default behavior (registering providers) is typically what you want.

**Before:**
```hcl
provider "azurerm" {
  skip_provider_registration = false
}
```

**After:**
```hcl
provider "azurerm" {
  # Removed skip_provider_registration as it's deprecated
  # Provider registration happens by default
}
```

**Note:** If you need to skip provider registration (e.g., in restricted environments), use the `resource_provider_registrations` argument instead.

---

## Error 5: Deprecated argument `graceful_shutdown`

**Module:** `terraform/environments/*/providers.tf`

**Warning Message:**
```
Warning: "graceful_shutdown" is deprecated

graceful_shutdown = true
```

**Cause:**
The `graceful_shutdown` argument in the `virtual_machine` features block is deprecated.

**Resolution:**
This is a cosmetic warning and does not affect functionality. The argument can be safely removed as graceful shutdown is the default behavior.

**Before:**
```hcl
provider "azurerm" {
  features {
    virtual_machine {
      graceful_shutdown = true
    }
  }
}
```

**After:**
```hcl
provider "azurerm" {
  features {
    virtual_machine {
      delete_os_disk_on_deletion     = true
      skip_shutdown_and_force_delete = false
    }
  }
}
```

---

## General Troubleshooting Tips

### 1. Provider Version Mismatches
Always check the AzureRM provider documentation for your specific version:
- [AzureRM Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

### 2. Validate Before Apply
Always run `terraform validate` before `terraform plan` or `terraform apply`:
```bash
terraform validate
```

### 3. Check Deprecation Warnings
Deprecation warnings indicate arguments that will be removed in future versions. Address them proactively to avoid breaking changes during provider upgrades.

### 4. Use Terraform Format
Keep code consistent with:
```bash
terraform fmt -recursive
```

### 5. Lock Provider Versions
Use `.terraform.lock.hcl` to ensure consistent provider versions across team members and CI/CD pipelines.
