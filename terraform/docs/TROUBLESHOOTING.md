# Terraform Troubleshooting Guide

This document captures common errors encountered during development and their resolutions.

---

## Table of Contents

1. [Unsupported argument `auto_scaling_enabled`](#error-1-unsupported-argument-auto_scaling_enabled)
2. [Unsupported argument `automatic_upgrade_channel`](#error-2-unsupported-argument-automatic_upgrade_channel)
3. [Deprecated argument `disable_bgp_route_propagation`](#error-3-deprecated-argument-disable_bgp_route_propagation)
4. [Deprecated argument `skip_provider_registration`](#error-4-deprecated-argument-skip_provider_registration)
5. [Deprecated argument `graceful_shutdown`](#error-5-deprecated-argument-graceful_shutdown)
6. [OpenPGP key expired error](#error-6-openpgp-key-expired-error)
7. [Invalid dynamic for_each value](#error-7-invalid-dynamic-for_each-value)
8. [Invalid count argument - depends on resource attributes](#error-8-invalid-count-argument---depends-on-resource-attributes)
9. [Storage account network rules default action](#error-9-storage-account-network-rules-default-action)
10. [Database minimum TLS version](#error-10-database-minimum-tls-version)
11. [AKS AAD RBAC - managed = false requires client/server app IDs](#error-11-aks-aad-rbac---managed--false-requires-clientserver-app-ids)
12. [ACR public_network_access_enabled - Premium SKU only](#error-12-acr-public_network_access_enabled---premium-sku-only)
13. [PostgreSQL PgBouncer - not supported on Burstable tier](#error-13-postgresql-pgbouncer---not-supported-on-burstable-tier)
14. [Policy Assignment 403 - missing permissions](#error-14-policy-assignment-403---missing-permissions)
15. [Role Assignment 403 - missing permissions](#error-15-role-assignment-403---missing-permissions)
16. [Firewall Rule Priority - duplicate priorities](#error-16-firewall-rule-priority---duplicate-priorities)
17. [AKS attribute name changes in AzureRM 3.x](#error-17-aks-attribute-name-changes-in-azurerm-3x)

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
Remove the deprecated argument. Graceful shutdown is the default behavior.

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

## Error 6: OpenPGP key expired error

**Context:** GitHub Actions CI/CD pipeline during `terraform init`

**Error Message:**
```
Error: Failed to install provider

Error while installing hashicorp/azurerm v3.x.x: the current package for 
registry.terraform.io/hashicorp/azurerm 3.x.x doesn't match any of the checksums 
previously recorded in the dependency lock file.

openpgp: signature made by key which has expired
```

**Cause:**
The Terraform version being used (e.g., 1.6.0) has an older OpenPGP key that has expired. Newer provider versions are signed with updated keys that older Terraform versions cannot verify.

**Resolution:**
Upgrade Terraform to version 1.9.0 or later which has updated signing keys.

**Before (in `.github/workflows/terraform.yml`):**
```yaml
env:
  TF_VERSION: '1.6.0'
```

**After:**
```yaml
env:
  TF_VERSION: '1.9.0'
```

**Alternative:** Run `terraform init -upgrade` to refresh provider signatures, but upgrading Terraform is the recommended long-term fix.

---

## Error 7: Invalid dynamic for_each value

**Module:** `terraform/modules/observability/alerts.tf`

**Error Message:**
```
Error: Invalid dynamic for_each value

  on ../../modules/observability/alerts.tf line 111, in resource "azurerm_monitor_metric_alert" "node_cpu":
 111:     for_each = var.teams_webhook_url != null ? [1] : []

Cannot use a list of number value in for_each. An iterable collection is required.
```

**Cause:**
In Terraform 1.9.0+, `for_each` in dynamic blocks requires a set of strings or a map, not a list of numbers like `[1]`.

**Resolution:**
Option 1: Use `toset()` with string values:
```hcl
dynamic "action" {
  for_each = var.teams_webhook_url != null ? toset(["teams"]) : toset([])
  content {
    action_group_id = azurerm_monitor_action_group.teams[0].id
  }
}
```

Option 2 (Recommended): Move the condition to the resource's `count` parameter instead of using dynamic blocks:
```hcl
resource "azurerm_monitor_metric_alert" "node_cpu" {
  count = var.create_alerts && var.aks_cluster_id != null && var.teams_webhook_url != null ? 1 : 0
  
  # ... other configuration ...
  
  action {
    action_group_id = azurerm_monitor_action_group.teams[0].id
  }
}
```

---

## Error 8: Invalid count argument - depends on resource attributes

**Module:** Multiple modules (AKS, Data, Network, Security)

**Error Message:**
```
Error: Invalid count argument

  on ../../modules/aks/main.tf line 160, in resource "azurerm_monitor_diagnostic_setting" "aks":
 160:   count = var.log_analytics_workspace_id != null ? 1 : 0

The "count" value depends on resource attributes that cannot be determined
until apply, so Terraform cannot predict how many instances will be
created. To work around this, use the -target argument to first apply only
the resources that the count depends on.
```

**Cause:**
When a variable's value comes from another module's output (e.g., `module.observability.log_analytics_workspace_id`), Terraform cannot determine if it's null or not until apply time. This makes the `count` condition unknown at plan time.

**Resolution:**
Use a separate boolean variable that is known at plan time instead of checking if the ID is null.

**Before:**
```hcl
# In the module
resource "azurerm_monitor_diagnostic_setting" "aks" {
  count = var.log_analytics_workspace_id != null ? 1 : 0
  # ...
}

# In the environment
module "aks" {
  log_analytics_workspace_id = module.observability.log_analytics_workspace_id
}
```

**After:**
```hcl
# In the module variables.tf - add a boolean flag
variable "enable_diagnostic_settings" {
  description = "Enable diagnostic settings"
  type        = bool
  default     = true
}

# In the module - use the boolean flag
resource "azurerm_monitor_diagnostic_setting" "aks" {
  count = var.enable_diagnostic_settings ? 1 : 0
  # ...
}

# In the environment - pass both the ID and the flag
module "aks" {
  log_analytics_workspace_id = module.observability.log_analytics_workspace_id
  enable_diagnostic_settings = true
}
```

**Affected Resources:**
- `azurerm_monitor_diagnostic_setting` (all modules)
- `azurerm_role_assignment.acr_pull` (AKS module)
- `azurerm_role_assignment.network_contributor` (AKS module)
- `azurerm_route_table.aks` (Spoke network module)

**Pattern to Follow:**
For any `count` or `for_each` that depends on a module output:
1. Add a boolean variable (e.g., `enable_*`)
2. Use the boolean in the count condition
3. Pass `true` or `false` from the calling module

---

## Error 9: Storage account network rules default action

**Severity:** CRITICAL (Security vulnerability AZU-0012)

**Scanner:** Trivy, Checkov

**Error Message:**
```
CKV_AZURE_35: "Ensure default network access rule for Storage Accounts is set to deny"
AZU-0012: "The default action on Storage account network rules should be set to deny"
```

**Cause:**
Storage account allows public network access by default, which is a security risk.

**Resolution:**
Add network rules with default deny action:

```hcl
resource "azurerm_storage_account" "main" {
  # ... other configuration ...
  
  # Network rules - default deny (CRITICAL: AZU-0012)
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices", "Logging", "Metrics"]
    virtual_network_subnet_ids = var.storage_allowed_subnet_ids
    ip_rules                   = var.storage_allowed_ip_ranges
  }
}
```

**Additional Security Enhancements:**
```hcl
resource "azurerm_storage_account" "main" {
  # Disable shared access key (use Azure AD auth)
  shared_access_key_enabled = false
  
  # Enable infrastructure encryption (double encryption)
  infrastructure_encryption_enabled = true
  
  # Enable queue logging
  queue_properties {
    logging {
      delete                = true
      read                  = true
      write                 = true
      version               = "1.0"
      retention_policy_days = 7
    }
  }
}
```

---

## Error 10: Database minimum TLS version

**Severity:** MEDIUM (Security vulnerability AZU-0026)

**Scanner:** Trivy

**Error Message:**
```
AZU-0026: "Databases should have the minimum TLS set for connections"
```

**Cause:**
PostgreSQL server doesn't explicitly enforce TLS 1.2 minimum.

**Resolution:**
Add server configuration to enforce TLS 1.2:

```hcl
resource "azurerm_postgresql_flexible_server_configuration" "require_secure_transport" {
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "ON"
}

resource "azurerm_postgresql_flexible_server_configuration" "ssl_min_protocol_version" {
  name      = "ssl_min_protocol_version"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "TLSv1.2"
}
```

---

## Error 11: AKS AAD RBAC - managed = false requires client/server app IDs

**Module:** `terraform/modules/aks/main.tf`

**Error Message:**
```
Error: creating Cluster: performing CreateOrUpdate: unexpected status 400 (400 Bad Request) 
with error: BadRequest: you must specify client_app_id and server_app_id and server_app_secret 
when using managed aad rbac (managed = false)
```

**Cause:**
When using Azure AD integration with AKS, if `managed = false` is set (legacy AAD integration), you must provide client_app_id, server_app_id, and server_app_secret. The modern approach uses managed AAD which doesn't require these.

**Resolution:**
Use managed Azure AD integration (the default in newer AzureRM provider versions). The `azure_active_directory_role_based_access_control` block should NOT include `managed = false`:

**Before (incorrect):**
```hcl
azure_active_directory_role_based_access_control {
  managed                = false  # This requires app IDs
  azure_rbac_enabled     = true
  admin_group_object_ids = var.azure_ad_admin_group_ids
}
```

**After (correct):**
```hcl
azure_active_directory_role_based_access_control {
  azure_rbac_enabled     = true
  admin_group_object_ids = var.azure_ad_admin_group_ids
  # managed = true is the default, no need to specify
}
```

---

## Error 12: ACR public_network_access_enabled - Premium SKU only

**Module:** `terraform/modules/data/acr.tf`

**Error Message:**
```
Error: creating Container Registry: performing CreateOrUpdate: unexpected status 400 (400 Bad Request) 
with error: BadRequest: public_network_access_enabled can only be disabled for a Premium Sku
```

**Cause:**
Disabling public network access (`public_network_access_enabled = false`) is only supported for Premium SKU ACR. Standard and Basic SKUs require public network access to be enabled.

**Resolution:**
For non-Premium SKUs, set `public_network_access_enabled = true`:

```hcl
# In environment main.tf (dev)
module "data" {
  # ...
  acr_sku                           = "Standard"
  acr_public_network_access_enabled = true  # Required for Standard SKU
}

# In environment main.tf (prod)
module "data" {
  # ...
  acr_sku                           = "Premium"
  acr_public_network_access_enabled = false  # Can disable for Premium
}
```

**Alternative:** Upgrade to Premium SKU if private network access is required.

---

## Error 13: PostgreSQL PgBouncer - not supported on Burstable tier

**Module:** `terraform/modules/data/postgresql.tf`

**Error Message:**
```
Error: updating Flexible Server Configuration: performing CreateOrUpdate: unexpected status 400 
(400 Bad Request) with error: InvalidParameterValue: PgBouncer isn't supported on servers 
which are using Burstable compute tier.
```

**Cause:**
PgBouncer connection pooling is NOT supported on Burstable tier PostgreSQL servers (B_Standard_*). It's only available on General Purpose (GP_*) and Memory Optimized (MO_*) tiers.

**Resolution:**
Add a variable to conditionally enable PgBouncer based on the SKU tier:

**In variables.tf:**
```hcl
variable "postgresql_enable_pgbouncer" {
  description = "Enable PgBouncer connection pooling. Note: NOT supported on Burstable tier (B_Standard_*)"
  type        = bool
  default     = true
}
```

**In postgresql.tf:**
```hcl
resource "azurerm_postgresql_flexible_server_configuration" "pgbouncer_enabled" {
  count = var.postgresql_enable_pgbouncer ? 1 : 0

  name      = "pgbouncer.enabled"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "true"
}
```

**In environment main.tf:**
```hcl
# Dev (Burstable tier)
module "data" {
  postgresql_sku_name         = "B_Standard_B2s"
  postgresql_enable_pgbouncer = false  # Not supported on Burstable
}

# Prod (General Purpose tier)
module "data" {
  postgresql_sku_name         = "GP_Standard_D4s_v3"
  postgresql_enable_pgbouncer = true  # Supported on GP tier
}
```

---

## Error 14: Policy Assignment 403 - missing permissions

**Module:** `terraform/modules/governance/policies.tf`

**Error Message:**
```
Error: creating Subscription Policy Assignment: unexpected status 403 (403 Forbidden) 
with error: AuthorizationFailed: The client '252246f4-6a3c-4f5a-810b-59dc0a7463dc' with 
object id '252246f4-6a3c-4f5a-810b-59dc0a7463dc' does not have authorization to perform 
action 'Microsoft.Authorization/policyAssignments/write' over scope '/subscriptions/...'
```

**Cause:**
The service principal used for Terraform doesn't have the `Microsoft.Authorization/policyAssignments/write` permission required to create policy assignments.

**Resolution:**
Option 1: Grant the service principal the "Resource Policy Contributor" role at subscription level:
```bash
az role assignment create \
  --assignee <service-principal-object-id> \
  --role "Resource Policy Contributor" \
  --scope /subscriptions/<subscription-id>
```

Option 2: Disable policy assignments in the environment:
```hcl
module "governance" {
  # ...
  enable_policy_assignments = false
}
```

---

## Error 15: Role Assignment 403 - missing permissions

**Module:** Multiple modules (AKS, Security)

**Error Message:**
```
Error: creating Role Assignment: unexpected status 403 (403 Forbidden) 
with error: AuthorizationFailed: The client does not have authorization to perform 
action 'Microsoft.Authorization/roleAssignments/write' over scope '...'
```

**Cause:**
The service principal doesn't have permission to create role assignments. This is needed for:
- ACR pull role for AKS kubelet identity
- Network Contributor role for AKS identity
- Key Vault access policies
- Managed Identity Operator role

**Resolution:**
Option 1: Grant the service principal the "User Access Administrator" role:
```bash
az role assignment create \
  --assignee <service-principal-object-id> \
  --role "User Access Administrator" \
  --scope /subscriptions/<subscription-id>
```

Option 2: Disable role assignments in the modules by adding `enable_role_assignments = false`:

**In AKS module variables.tf:**
```hcl
variable "enable_role_assignments" {
  description = "Enable role assignments (requires Microsoft.Authorization/roleAssignments/write permission)"
  type        = bool
  default     = true
}
```

**In environment main.tf:**
```hcl
module "aks" {
  # ...
  enable_role_assignments = false
}

module "security" {
  # ...
  enable_role_assignments = false
}
```

**Note:** When role assignments are disabled, you must manually create the following role assignments:
1. AcrPull role for kubelet identity on ACR
2. Network Contributor role for AKS identity on subnet
3. Private DNS Zone Contributor role for AKS identity on private DNS zone
4. Key Vault Secrets User role for AKS and kubelet identities on Key Vault
5. Managed Identity Operator role for AKS identity on kubelet identity

---

## Error 16: Firewall Rule Priority - duplicate priorities

**Module:** `terraform/modules/network/hub/firewall_rules.tf`

**Error Message:**
```
Error: creating Rule Collection Group: unexpected status 400 (400 Bad Request) 
with error: FirewallPolicyRuleCollectionGroupRuleCollectionPrioritiesMustBeUnique: 
Invalid Rule Collection Group. Priority 100 used for more than one rule collection.
```

**Cause:**
Within a firewall policy rule collection group, ALL rule collections (both application and network) must have unique priorities. The priority namespace is shared between application_rule_collection and network_rule_collection blocks.

**Resolution:**
Ensure unique priorities across all rule collections within a group. Use different priority ranges for application rules (100-400) and network rules (500-700):

```hcl
resource "azurerm_firewall_policy_rule_collection_group" "aks" {
  # ...
  
  # Application rules: 100-400
  application_rule_collection {
    name     = "aks-management"
    priority = 100
    # ...
  }

  application_rule_collection {
    name     = "azure-monitor"
    priority = 200
    # ...
  }

  # Network rules: 500-700 (different range to avoid conflicts)
  network_rule_collection {
    name     = "ntp"
    priority = 500  # NOT 100!
    # ...
  }

  network_rule_collection {
    name     = "dns"
    priority = 600
    # ...
  }
}
```

---

## Error 17: AKS attribute name changes in AzureRM 3.x

**Module:** `terraform/modules/aks/main.tf`, `terraform/modules/aks/node_pools.tf`

**Error Message:**
```
Error: Unsupported argument

  on main.tf line 70, in resource "azurerm_kubernetes_cluster" "main":
  70:     auto_scaling_enabled = true

An argument named "auto_scaling_enabled" is not expected here.
```

Or:
```
Error: Unsupported argument

  on main.tf line 103, in resource "azurerm_kubernetes_cluster" "main":
 103:   automatic_upgrade_channel = var.automatic_channel_upgrade

An argument named "automatic_upgrade_channel" is not expected here.
```

**Cause:**
AzureRM provider versions have different attribute names for AKS resources. The naming convention varies between versions.

**Resolution:**
Use the correct attribute names for your provider version. For AzureRM 3.x (up to 3.117.x):

| Correct Name (3.x) | Incorrect Name |
|---------------------|------------------|
| `enable_auto_scaling` | `auto_scaling_enabled` |
| `automatic_channel_upgrade` | `automatic_upgrade_channel` |

**Correct usage:**
```hcl
default_node_pool {
  enable_auto_scaling = true
}

automatic_channel_upgrade = var.automatic_channel_upgrade
```

**Note:** Check the [AzureRM Provider Changelog](https://github.com/hashicorp/terraform-provider-azurerm/blob/main/CHANGELOG.md) for attribute name changes when upgrading provider versions. Always verify attribute names against your locked provider version.

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

### 6. Count vs For_Each Dependencies
When using `count` or `for_each` with conditions:
- **DO:** Use boolean variables known at plan time
- **DON'T:** Check if module outputs are null (unknown until apply)

### 7. Security Scanning
Run security scans locally before pushing:
```bash
# Checkov
checkov -d terraform/

# tfsec
tfsec terraform/

# Trivy
trivy config terraform/
```

### 8. GitHub Actions Debugging
View failed workflow logs:
```bash
gh run view <run-id> --log-failed
```

List recent workflow runs:
```bash
gh run list --workflow=terraform.yml --limit 5
```
