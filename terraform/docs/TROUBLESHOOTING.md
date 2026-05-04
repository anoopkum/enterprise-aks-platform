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
Option 1 (Recommended): Grant the service principal the "User Access Administrator" role:
```bash
az role assignment create \
  --assignee <service-principal-object-id> \
  --role "User Access Administrator" \
  --scope /subscriptions/<subscription-id>
```

Option 2: Disable role assignments in the modules by adding `enable_role_assignments = false`:

**IMPORTANT:** If you disable role assignments, you MUST manually create the "Managed Identity Operator" role assignment for AKS to work:
```bash
# Get the AKS identity principal ID
AKS_IDENTITY_PRINCIPAL_ID=$(az identity show \
  --name <aks-identity-name> \
  --resource-group <security-resource-group> \
  --query principalId -o tsv)

# Get the kubelet identity resource ID
KUBELET_IDENTITY_ID=$(az identity show \
  --name <kubelet-identity-name> \
  --resource-group <security-resource-group> \
  --query id -o tsv)

# Create the role assignment
az role assignment create \
  --assignee $AKS_IDENTITY_PRINCIPAL_ID \
  --role "Managed Identity Operator" \
  --scope $KUBELET_IDENTITY_ID
```

**Note:** When role assignments are disabled, you must manually create the following role assignments:
1. **Managed Identity Operator** role for AKS identity on kubelet identity (REQUIRED for AKS to work)
2. AcrPull role for kubelet identity on ACR
3. Network Contributor role for AKS identity on subnet
4. Private DNS Zone Contributor role for AKS identity on private DNS zone
5. Key Vault Secrets User role for AKS and kubelet identities on Key Vault

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


---

## Error 18: Kubernetes version requires LTS (1.31+)

**Module:** `terraform/modules/aks`

**Error Message:**
```
Error: creating Kubernetes Cluster: unexpected status 400 (400 Bad Request) with response: {
  "code": "K8sVersionNotSupported",
  "message": "Managed cluster is on version 1.31.x, which is only available for Long-Term Support (LTS). 
  If you intend to onboard to LTS, please ensure the cluster is in Premium tier and LTS support plan..."
}
```

**Cause:**
Kubernetes version 1.31+ requires AKS Premium tier with Long-Term Support (LTS) plan. Free and Standard tiers cannot use these versions.

**Resolution:**
Option 1: Use a supported GA version (recommended for dev/test):
```hcl
# In terraform.tfvars
kubernetes_version = "1.30"
```

Option 2: Upgrade to Premium tier with LTS (for production):
```hcl
# In main.tf
sku_tier = "Premium"

# Enable LTS in the cluster configuration
support_plan = "AKSLongTermSupport"
```

**Check available versions:**
```bash
az aks get-versions --location uksouth --output table
```

---

## Error 20: Kubernetes version 1.30 also requires LTS in some regions

**Module:** `terraform/modules/aks`

**Error Message:**
```
Error: creating Kubernetes Cluster: unexpected status 400 (400 Bad Request) with response: {
  "code": "K8sVersionNotSupported",
  "message": "Managed cluster is on version 1.30.14, which is only available for Long-Term Support (LTS)..."
}
```

**Cause:**
As of 2026, Kubernetes version 1.30 has also moved to LTS-only support in Azure. The "KubernetesOfficial" support plan is only available for more recent versions (1.33+).

**Resolution:**
Use Kubernetes version 1.33 or later which supports the "KubernetesOfficial" plan:
```hcl
# In terraform.tfvars
kubernetes_version = "1.33"
```

**Check available versions and their support plans:**
```bash
az aks get-versions --location uksouth --output table
```

The output shows which versions support "KubernetesOfficial" (standard support) vs "AKSLongTermSupport" (requires Premium tier).

---

## Error 19: Resource already exists - needs import

**Module:** Various

**Error Message:**
```
Error: A resource with the ID "..." already exists - to be managed via Terraform this resource 
needs to be imported into the State.
```

