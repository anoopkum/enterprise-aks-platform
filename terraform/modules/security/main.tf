# Security Module - Main Configuration
#
# This module creates security infrastructure including:
# - Azure Key Vault with private endpoint
# - User-assigned managed identities for AKS
# - RBAC role assignments
#
# Resources are defined in separate files:
# - keyvault.tf: Key Vault and private endpoint
# - managed_identities.tf: AKS and kubelet identities
# - private_endpoints.tf: Reusable private endpoint patterns

# This file serves as the module entry point and documentation.
# All resources are defined in their respective files for better organization.
