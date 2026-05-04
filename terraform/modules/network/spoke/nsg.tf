# Spoke Network Module - Network Security Groups
#
# This file creates NSGs for each subnet with deny-all default rules
# and explicit allow rules for required traffic flows.

#------------------------------------------------------------------------------
# NSG - AKS Subnet
#------------------------------------------------------------------------------

resource "azurerm_network_security_group" "aks" {
  count = var.enable_nsg ? 1 : 0

  name                = "${var.vnet_name}-aks-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow inbound from Azure Load Balancer (health probes)
  security_rule {
    name                       = "AllowAzureLoadBalancerInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Allow inbound from VNet (pod-to-pod, node-to-node)
  security_rule {
    name                       = "AllowVnetInbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # Allow inbound from App Gateway subnet (ingress traffic)
  security_rule {
    name                       = "AllowAppGatewayInbound"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80-65535"
    source_address_prefix      = var.app_gateway_subnet_prefix
    destination_address_prefix = "*"
  }

  # Deny all other inbound traffic
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow outbound to VNet
  security_rule {
    name                       = "AllowVnetOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # Allow outbound to Azure services (for service endpoints)
  security_rule {
    name                       = "AllowAzureCloudOutbound"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }

  # Allow outbound to Internet (via Azure Firewall)
  security_rule {
    name                       = "AllowInternetOutbound"
    priority                   = 300
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  count = var.enable_nsg ? 1 : 0

  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks[0].id
}

#------------------------------------------------------------------------------
# NSG - AKS ILB Subnet
#------------------------------------------------------------------------------

resource "azurerm_network_security_group" "aks_ilb" {
  count = var.enable_nsg ? 1 : 0

  name                = "${var.vnet_name}-aks-ilb-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow inbound from AKS subnet
  security_rule {
    name                       = "AllowAksSubnetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.aks_subnet_prefix
    destination_address_prefix = "*"
  }

  # Allow inbound from Azure Load Balancer
  security_rule {
    name                       = "AllowAzureLoadBalancerInbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Deny all other inbound
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "aks_ilb" {
  count = var.enable_nsg ? 1 : 0

  subnet_id                 = azurerm_subnet.aks_ilb.id
  network_security_group_id = azurerm_network_security_group.aks_ilb[0].id
}

#------------------------------------------------------------------------------
# NSG - Private Endpoints Subnet
#------------------------------------------------------------------------------

resource "azurerm_network_security_group" "private_endpoints" {
  count = var.enable_nsg ? 1 : 0

  name                = "${var.vnet_name}-pe-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow inbound from VNet (AKS accessing private endpoints)
  security_rule {
    name                       = "AllowVnetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Allow PostgreSQL from AKS
  security_rule {
    name                       = "AllowPostgreSQLInbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["5432", "6432"]
    source_address_prefix      = var.aks_subnet_prefix
    destination_address_prefix = "*"
  }

  # Deny all other inbound
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  count = var.enable_nsg ? 1 : 0

  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints[0].id
}

#------------------------------------------------------------------------------
# NSG - Application Gateway Subnet
#------------------------------------------------------------------------------

resource "azurerm_network_security_group" "app_gateway" {
  count = var.enable_nsg ? 1 : 0

  name                = "${var.vnet_name}-agw-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow inbound HTTP/HTTPS from Internet
  security_rule {
    name                       = "AllowHttpsInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Allow inbound from Azure Gateway Manager (required for App Gateway)
  security_rule {
    name                       = "AllowGatewayManagerInbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  # Allow inbound from Azure Load Balancer
  security_rule {
    name                       = "AllowAzureLoadBalancerInbound"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Deny all other inbound
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow outbound to AKS subnet (backend pool)
  security_rule {
    name                       = "AllowAksSubnetOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80-65535"
    source_address_prefix      = "*"
    destination_address_prefix = var.aks_subnet_prefix
  }

  # Allow outbound to Azure services
  security_rule {
    name                       = "AllowAzureCloudOutbound"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "app_gateway" {
  count = var.enable_nsg ? 1 : 0

  subnet_id                 = azurerm_subnet.app_gateway.id
  network_security_group_id = azurerm_network_security_group.app_gateway[0].id
}

#------------------------------------------------------------------------------
# Diagnostic Settings - NSGs
#------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "nsg_aks" {
  count = var.enable_nsg && var.enable_diagnostic_settings && var.log_analytics_workspace_id != null ? 1 : 0

  name                       = "${azurerm_network_security_group.aks[0].name}-diag"
  target_resource_id         = azurerm_network_security_group.aks[0].id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

resource "azurerm_monitor_diagnostic_setting" "nsg_pe" {
  count = var.enable_nsg && var.enable_diagnostic_settings && var.log_analytics_workspace_id != null ? 1 : 0

  name                       = "${azurerm_network_security_group.private_endpoints[0].name}-diag"
  target_resource_id         = azurerm_network_security_group.private_endpoints[0].id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}