**Cause:**
The resource was created outside of Terraform or in a previous failed run, and now exists in Azure but not in Terraform state.

**Resolution:**
Import the resource into Terraform state:
```bash
# Example for firewall rule collection group
terraform import 'module.hub_network.azurerm_firewall_policy_rule_collection_group.aks[0]' \
  '/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Network/firewallPolicies/<policy>/ruleCollectionGroups/<name>'
```

Or delete the resource in Azure and let Terraform recreate it:
```bash
az network firewall policy rule-collection-group delete \
  --name aks-rules \
  --policy-name enterprise-dev-uksouth-vnet-hub-afw-policy \
  --resource-group enterprise-dev-uksouth-rg-hub
```


---

## Error 21: InvalidPrivateDNSZoneResourceID - AKS requires region-specific DNS zone

**Module:** `terraform/modules/aks`

**Error Message:**
```
Error: creating Kubernetes Cluster: unexpected status 400 (400 Bad Request) with response: {
  "code": "InvalidPrivateDNSZoneResourceID",
  "message": "Invalid private dns zone resource id '...privatelink.azmk8s.io' for private cluster. 
  It should be a valid resource id and the private dns zone name should be in either of these formats: 
  'private.<region>.azmk8s.io, privatelink.<region>.azmk8s.io, [a-zA-Z0-9-]{1,32}.private.<region>.azmk8s.io, 
  [a-zA-Z0-9-]{1,32}.privatelink.<region>.azmk8s.io'."
}
```

**Cause:**
AKS private clusters require a region-specific private DNS zone name. The generic `privatelink.azmk8s.io` is not valid. The zone name must include the Azure region, e.g., `privatelink.uksouth.azmk8s.io`.

**Resolution:**
1. Update the hub network module to create a region-specific AKS private DNS zone:
```hcl
# In dns.tf
locals {
  aks_private_dns_zone_name = "privatelink.${var.location}.azmk8s.io"
}

resource "azurerm_private_dns_zone" "aks" {
  count = var.create_private_dns_zones ? 1 : 0
  name  = local.aks_private_dns_zone_name
  # ...
}
```

2. Update the AKS module to use the region-specific zone:
```hcl
private_dns_zone_id = module.hub_network.aks_private_dns_zone_id
```

3. If the old zone exists, delete it and its VNet links:
```bash
# Delete VNet links first
az network private-dns link vnet delete \
  --name <vnet-link-name> \
  --zone-name privatelink.azmk8s.io \
  --resource-group <hub-rg> --yes

# Then delete the zone
az network private-dns zone delete \
  --name privatelink.azmk8s.io \
  --resource-group <hub-rg> --yes
```

**Valid DNS Zone Formats:**
- `private.<region>.azmk8s.io`
- `privatelink.<region>.azmk8s.io`
- `<custom-prefix>.private.<region>.azmk8s.io`
- `<custom-prefix>.privatelink.<region>.azmk8s.io`

**Example for UK South:**
- `privatelink.uksouth.azmk8s.io`


---

## Error 22: ResourceMissingPermissionError - AKS identity needs DNS zone read permission

**Module:** `terraform/modules/aks`

**Error Message:**
```
Error: creating Kubernetes Cluster: unexpected status 400 (400 Bad Request) with response: {
  "code": "ResourceMissingPermissionError",
  "message": "Service principal or user-assigned identity must be given certain permissions to resource 
  /subscriptions/.../resourceGroups/.../providers/Microsoft.Network/privateDnsZones/privatelink.uksouth.azmk8s.io. 
  Check access result not allowed for action Microsoft.Network/privateDnsZones/read."
}
```

**Cause:**
When using a User-Assigned Managed Identity for AKS with a private cluster, the identity needs "Private DNS Zone Contributor" role on the private DNS zone **before** the cluster is created. The role assignment in the AKS module's rbac.tf was using `azurerm_kubernetes_cluster.main.identity[0].principal_id`, which creates a circular dependency - the cluster can't be created without the permission, but the permission can't be assigned without the cluster.

