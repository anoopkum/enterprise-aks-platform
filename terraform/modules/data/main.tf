# Data Module - Main Configuration
#
# This module creates data infrastructure including:
# - Azure Container Registry with geo-replication
# - Azure PostgreSQL Flexible Server with HA
# - Azure Storage Account
#
# Resources are defined in separate files:
# - acr.tf: Container Registry and private endpoint
# - postgresql.tf: PostgreSQL Flexible Server and PgBouncer
# - storage.tf: Storage Account and lifecycle policies

# This file serves as the module entry point.
# All resources are defined in their respective files.
