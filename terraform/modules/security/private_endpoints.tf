# Security Module - Private Endpoints
#
# This file provides a reusable private endpoint resource
# that can be used for various Azure PaaS services.

#------------------------------------------------------------------------------
# Private Endpoint for Generic Resources
# This is a reusable pattern - specific endpoints are created in their
# respective modules (ACR in data module, PostgreSQL in data module, etc.)
#------------------------------------------------------------------------------

# Note: Key Vault private endpoint is defined in keyvault.tf
# Other private endpoints (ACR, PostgreSQL, Storage) are defined in the data module
# This file serves as documentation and can be extended for additional services

#------------------------------------------------------------------------------
# Local values for private endpoint configuration
#------------------------------------------------------------------------------

locals {
  # Mapping of Azure service types to their private endpoint subresource names
  private_endpoint_subresources = {
    key_vault    = "vault"
    acr          = "registry"
    postgresql   = "postgresqlServer"
    storage_blob = "blob"
    storage_file = "file"
    cosmos_sql   = "Sql"
    redis        = "redisCache"
    service_bus  = "namespace"
    event_hub    = "namespace"
  }

  # Mapping of Azure service types to their private DNS zone names
  private_dns_zones = {
    key_vault    = "privatelink.vaultcore.azure.net"
    acr          = "privatelink.azurecr.io"
    postgresql   = "privatelink.postgres.database.azure.com"
    storage_blob = "privatelink.blob.core.windows.net"
    storage_file = "privatelink.file.core.windows.net"
    cosmos_sql   = "privatelink.documents.azure.com"
    redis        = "privatelink.redis.cache.windows.net"
    service_bus  = "privatelink.servicebus.windows.net"
    event_hub    = "privatelink.servicebus.windows.net"
  }
}