**Resolution:**
Move the role assignment to the environment's main.tf and assign it to the user-assigned identity (from the security module) before the AKS module runs:

```hcl
# In environments/dev/main.tf (or prod)

# Private DNS Zone Contributor for AKS Identity
# Required for AKS to manage DNS records in private DNS zone during cluster creation
resource "azurerm_role_assignment" "aks_dns_contributor" {
  scope                = module.hub_network.aks_private_dns_zone_id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = module.security.aks_identity_principal_id
}

# Network Contributor for AKS Identity on AKS Subnet
# Required for AKS to manage load balancers and route tables
resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = module.spoke_network.aks_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = module.security.aks_identity_principal_id
}

module "aks" {
  source = "../../modules/aks"

  # Ensure role assignments are created before AKS cluster
  depends_on = [
    azurerm_role_assignment.aks_dns_contributor,
    azurerm_role_assignment.aks_network_contributor
  ]
  
  # ... rest of configuration
}
```

**Key Points:**
1. The role assignments must use the **user-assigned identity's principal_id** (from security module), not the cluster's identity
2. The `depends_on` ensures Terraform creates the role assignments before attempting to create the AKS cluster
3. Remove duplicate role assignments from the AKS module's rbac.tf to avoid conflicts

---

## Error 23: Resource already exists - Firewall Policy Rule Collection Group

**Module:** `terraform/modules/network/hub`

**Error Message:**
```
Error: A resource with the ID "/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/
firewallPolicies/.../ruleCollectionGroups/aks-rules" already exists - to be managed via Terraform 
this resource needs to be imported into the State.
```

**Cause:**
The firewall policy rule collection group was created in a previous Terraform run but the apply failed before the state could be saved. The resource exists in Azure but not in Terraform state.

**Resolution:**
Option 1: Import the resource into Terraform state:
```bash
terraform import \
  -var="subscription_id=<subscription-id>" \
  -var="tenant_id=<tenant-id>" \
  'module.hub_network.azurerm_firewall_policy_rule_collection_group.aks[0]' \
  '/subscriptions/<subscription-id>/resourceGroups/<hub-rg>/providers/Microsoft.Network/firewallPolicies/<policy-name>/ruleCollectionGroups/aks-rules'
```

Option 2: Delete the resource in Azure and let Terraform recreate it:
```bash
az network firewall policy rule-collection-group delete \
  --name aks-rules \
  --policy-name <policy-name> \
  --resource-group <hub-rg> \
  --yes
```

**CI/CD Workflow Fix:**
Add an import step to the GitHub Actions workflow before apply:
```yaml
- name: Import Existing Resources (if needed)
  run: |
    terraform import \
      -var="subscription_id=${{ secrets.AZURE_SUBSCRIPTION_ID }}" \
      -var="tenant_id=${{ secrets.AZURE_TENANT_ID }}" \
      'module.hub_network.azurerm_firewall_policy_rule_collection_group.aks[0]' \
      '/subscriptions/${{ secrets.AZURE_SUBSCRIPTION_ID }}/resourceGroups/enterprise-dev-uksouth-rg-hub/providers/Microsoft.Network/firewallPolicies/enterprise-dev-uksouth-vnet-hub-afw-policy/ruleCollectionGroups/aks-rules' \
      2>/dev/null || echo "Resource already in state or does not exist"
  working-directory: terraform/environments/dev
  continue-on-error: true
```

**Prevention:**
This error typically occurs when:
1. A Terraform apply is interrupted mid-execution
2. The state file is corrupted or out of sync
3. Resources are created manually in Azure

To prevent:
- Use remote state with locking (Azure Storage with blob lease)
- Don't interrupt Terraform apply operations
- Avoid manual changes to Terraform-managed resources
