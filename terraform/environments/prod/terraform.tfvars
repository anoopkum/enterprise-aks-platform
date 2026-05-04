# Production Environment - Variable Values
#
# Full HA settings with appropriate node counts for production workloads.

#------------------------------------------------------------------------------
# General Configuration
#------------------------------------------------------------------------------

# subscription_id = "00000000-0000-0000-0000-000000000000"  # Set via TF_VAR_subscription_id
# tenant_id       = "00000000-0000-0000-0000-000000000000"  # Set via TF_VAR_tenant_id

location           = "uksouth"
secondary_location = "ukwest"
org                = "contoso"

#------------------------------------------------------------------------------
# Tagging Configuration
#------------------------------------------------------------------------------

owner_email = "anoop.kumar@rackspace.com"
cost_center = "IT-PROD-001"

#------------------------------------------------------------------------------
# Network Configuration
#------------------------------------------------------------------------------

hub_vnet_address_space   = ["10.20.0.0/16"]
spoke_vnet_address_space = ["10.21.0.0/16"]

#------------------------------------------------------------------------------
# AKS Configuration
#------------------------------------------------------------------------------

kubernetes_version = "1.30"

# Azure AD group IDs for AKS admin access
# aks_admin_group_ids = ["00000000-0000-0000-0000-000000000000"]

# Authorized IP ranges for AKS API server access
# api_server_authorized_ip_ranges = ["203.0.113.0/24"]

#------------------------------------------------------------------------------
# Budget Configuration
#------------------------------------------------------------------------------

monthly_budget = 50000

# budget_alert_emails = ["platform-team@contoso.com", "finops@contoso.com", "management@contoso.com"]

#------------------------------------------------------------------------------
# Alerting Configuration
#------------------------------------------------------------------------------

# PagerDuty integration key for Sev0 alerts
# pagerduty_integration_key = "your-pagerduty-integration-key"

# Microsoft Teams webhook URL for Sev1-3 alerts
# teams_webhook_url = "https://outlook.office.com/webhook/..."
