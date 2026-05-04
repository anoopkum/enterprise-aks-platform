# Development Environment - Variable Values
#
# Configuration for Enterprise AKS Platform - Dev Environment

# Azure Configuration
subscription_id = "27320543-d2ea-4fd5-b361-0145cc56934b"
tenant_id       = "e2e605ca-a105-4b19-bcb9-5b1ca2d5ce71"

# General
location = "uksouth"
org      = "enterprise"

# Tagging
owner_email = "anoop.kumar@rackspace.com"
cost_center = "CC-AKS-DEV"

# Network
hub_vnet_address_space   = ["10.0.0.0/16"]
spoke_vnet_address_space = ["10.1.0.0/16"]

# AKS
kubernetes_version = "1.31"

# Azure AD Admin Group - Create a group in Azure AD and add the Object ID here
# To create: az ad group create --display-name "AKS-Admins-Dev" --mail-nickname "aks-admins-dev"
# To get ID: az ad group show --group "AKS-Admins-Dev" --query id -o tsv
aks_admin_group_ids = []  # Add your Azure AD group ID here

# API Server Access - Your current IP and common ranges
api_server_authorized_ip_ranges = [
  "2.221.35.167/32",   # Your current IP
]

# Budget
monthly_budget      = 2000
budget_alert_emails = ["anoop.kumar@rackspace.com"]
