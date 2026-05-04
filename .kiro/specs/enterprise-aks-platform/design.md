# Technical Design Document: Enterprise AKS Platform

## Overview

This document provides the comprehensive technical design for an enterprise-grade Azure Kubernetes Service (AKS) platform. The platform implements a production-ready, highly secure, scalable, and cost-optimized container orchestration solution following Zero Trust principles and enterprise standards.

### Design Goals

1. **Security-First Architecture**: Private endpoints, network segmentation, workload identity, and policy enforcement
2. **High Availability**: Multi-zone deployment, automated failover, and resilience patterns
3. **Operational Excellence**: Comprehensive observability, automated incident response, and GitOps workflows
4. **Cost Optimization**: Spot instances, autoscaling, and FinOps integration
5. **Developer Experience**: Self-service capabilities, standardized pipelines, and clear documentation

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Network Topology | Hub-Spoke | Centralized security controls, reduced management overhead |
| AKS API Access | Private + Authorized IPs | Zero Trust with developer access from approved IPs |
| Identity | Workload Identity | No secrets in cluster, Azure AD federation |
| Policy Enforcement | OPA Gatekeeper | Kubernetes-native, flexible policy language |
| Observability | Prometheus + Grafana + Azure Monitor | Best-of-breed metrics with Azure integration |
| IaC | Terraform with Modules | Mature ecosystem, state management, modularity |
| CI/CD | GitHub Actions | Native integration, OIDC support, marketplace |

---

## Architecture

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    AZURE SUBSCRIPTION                                     │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                              HUB VIRTUAL NETWORK (10.0.0.0/16)                       │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌────────────────┐  │ │
│  │  │  Azure Firewall │  │  Azure Bastion  │  │  VPN Gateway    │  │ Private DNS    │  │ │
│  │  │  10.0.1.0/26    │  │  10.0.2.0/26    │  │  10.0.3.0/27    │  │ Zones          │  │ │
│  │  │                 │  │                 │  │                 │  │ *.privatelink  │  │ │
│  │  │  ┌───────────┐  │  │  ┌───────────┐  │  │  ┌───────────┐  │  │                │  │ │
│  │  │  │ App Rules │  │  │  │ Jump Host │  │  │  │ S2S/P2S   │  │  │ - ACR          │  │ │
│  │  │  │ Net Rules │  │  │  │ Access    │  │  │  │ Tunnels   │  │  │ - KeyVault     │  │ │
│  │  │  │ DNAT      │  │  │  └───────────┘  │  │  └───────────┘  │  │ - PostgreSQL   │  │ │
│  │  │  └───────────┘  │  │                 │  │                 │  │ - Storage      │  │ │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘  └────────────────┘  │ │
│  │                                      │                                               │ │
│  │                            VNet Peering (Gateway Transit)                            │ │
│  └──────────────────────────────────────┼───────────────────────────────────────────────┘ │
│                                         │                                                 │
│  ┌──────────────────────────────────────┼───────────────────────────────────────────────┐ │
│  │                         SPOKE VIRTUAL NETWORK (10.1.0.0/16)                          │ │
│  │                                      │                                               │ │
│  │  ┌───────────────────────────────────┴────────────────────────────────────────────┐  │ │
│  │  │                        AKS SUBNET (10.1.0.0/22)                                 │  │ │
│  │  │  ┌─────────────────────────────────────────────────────────────────────────┐   │  │ │
│  │  │  │                    PRIVATE AKS CLUSTER                                   │   │  │ │
│  │  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │   │  │ │
│  │  │  │  │ System Pool │  │ User Pool   │  │ Spot Pool   │  │ API Server      │ │   │  │ │
│  │  │  │  │ 2-5 nodes   │  │ 2-20 nodes  │  │ 0-10 nodes  │  │ (Private EP)    │ │   │  │ │
│  │  │  │  │ Zone 1,2,3  │  │ Zone 1,2,3  │  │ Zone 1,2,3  │  │ 10.1.4.4        │ │   │  │ │
│  │  │  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────────┘ │   │  │ │
│  │  │  │                                                                          │   │  │ │
│  │  │  │  ┌─────────────────────────────────────────────────────────────────────┐│   │  │ │
│  │  │  │  │ KUBERNETES WORKLOADS                                                ││   │  │ │
│  │  │  │  │ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────────┐ ││   │  │ │
│  │  │  │  │ │Prometheus│ │ Grafana  │ │OPA Gate- │ │ KEDA     │ │ App        │ ││   │  │ │
│  │  │  │  │ │          │ │          │ │keeper    │ │          │ │ Workloads  │ ││   │  │ │
│  │  │  │  │ └──────────┘ └──────────┘ └──────────┘ └──────────┘ └────────────┘ ││   │  │ │
│  │  │  │  └─────────────────────────────────────────────────────────────────────┘│   │  │ │
│  │  │  └─────────────────────────────────────────────────────────────────────────┘   │  │ │
│  │  └────────────────────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                                       │ │
│  │  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────────────────┐  │ │
│  │  │ ILB SUBNET         │  │ PE SUBNET          │  │ APP GW SUBNET                  │  │ │
│  │  │ 10.1.4.0/24        │  │ 10.1.5.0/24        │  │ 10.1.6.0/24                    │  │ │
│  │  │ Internal LBs       │  │ Private Endpoints  │  │ App Gateway + WAF              │  │ │
│  │  └────────────────────┘  │ - ACR PE           │  │ Ingress Controller             │  │ │
│  │                          │ - KeyVault PE      │  └────────────────────────────────┘  │ │
│  │                          │ - PostgreSQL PE    │                                      │ │
│  │                          │ - Storage PE       │                                      │ │
│  │                          └────────────────────┘                                      │ │
│  └──────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                           │
│  ┌──────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                              AZURE PAAS SERVICES                                      │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │ │
│  │  │ Azure Container │  │ Azure Key Vault │  │ Azure Database  │  │ Log Analytics   │  │ │
│  │  │ Registry (ACR)  │  │                 │  │ for PostgreSQL  │  │ Workspace       │  │ │
│  │  │ Premium SKU     │  │ Premium SKU     │  │ Flexible Server │  │                 │  │ │
│  │  │ Geo-replicated  │  │ HSM-backed      │  │ Zone-redundant  │  │ Container       │  │ │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘  │ Insights        │  │ │
│  │                                                                  └─────────────────┘  │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │ │
│  │  │ Storage Account │  │ Application     │  │ Azure Policy    │  │ Azure Cost      │  │ │
│  │  │ (TF State)      │  │ Insights        │  │                 │  │ Management      │  │ │
│  │  │ GRS + Versioning│  │ APM + Tracing   │  │ Compliance      │  │ Budgets         │  │ │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘  └─────────────────┘  │ │
│  └──────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                           │
└─────────────────────────────────────────────────────────────────────────────────────────┘

                                    EXTERNAL CONNECTIONS
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐ │
│  │ GitHub Actions  │  │ PagerDuty       │  │ Microsoft Teams │  │ Azure AD            │ │
│  │ CI/CD Pipelines │  │ Incident Mgmt   │  │ Notifications   │  │ Identity Provider   │ │
│  │ OIDC Auth       │  │ Sev0/Sev1 Alerts│  │ Sev1-3 Alerts   │  │ Workload Identity   │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

### Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              REQUEST FLOW (INGRESS)                                  │
└─────────────────────────────────────────────────────────────────────────────────────┘

  Internet          Azure Front Door       App Gateway/WAF        AKS Ingress         Pod
     │                    │                      │                    │                │
     │  HTTPS Request     │                      │                    │                │
     ├───────────────────►│                      │                    │                │
     │                    │  DDoS Protection     │                    │                │
     │                    │  Global Load Balance │                    │                │
     │                    ├─────────────────────►│                    │                │
     │                    │                      │  WAF Rules         │                │
     │                    │                      │  SSL Termination   │                │
     │                    │                      ├───────────────────►│                │
     │                    │                      │                    │  Route to Svc  │
     │                    │                      │                    ├───────────────►│
     │                    │                      │                    │                │

┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              EGRESS FLOW (OUTBOUND)                                  │
└─────────────────────────────────────────────────────────────────────────────────────┘

     Pod              UDR              Azure Firewall        Internet/PaaS
      │                │                     │                    │
      │  Outbound      │                     │                    │
      ├───────────────►│                     │                    │
      │                │  Force Tunnel       │                    │
      │                ├────────────────────►│                    │
      │                │                     │  FQDN Filtering    │
      │                │                     │  Logging           │
      │                │                     ├───────────────────►│
      │                │                     │                    │

┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         PRIVATE ENDPOINT FLOW (PAAS ACCESS)                          │
└─────────────────────────────────────────────────────────────────────────────────────┘

     Pod           Private DNS         Private Endpoint        PaaS Service
      │                │                     │                      │
      │  DNS Query     │                     │                      │
      │  acr.io        │                     │                      │
      ├───────────────►│                     │                      │
      │                │  Resolve to PE IP   │                      │
      │◄───────────────┤  10.1.5.x           │                      │
      │                │                     │                      │
      │  Connect to PE │                     │                      │
      ├────────────────┼────────────────────►│                      │
      │                │                     │  Private Backbone    │
      │                │                     ├─────────────────────►│
      │                │                     │                      │
```

---

## Components and Interfaces

### Component Inventory

| Component | Type | Purpose | Interfaces |
|-----------|------|---------|------------|
| Hub VNet | Network | Central network services | Peering, DNS, Firewall |
| Spoke VNet | Network | Workload isolation | Peering, Subnets |
| Azure Firewall | Security | Egress filtering | FQDN rules, Network rules |
| AKS Cluster | Compute | Container orchestration | Kubernetes API, kubelet |
| ACR | Registry | Container images | Docker API, Private EP |
| Key Vault | Security | Secrets management | REST API, CSI Driver |
| PostgreSQL | Data | Relational database | PostgreSQL protocol, PE |
| Log Analytics | Observability | Log aggregation | REST API, Agent |
| Prometheus | Observability | Metrics collection | PromQL, Remote Write |
| Grafana | Observability | Visualization | HTTP, Azure AD |
| OPA Gatekeeper | Security | Policy enforcement | Admission webhook |

### Interface Specifications

#### Kubernetes API Server
- **Protocol**: HTTPS (TLS 1.2+)
- **Authentication**: Azure AD + Kubernetes RBAC
- **Access**: Private endpoint (10.1.4.4) + Authorized IP ranges for developer access
- **Port**: 443
- **Authorized IPs**: Configurable list of developer/CI-CD IPs (e.g., office IPs, VPN exit points, individual developer IPs)

#### Container Registry
- **Protocol**: HTTPS
- **Authentication**: Managed Identity (AcrPull role)
- **Access**: Private endpoint
- **Rate Limits**: Premium tier (unlimited)

#### Key Vault
- **Protocol**: HTTPS
- **Authentication**: Workload Identity
- **Access**: Private endpoint
- **Operations**: Get secrets, List secrets

#### PostgreSQL
- **Protocol**: PostgreSQL (TLS required)
- **Authentication**: Azure AD + Managed Identity
- **Access**: Private endpoint
- **Connection Pooling**: PgBouncer (6432)

---

## Data Models

### Terraform State Structure

```hcl
# State organization per environment
terraform-state/
├── dev/
│   ├── network.tfstate
│   ├── aks.tfstate
│   ├── security.tfstate
│   └── data.tfstate
├── test/
│   └── ... (same structure)
└── prod/
    └── ... (same structure)
```

### Resource Naming Convention

```
{org}-{env}-{region}-{resource-type}-{instance}

Examples:
- contoso-prod-eastus-vnet-hub
- contoso-prod-eastus-aks-main
- contoso-prod-eastus-kv-platform
- contoso-prod-eastus-acr-main
```

### Tagging Schema

```hcl
locals {
  mandatory_tags = {
    Environment = var.environment        # dev, test, prod
    Owner       = var.owner_email        # team-platform@contoso.com
    CostCenter  = var.cost_center        # CC-12345
    Application = var.application_name   # enterprise-aks-platform
    ManagedBy   = "terraform"
    Repository  = var.repository_url
    CreatedDate = timestamp()
  }
}
```

### Kubernetes Namespace Structure

```yaml
# Namespace hierarchy
namespaces:
  system:
    - kube-system          # Core Kubernetes components
    - gatekeeper-system    # OPA Gatekeeper
    - monitoring           # Prometheus, Grafana
    - ingress-nginx        # Ingress controller
    - cert-manager         # Certificate management
  platform:
    - platform-tools       # Platform utilities
    - secrets-store        # CSI driver components
  applications:
    - app-team-a-dev       # Team A development
    - app-team-a-prod      # Team A production
    - app-team-b-dev       # Team B development
    - app-team-b-prod      # Team B production
```

---

## Terraform Folder Structure

```
terraform/
├── README.md
├── Makefile                          # Common commands
│
├── modules/                          # Reusable modules
│   ├── network/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   ├── hub/
│   │   │   ├── main.tf               # Hub VNet, Firewall, Bastion
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── dns.tf                # Private DNS zones
│   │   └── spoke/
│   │       ├── main.tf               # Spoke VNet, Peering
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── subnets.tf            # AKS, PE, ILB subnets
│   │
│   ├── aks/
│   │   ├── main.tf                   # AKS cluster resource
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   ├── node_pools.tf             # System, User, Spot pools
│   │   ├── identity.tf               # Managed identities
│   │   ├── addons.tf                 # Azure Policy, monitoring
│   │   └── rbac.tf                   # Azure AD integration
│   │
│   ├── security/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   ├── keyvault.tf               # Key Vault + policies
│   │   ├── managed_identities.tf     # User-assigned identities
│   │   └── private_endpoints.tf      # PE for all PaaS
│   │
│   ├── observability/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   ├── log_analytics.tf          # Workspace + solutions
│   │   ├── app_insights.tf           # Application Insights
│   │   └── alerts.tf                 # Azure Monitor alerts
│   │
│   ├── data/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   ├── postgresql.tf             # Flexible Server
│   │   ├── storage.tf                # Storage accounts
│   │   └── acr.tf                    # Container Registry
│   │
│   └── governance/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       ├── policies.tf               # Azure Policy assignments
│       └── budgets.tf                # Cost management
│
├── environments/                     # Environment configurations
│   ├── dev/
│   │   ├── main.tf                   # Module composition
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   ├── backend.tf                # State configuration
│   │   └── terraform.tfvars          # Dev-specific values
│   │
│   ├── test/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   ├── backend.tf
│   │   └── terraform.tfvars
│   │
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── providers.tf
│       ├── backend.tf
│       └── terraform.tfvars
│
└── shared/                           # Shared configurations
    ├── naming.tf                     # Naming conventions
    ├── tags.tf                       # Tag definitions
    └── locals.tf                     # Common locals
```

---

## Sample Terraform Code

### Backend Configuration (environments/prod/backend.tf)

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "contoso-prod-eastus-rg-tfstate"
    storage_account_name = "contosoprodtfstate"
    container_name       = "tfstate"
    key                  = "prod/aks-platform.tfstate"
    use_oidc             = true
    subscription_id      = "00000000-0000-0000-0000-000000000000"
    tenant_id            = "00000000-0000-0000-0000-000000000000"
  }
}
```

### Main Module Composition (environments/prod/main.tf)

```hcl
# environments/prod/main.tf

locals {
  environment = "prod"
  region      = "eastus"
  org         = "contoso"
  
  common_tags = {
    Environment = local.environment
    Owner       = var.owner_email
    CostCenter  = var.cost_center
    Application = "enterprise-aks-platform"
    ManagedBy   = "terraform"
    Repository  = "https://github.com/contoso/aks-platform"
  }
}

# Network Module - Hub
module "hub_network" {
  source = "../../modules/network/hub"
  
  resource_group_name = azurerm_resource_group.hub.name
  location            = local.region
  
  vnet_name          = "${local.org}-${local.environment}-${local.region}-vnet-hub"
  vnet_address_space = ["10.0.0.0/16"]
  
  firewall_subnet_prefix = "10.0.1.0/26"
  bastion_subnet_prefix  = "10.0.2.0/26"
  gateway_subnet_prefix  = "10.0.3.0/27"
  
  enable_ddos_protection = true
  
  private_dns_zones = [
    "privatelink.azurecr.io",
    "privatelink.vaultcore.azure.net",
    "privatelink.postgres.database.azure.com",
    "privatelink.blob.core.windows.net",
    "privatelink.azmk8s.io"
  ]
  
  tags = local.common_tags
}

# Network Module - Spoke
module "spoke_network" {
  source = "../../modules/network/spoke"
  
  resource_group_name = azurerm_resource_group.spoke.name
  location            = local.region
  
  vnet_name          = "${local.org}-${local.environment}-${local.region}-vnet-spoke"
  vnet_address_space = ["10.1.0.0/16"]
  
  hub_vnet_id              = module.hub_network.vnet_id
  hub_firewall_private_ip  = module.hub_network.firewall_private_ip
  
  subnets = {
    aks = {
      address_prefix = "10.1.0.0/22"
      service_endpoints = ["Microsoft.ContainerRegistry", "Microsoft.KeyVault"]
    }
    aks_ilb = {
      address_prefix = "10.1.4.0/24"
    }
    private_endpoints = {
      address_prefix = "10.1.5.0/24"
    }
    app_gateway = {
      address_prefix = "10.1.6.0/24"
    }
  }
  
  private_dns_zone_ids = module.hub_network.private_dns_zone_ids
  
  tags = local.common_tags
}

# Security Module
module "security" {
  source = "../../modules/security"
  
  resource_group_name = azurerm_resource_group.security.name
  location            = local.region
  
  key_vault_name = "${local.org}-${local.environment}-${local.region}-kv"
  
  private_endpoint_subnet_id = module.spoke_network.subnet_ids["private_endpoints"]
  private_dns_zone_ids       = module.hub_network.private_dns_zone_ids
  
  aks_identity_principal_id = module.aks.kubelet_identity_object_id
  
  tags = local.common_tags
}

# AKS Module
module "aks" {
  source = "../../modules/aks"
  
  resource_group_name = azurerm_resource_group.aks.name
  location            = local.region
  
  cluster_name    = "${local.org}-${local.environment}-${local.region}-aks"
  dns_prefix      = "${local.org}-${local.environment}-aks"
  kubernetes_version = "1.28"
  
  # Network configuration
  vnet_subnet_id           = module.spoke_network.subnet_ids["aks"]
  private_cluster_enabled  = true
  private_dns_zone_id      = module.hub_network.private_dns_zone_ids["privatelink.azmk8s.io"]
  
  # API Server Access - Authorized IP Ranges for Developer/CI-CD Access
  # This allows access from specific IPs while maintaining private cluster security
  enable_public_fqdn_for_authorized_ips = var.enable_public_fqdn_for_authorized_ips
  api_server_authorized_ip_ranges = var.api_server_authorized_ip_ranges
  # Example IP ranges:
  # - "203.0.113.50/32"     # Developer laptop IP
  # - "198.51.100.0/24"     # Office network
  # - "192.0.2.10/32"       # CI/CD runner IP
  # - "10.0.0.0/8"          # Internal VPN range
  
  # Node pools
  system_node_pool = {
    name                = "system"
    vm_size             = "Standard_D4s_v5"
    node_count          = 2
    min_count           = 2
    max_count           = 5
    availability_zones  = ["1", "2", "3"]
    os_disk_size_gb     = 128
    os_disk_type        = "Ephemeral"
    only_critical_addons_enabled = true
  }
  
  user_node_pools = {
    user = {
      name               = "user"
      vm_size            = "Standard_D8s_v5"
      node_count         = 2
      min_count          = 2
      max_count          = 20
      availability_zones = ["1", "2", "3"]
      os_disk_size_gb    = 256
      os_disk_type       = "Ephemeral"
      node_labels = {
        "workload-type" = "general"
      }
    }
    spot = {
      name               = "spot"
      vm_size            = "Standard_D8s_v5"
      node_count         = 0
      min_count          = 0
      max_count          = 10
      availability_zones = ["1", "2", "3"]
      priority           = "Spot"
      eviction_policy    = "Delete"
      spot_max_price     = -1
      node_labels = {
        "workload-type" = "spot"
      }
      node_taints = ["kubernetes.azure.com/scalesetpriority=spot:NoSchedule"]
    }
  }
  
  # Identity
  identity_type                = "UserAssigned"
  user_assigned_identity_id    = module.security.aks_identity_id
  azure_rbac_enabled           = true
  local_account_disabled       = true
  azure_ad_admin_group_ids     = var.aks_admin_group_ids
  
  # Addons
  azure_policy_enabled         = true
  oms_agent_enabled            = true
  log_analytics_workspace_id   = module.observability.log_analytics_workspace_id
  
  # Container Registry
  acr_id = module.data.acr_id
  
  tags = local.common_tags
}

# Observability Module
module "observability" {
  source = "../../modules/observability"
  
  resource_group_name = azurerm_resource_group.observability.name
  location            = local.region
  
  log_analytics_workspace_name = "${local.org}-${local.environment}-${local.region}-law"
  app_insights_name            = "${local.org}-${local.environment}-${local.region}-ai"
  
  retention_in_days = 90
  
  aks_cluster_id = module.aks.cluster_id
  
  alert_action_group_id = azurerm_monitor_action_group.platform.id
  
  tags = local.common_tags
}

# Data Module
module "data" {
  source = "../../modules/data"
  
  resource_group_name = azurerm_resource_group.data.name
  location            = local.region
  
  # Container Registry
  acr_name     = "${local.org}${local.environment}acr"
  acr_sku      = "Premium"
  acr_geo_replications = ["westus2"]
  
  # PostgreSQL
  postgresql_server_name = "${local.org}-${local.environment}-${local.region}-psql"
  postgresql_sku_name    = "GP_Standard_D4s_v3"
  postgresql_version     = "15"
  postgresql_ha_enabled  = true
  postgresql_backup_retention_days = 35
  
  # Private Endpoints
  private_endpoint_subnet_id = module.spoke_network.subnet_ids["private_endpoints"]
  private_dns_zone_ids       = module.hub_network.private_dns_zone_ids
  
  tags = local.common_tags
}

# Governance Module
module "governance" {
  source = "../../modules/governance"
  
  subscription_id = data.azurerm_subscription.current.subscription_id
  
  allowed_vm_sizes = [
    "Standard_D4s_v5",
    "Standard_D8s_v5",
    "Standard_D16s_v5"
  ]
  
  mandatory_tags = keys(local.common_tags)
  
  monthly_budget = var.monthly_budget
  budget_alert_emails = var.budget_alert_emails
}
```

### Network Hub Module (modules/network/hub/main.tf)

```hcl
# modules/network/hub/main.tf

resource "azurerm_virtual_network" "hub" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  
  ddos_protection_plan {
    id     = var.enable_ddos_protection ? azurerm_network_ddos_protection_plan.main[0].id : null
    enable = var.enable_ddos_protection
  }
  
  tags = var.tags
}

resource "azurerm_network_ddos_protection_plan" "main" {
  count               = var.enable_ddos_protection ? 1 : 0
  name                = "${var.vnet_name}-ddos"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Azure Firewall Subnet
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.firewall_subnet_prefix]
}

# Azure Firewall
resource "azurerm_public_ip" "firewall" {
  name                = "${var.vnet_name}-fw-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_firewall" "main" {
  name                = "${var.vnet_name}-fw"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  zones               = ["1", "2", "3"]
  
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
  
  tags = var.tags
}

# Firewall Policy
resource "azurerm_firewall_policy" "main" {
  name                = "${var.vnet_name}-fw-policy"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  
  dns {
    proxy_enabled = true
  }
  
  tags = var.tags
}

# AKS Required FQDN Rules
resource "azurerm_firewall_policy_rule_collection_group" "aks" {
  name               = "aks-rules"
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = 100
  
  application_rule_collection {
    name     = "aks-required"
    priority = 100
    action   = "Allow"
    
    rule {
      name = "aks-management"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = var.vnet_address_space
      destination_fqdns = [
        "*.hcp.${var.location}.azmk8s.io",
        "mcr.microsoft.com",
        "*.data.mcr.microsoft.com",
        "management.azure.com",
        "login.microsoftonline.com",
        "packages.microsoft.com",
        "acs-mirror.azureedge.net"
      ]
    }
    
    rule {
      name = "azure-monitor"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = var.vnet_address_space
      destination_fqdns = [
        "dc.services.visualstudio.com",
        "*.ods.opinsights.azure.com",
        "*.oms.opinsights.azure.com",
        "*.monitoring.azure.com"
      ]
    }
  }
  
  network_rule_collection {
    name     = "aks-network"
    priority = 200
    action   = "Allow"
    
    rule {
      name                  = "ntp"
      protocols             = ["UDP"]
      source_addresses      = var.vnet_address_space
      destination_addresses = ["*"]
      destination_ports     = ["123"]
    }
  }
}

# Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                       = "firewall-diagnostics"
  target_resource_id         = azurerm_firewall.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id
  
  enabled_log {
    category = "AzureFirewallApplicationRule"
  }
  
  enabled_log {
    category = "AzureFirewallNetworkRule"
  }
  
  enabled_log {
    category = "AzureFirewallDnsProxy"
  }
  
  metric {
    category = "AllMetrics"
  }
}

# Azure Bastion
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.bastion_subnet_prefix]
}

resource "azurerm_public_ip" "bastion" {
  name                = "${var.vnet_name}-bastion-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "main" {
  name                = "${var.vnet_name}-bastion"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
  
  tunneling_enabled = true
  
  tags = var.tags
}
```

### Private DNS Zones (modules/network/hub/dns.tf)

```hcl
# modules/network/hub/dns.tf

resource "azurerm_private_dns_zone" "zones" {
  for_each            = toset(var.private_dns_zones)
  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  for_each              = azurerm_private_dns_zone.zones
  name                  = "${var.vnet_name}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = var.tags
}
```

### AKS Module (modules/aks/main.tf)

```hcl
# modules/aks/main.tf

resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  
  # Private cluster configuration with authorized IP access
  # This enables a hybrid approach: private endpoint for internal access
  # AND public FQDN with IP restrictions for developer/CI-CD access
  private_cluster_enabled             = var.private_cluster_enabled
  private_dns_zone_id                 = var.private_dns_zone_id
  private_cluster_public_fqdn_enabled = var.enable_public_fqdn_for_authorized_ips
  
  # API Server Access Profile - Allow specific IPs to access the cluster
  # This is critical for developer access from laptops, CI/CD runners, etc.
  api_server_access_profile {
    # List of authorized IP ranges (CIDR notation)
    # Examples: "203.0.113.50/32" (single IP), "10.0.0.0/8" (range)
    authorized_ip_ranges = var.api_server_authorized_ip_ranges
    
    # Enable private cluster (API server has private endpoint)
    # When combined with authorized_ip_ranges, creates hybrid access model
    subnet_id                = var.private_cluster_enabled ? var.api_server_subnet_id : null
    vnet_integration_enabled = var.private_cluster_enabled
  }
  
  # Identity
  identity {
    type         = var.identity_type
    identity_ids = var.identity_type == "UserAssigned" ? [var.user_assigned_identity_id] : null
  }
  
  # System node pool
  default_node_pool {
    name                         = var.system_node_pool.name
    vm_size                      = var.system_node_pool.vm_size
    node_count                   = var.system_node_pool.node_count
    min_count                    = var.system_node_pool.min_count
    max_count                    = var.system_node_pool.max_count
    zones                        = var.system_node_pool.availability_zones
    os_disk_size_gb              = var.system_node_pool.os_disk_size_gb
    os_disk_type                 = var.system_node_pool.os_disk_type
    vnet_subnet_id               = var.vnet_subnet_id
    enable_auto_scaling          = true
    only_critical_addons_enabled = var.system_node_pool.only_critical_addons_enabled
    
    upgrade_settings {
      max_surge = "33%"
    }
    
    node_labels = {
      "nodepool-type" = "system"
    }
  }
  
  # Network configuration
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "azure"
    load_balancer_sku   = "standard"
    outbound_type       = "userDefinedRouting"
    service_cidr        = "172.16.0.0/16"
    dns_service_ip      = "172.16.0.10"
  }
  
  # Azure AD integration
  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = var.azure_rbac_enabled
    admin_group_object_ids = var.azure_ad_admin_group_ids
  }
  
  local_account_disabled = var.local_account_disabled
  
  # Addons
  azure_policy_enabled = var.azure_policy_enabled
  
  dynamic "oms_agent" {
    for_each = var.oms_agent_enabled ? [1] : []
    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }
  
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }
  
  workload_identity_enabled = true
  oidc_issuer_enabled       = true
  
  # Maintenance window
  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [2, 3, 4]
    }
  }
  
  # Auto-upgrade
  automatic_channel_upgrade = "patch"
  
  tags = var.tags
  
  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count
    ]
  }
}

# ACR Pull permission
resource "azurerm_role_assignment" "acr_pull" {
  count                = var.acr_id != null ? 1 : 0
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}
```

### Node Pools (modules/aks/node_pools.tf)

```hcl
# modules/aks/node_pools.tf

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  for_each              = var.user_node_pools
  name                  = each.value.name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = each.value.vm_size
  node_count            = each.value.node_count
  min_count             = each.value.min_count
  max_count             = each.value.max_count
  zones                 = each.value.availability_zones
  os_disk_size_gb       = each.value.os_disk_size_gb
  os_disk_type          = each.value.os_disk_type
  vnet_subnet_id        = var.vnet_subnet_id
  enable_auto_scaling   = true
  
  priority        = lookup(each.value, "priority", "Regular")
  eviction_policy = lookup(each.value, "eviction_policy", null)
  spot_max_price  = lookup(each.value, "spot_max_price", null)
  
  node_labels = each.value.node_labels
  node_taints = lookup(each.value, "node_taints", [])
  
  upgrade_settings {
    max_surge = "33%"
  }
  
  tags = var.tags
  
  lifecycle {
    ignore_changes = [
      node_count
    ]
  }
}
```

### Security Module - Key Vault (modules/security/keyvault.tf)

```hcl
# modules/security/keyvault.tf

resource "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium"
  
  enabled_for_disk_encryption     = true
  enabled_for_deployment          = true
  enabled_for_template_deployment = true
  
  purge_protection_enabled   = true
  soft_delete_retention_days = 90
  
  public_network_access_enabled = false
  
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
  
  tags = var.tags
}

# Private Endpoint for Key Vault
resource "azurerm_private_endpoint" "keyvault" {
  name                = "${var.key_vault_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  
  private_service_connection {
    name                           = "${var.key_vault_name}-psc"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
  
  private_dns_zone_group {
    name                 = "keyvault-dns"
    private_dns_zone_ids = [var.private_dns_zone_ids["privatelink.vaultcore.azure.net"]]
  }
  
  tags = var.tags
}

# Access policy for AKS
resource "azurerm_key_vault_access_policy" "aks" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = var.aks_identity_principal_id
  
  secret_permissions = [
    "Get",
    "List"
  ]
  
  certificate_permissions = [
    "Get",
    "List"
  ]
}
```

---

## GitHub Actions Pipelines

### Terraform Infrastructure Pipeline (.github/workflows/terraform.yml)

```yaml
name: Terraform Infrastructure

on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'
  pull_request:
    branches: [main]
    paths:
      - 'terraform/**'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options:
          - dev
          - test
          - prod
      action:
        description: 'Terraform action'
        required: true
        type: choice
        options:
          - plan
          - apply
          - destroy

permissions:
  id-token: write
  contents: read
  pull-requests: write

env:
  TF_VERSION: '1.6.0'
  ARM_USE_OIDC: true
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

jobs:
  # Security scanning
  security-scan:
    name: Security Scan
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Run Checkov
        uses: bridgecrewio/checkov-action@v12
        with:
          directory: terraform/
          framework: terraform
          output_format: sarif
          output_file_path: checkov-results.sarif
          soft_fail: false
          skip_check: CKV_AZURE_35  # Example skip

      - name: Upload SARIF
        uses: github/codeql-action/upload-sarif@v2
        if: always()
        with:
          sarif_file: checkov-results.sarif

      - name: Run tfsec
        uses: aquasecurity/tfsec-action@v1.0.3
        with:
          working_directory: terraform/
          soft_fail: false

  # Terraform validation
  validate:
    name: Validate
    runs-on: ubuntu-latest
    needs: security-scan
    strategy:
      matrix:
        environment: [dev, test, prod]
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Format Check
        run: terraform fmt -check -recursive
        working-directory: terraform/

      - name: Terraform Init
        run: terraform init -backend=false
        working-directory: terraform/environments/${{ matrix.environment }}

      - name: Terraform Validate
        run: terraform validate
        working-directory: terraform/environments/${{ matrix.environment }}

  # Plan for each environment
  plan:
    name: Plan (${{ matrix.environment }})
    runs-on: ubuntu-latest
    needs: validate
    if: github.event_name == 'pull_request' || github.event.inputs.action == 'plan'
    strategy:
      matrix:
        environment: [dev, test, prod]
    environment: ${{ matrix.environment }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Terraform Init
        run: terraform init
        working-directory: terraform/environments/${{ matrix.environment }}
        env:
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}

      - name: Terraform Plan
        id: plan
        run: |
          terraform plan -no-color -out=tfplan \
            -var-file=terraform.tfvars \
            2>&1 | tee plan-output.txt
        working-directory: terraform/environments/${{ matrix.environment }}
        env:
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}

      - name: Upload Plan
        uses: actions/upload-artifact@v4
        with:
          name: tfplan-${{ matrix.environment }}
          path: terraform/environments/${{ matrix.environment }}/tfplan

      - name: Comment PR
        uses: actions/github-script@v7
        if: github.event_name == 'pull_request'
        with:
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('terraform/environments/${{ matrix.environment }}/plan-output.txt', 'utf8');
            const truncatedPlan = plan.length > 60000 ? plan.substring(0, 60000) + '\n... (truncated)' : plan;
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Terraform Plan - ${{ matrix.environment }}
              
              <details>
              <summary>Show Plan</summary>
              
              \`\`\`hcl
              ${truncatedPlan}
              \`\`\`
              
              </details>`
            });

  # Apply with approval
  apply-dev:
    name: Apply (dev)
    runs-on: ubuntu-latest
    needs: plan
    if: github.ref == 'refs/heads/main' && (github.event_name == 'push' || github.event.inputs.action == 'apply')
    environment:
      name: dev
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Download Plan
        uses: actions/download-artifact@v4
        with:
          name: tfplan-dev
          path: terraform/environments/dev

      - name: Terraform Init
        run: terraform init
        working-directory: terraform/environments/dev
        env:
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}

      - name: Terraform Apply
        run: terraform apply -auto-approve tfplan
        working-directory: terraform/environments/dev
        env:
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}

  apply-test:
    name: Apply (test)
    runs-on: ubuntu-latest
    needs: apply-dev
    if: github.ref == 'refs/heads/main'
    environment:
      name: test
      url: https://test.contoso.com
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Download Plan
        uses: actions/download-artifact@v4
        with:
          name: tfplan-test
          path: terraform/environments/test

      - name: Terraform Init
        run: terraform init
        working-directory: terraform/environments/test
        env:
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}

      - name: Terraform Apply
        run: terraform apply -auto-approve tfplan
        working-directory: terraform/environments/test
        env:
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}

  apply-prod:
    name: Apply (prod)
    runs-on: ubuntu-latest
    needs: apply-test
    if: github.ref == 'refs/heads/main'
    environment:
      name: prod
      url: https://prod.contoso.com
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Download Plan
        uses: actions/download-artifact@v4
        with:
          name: tfplan-prod
          path: terraform/environments/prod

      - name: Terraform Init
        run: terraform init
        working-directory: terraform/environments/prod
        env:
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}

      - name: Terraform Apply
        run: terraform apply -auto-approve tfplan
        working-directory: terraform/environments/prod
        env:
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
```

### Application CI/CD Pipeline (.github/workflows/app-deploy.yml)

```yaml
name: Application Build and Deploy

on:
  push:
    branches: [main]
    paths:
      - 'src/**'
      - 'charts/**'
  pull_request:
    branches: [main]
    paths:
      - 'src/**'
      - 'charts/**'

permissions:
  id-token: write
  contents: read
  packages: write
  security-events: write

env:
  ACR_NAME: contosoprodacr
  IMAGE_NAME: myapp
  HELM_VERSION: '3.13.0'

jobs:
  # Build and test
  build:
    name: Build and Test
    runs-on: ubuntu-latest
    outputs:
      image_tag: ${{ steps.meta.outputs.tags }}
      image_digest: ${{ steps.build.outputs.digest }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install Dependencies
        run: npm ci

      - name: Run Unit Tests
        run: npm run test:unit -- --coverage

      - name: Run Integration Tests
        run: npm run test:integration

      - name: Upload Coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info

      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: ACR Login
        run: az acr login --name ${{ env.ACR_NAME }}

      - name: Docker Meta
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.ACR_NAME }}.azurecr.io/${{ env.IMAGE_NAME }}
          tags: |
            type=sha,prefix=
            type=ref,event=branch
            type=ref,event=pr

      - name: Build and Push
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=registry,ref=${{ env.ACR_NAME }}.azurecr.io/${{ env.IMAGE_NAME }}:buildcache
          cache-to: type=registry,ref=${{ env.ACR_NAME }}.azurecr.io/${{ env.IMAGE_NAME }}:buildcache,mode=max

  # Security scanning
  security-scan:
    name: Security Scan
    runs-on: ubuntu-latest
    needs: build
    if: github.event_name != 'pull_request'
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: ACR Login
        run: az acr login --name ${{ env.ACR_NAME }}

      - name: Run Trivy Scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ needs.build.outputs.image_tag }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'

      - name: Upload Trivy Results
        uses: github/codeql-action/upload-sarif@v2
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: ${{ needs.build.outputs.image_tag }}
          format: spdx-json
          output-file: sbom.spdx.json

      - name: Upload SBOM
        uses: actions/upload-artifact@v4
        with:
          name: sbom
          path: sbom.spdx.json

  # Deploy to dev
  deploy-dev:
    name: Deploy (dev)
    runs-on: ubuntu-latest
    needs: [build, security-scan]
    environment:
      name: dev
      url: https://dev.contoso.com
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Get AKS Credentials
        run: |
          az aks get-credentials \
            --resource-group contoso-dev-eastus-rg-aks \
            --name contoso-dev-eastus-aks \
            --overwrite-existing

      - name: Setup Helm
        uses: azure/setup-helm@v3
        with:
          version: ${{ env.HELM_VERSION }}

      - name: Deploy with Helm
        run: |
          helm upgrade --install ${{ env.IMAGE_NAME }} ./charts/${{ env.IMAGE_NAME }} \
            --namespace app-team-a-dev \
            --create-namespace \
            --values ./charts/${{ env.IMAGE_NAME }}/values-dev.yaml \
            --set image.tag=${{ github.sha }} \
            --set image.repository=${{ env.ACR_NAME }}.azurecr.io/${{ env.IMAGE_NAME }} \
            --wait \
            --timeout 10m

      - name: Verify Deployment
        run: |
          kubectl rollout status deployment/${{ env.IMAGE_NAME }} \
            -n app-team-a-dev \
            --timeout=5m

  # Deploy to prod with canary
  deploy-prod:
    name: Deploy (prod)
    runs-on: ubuntu-latest
    needs: deploy-dev
    environment:
      name: prod
      url: https://prod.contoso.com
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Get AKS Credentials
        run: |
          az aks get-credentials \
            --resource-group contoso-prod-eastus-rg-aks \
            --name contoso-prod-eastus-aks \
            --overwrite-existing

      - name: Setup Helm
        uses: azure/setup-helm@v3
        with:
          version: ${{ env.HELM_VERSION }}

      - name: Deploy Canary (10%)
        run: |
          helm upgrade --install ${{ env.IMAGE_NAME }}-canary ./charts/${{ env.IMAGE_NAME }} \
            --namespace app-team-a-prod \
            --values ./charts/${{ env.IMAGE_NAME }}/values-prod.yaml \
            --set image.tag=${{ github.sha }} \
            --set image.repository=${{ env.ACR_NAME }}.azurecr.io/${{ env.IMAGE_NAME }} \
            --set canary.enabled=true \
            --set canary.weight=10 \
            --wait \
            --timeout 10m

      - name: Monitor Canary (5 min)
        run: |
          echo "Monitoring canary deployment for 5 minutes..."
          sleep 300
          
          # Check error rate
          ERROR_RATE=$(kubectl exec -n monitoring prometheus-0 -- \
            promtool query instant 'sum(rate(http_requests_total{status=~"5..",app="${{ env.IMAGE_NAME }}-canary"}[5m])) / sum(rate(http_requests_total{app="${{ env.IMAGE_NAME }}-canary"}[5m])) * 100' \
            | grep -oP '\d+\.\d+' || echo "0")
          
          if (( $(echo "$ERROR_RATE > 1" | bc -l) )); then
            echo "Error rate too high: $ERROR_RATE%"
            exit 1
          fi

      - name: Promote to Full Deployment
        run: |
          helm upgrade --install ${{ env.IMAGE_NAME }} ./charts/${{ env.IMAGE_NAME }} \
            --namespace app-team-a-prod \
            --values ./charts/${{ env.IMAGE_NAME }}/values-prod.yaml \
            --set image.tag=${{ github.sha }} \
            --set image.repository=${{ env.ACR_NAME }}.azurecr.io/${{ env.IMAGE_NAME }} \
            --wait \
            --timeout 10m
          
          # Remove canary
          helm uninstall ${{ env.IMAGE_NAME }}-canary -n app-team-a-prod || true

      - name: Verify Deployment
        run: |
          kubectl rollout status deployment/${{ env.IMAGE_NAME }} \
            -n app-team-a-prod \
            --timeout=5m
```

---

## Kubernetes Deployment Examples

### Helm Chart Structure

```
charts/
└── myapp/
    ├── Chart.yaml
    ├── values.yaml
    ├── values-dev.yaml
    ├── values-test.yaml
    ├── values-prod.yaml
    ├── templates/
    │   ├── _helpers.tpl
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   ├── ingress.yaml
    │   ├── hpa.yaml
    │   ├── pdb.yaml
    │   ├── serviceaccount.yaml
    │   ├── servicemonitor.yaml
    │   ├── configmap.yaml
    │   ├── secret-provider-class.yaml
    │   └── networkpolicy.yaml
    └── tests/
        └── test-connection.yaml
```

### Chart.yaml

```yaml
apiVersion: v2
name: myapp
description: Enterprise application Helm chart
type: application
version: 1.0.0
appVersion: "1.0.0"
keywords:
  - enterprise
  - aks
maintainers:
  - name: Platform Team
    email: platform@contoso.com
dependencies:
  - name: common
    version: "1.x.x"
    repository: "https://charts.bitnami.com/bitnami"
```

### values-prod.yaml

```yaml
# Production values
replicaCount: 3

image:
  repository: contosoprodacr.azurecr.io/myapp
  pullPolicy: Always
  tag: ""  # Set by CI/CD

serviceAccount:
  create: true
  annotations:
    azure.workload.identity/client-id: "00000000-0000-0000-0000-000000000000"
  name: myapp

podAnnotations:
  azure.workload.identity/use: "true"

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
      - ALL

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 50
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
        - type: Pods
          value: 4
          periodSeconds: 15
      selectPolicy: Max

pdb:
  enabled: true
  minAvailable: 2

nodeSelector:
  workload-type: general

tolerations: []

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                  - myapp
          topologyKey: topology.kubernetes.io/zone

topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: myapp

service:
  type: ClusterIP
  port: 80
  targetPort: 8080

ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: api.contoso.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: api-tls
      hosts:
        - api.contoso.com

probes:
  liveness:
    httpGet:
      path: /health/live
      port: http
    initialDelaySeconds: 10
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
  readiness:
    httpGet:
      path: /health/ready
      port: http
    initialDelaySeconds: 5
    periodSeconds: 5
    timeoutSeconds: 3
    failureThreshold: 3
  startup:
    httpGet:
      path: /health/startup
      port: http
    initialDelaySeconds: 0
    periodSeconds: 5
    timeoutSeconds: 3
    failureThreshold: 30

secretsProvider:
  enabled: true
  provider: azure
  keyvaultName: contoso-prod-eastus-kv
  tenantId: "00000000-0000-0000-0000-000000000000"
  secrets:
    - objectName: db-connection-string
      objectType: secret
    - objectName: api-key
      objectType: secret

env:
  - name: ASPNETCORE_ENVIRONMENT
    value: Production
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: http://otel-collector.monitoring:4317

serviceMonitor:
  enabled: true
  interval: 30s
  path: /metrics
  labels:
    release: prometheus

networkPolicy:
  enabled: true
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
      ports:
        - protocol: TCP
          port: 8080
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: monitoring
      ports:
        - protocol: TCP
          port: 4317
    - to:
        - ipBlock:
            cidr: 10.1.5.0/24  # Private endpoints subnet
      ports:
        - protocol: TCP
          port: 5432
        - protocol: TCP
          port: 443
```

### Deployment Template (templates/deployment.yaml)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "myapp.fullname" . }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "myapp.selectorLabels" . | nindent 6 }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 0
  template:
    metadata:
      annotations:
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
      labels:
        {{- include "myapp.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "myapp.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      {{- with .Values.topologySpreadConstraints }}
      topologySpreadConstraints:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.targetPort }}
              protocol: TCP
          {{- with .Values.probes.liveness }}
          livenessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.probes.readiness }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.probes.startup }}
          startupProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          env:
            {{- toYaml .Values.env | nindent 12 }}
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            {{- if .Values.secretsProvider.enabled }}
            - name: secrets-store
              mountPath: /mnt/secrets-store
              readOnly: true
            {{- end }}
      volumes:
        - name: tmp
          emptyDir: {}
        {{- if .Values.secretsProvider.enabled }}
        - name: secrets-store
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: {{ include "myapp.fullname" . }}
        {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

### HPA Template (templates/hpa.yaml)

```yaml
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "myapp.fullname" . }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "myapp.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
  {{- with .Values.autoscaling.behavior }}
  behavior:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
```

### PDB Template (templates/pdb.yaml)

```yaml
{{- if .Values.pdb.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "myapp.fullname" . }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
spec:
  {{- if .Values.pdb.minAvailable }}
  minAvailable: {{ .Values.pdb.minAvailable }}
  {{- end }}
  {{- if .Values.pdb.maxUnavailable }}
  maxUnavailable: {{ .Values.pdb.maxUnavailable }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "myapp.selectorLabels" . | nindent 6 }}
{{- end }}
```

### Secret Provider Class (templates/secret-provider-class.yaml)

```yaml
{{- if .Values.secretsProvider.enabled }}
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: {{ include "myapp.fullname" . }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
spec:
  provider: {{ .Values.secretsProvider.provider }}
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "false"
    clientID: {{ .Values.serviceAccount.annotations | get "azure.workload.identity/client-id" }}
    keyvaultName: {{ .Values.secretsProvider.keyvaultName }}
    tenantId: {{ .Values.secretsProvider.tenantId }}
    objects: |
      array:
        {{- range .Values.secretsProvider.secrets }}
        - |
          objectName: {{ .objectName }}
          objectType: {{ .objectType }}
        {{- end }}
{{- end }}
```

---

## OPA Gatekeeper Policies

### Constraint Templates

#### Require Non-Root User (templates/k8srequirenonroot.yaml)

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequirenonroot
  annotations:
    description: Requires containers to run as non-root user
spec:
  crd:
    spec:
      names:
        kind: K8sRequireNonRoot
      validation:
        openAPIV3Schema:
          type: object
          properties:
            exemptImages:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequirenonroot

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not is_exempt(container.image)
          not container.securityContext.runAsNonRoot
          msg := sprintf("Container %v must set securityContext.runAsNonRoot to true", [container.name])
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not is_exempt(container.image)
          container.securityContext.runAsUser == 0
          msg := sprintf("Container %v must not run as root (runAsUser: 0)", [container.name])
        }

        is_exempt(image) {
          exempt := input.parameters.exemptImages[_]
          startswith(image, exempt)
        }
```

#### Require Resource Limits (templates/k8srequireresources.yaml)

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequireresources
  annotations:
    description: Requires containers to have resource requests and limits
spec:
  crd:
    spec:
      names:
        kind: K8sRequireResources
      validation:
        openAPIV3Schema:
          type: object
          properties:
            exemptImages:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequireresources

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not is_exempt(container.image)
          not container.resources.limits.cpu
          msg := sprintf("Container %v must specify resources.limits.cpu", [container.name])
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not is_exempt(container.image)
          not container.resources.limits.memory
          msg := sprintf("Container %v must specify resources.limits.memory", [container.name])
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not is_exempt(container.image)
          not container.resources.requests.cpu
          msg := sprintf("Container %v must specify resources.requests.cpu", [container.name])
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not is_exempt(container.image)
          not container.resources.requests.memory
          msg := sprintf("Container %v must specify resources.requests.memory", [container.name])
        }

        is_exempt(image) {
          exempt := input.parameters.exemptImages[_]
          startswith(image, exempt)
        }
```

#### Block Privileged Containers (templates/k8sblockprivileged.yaml)

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sblockprivileged
  annotations:
    description: Blocks privileged containers and privilege escalation
spec:
  crd:
    spec:
      names:
        kind: K8sBlockPrivileged
      validation:
        openAPIV3Schema:
          type: object
          properties:
            exemptImages:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sblockprivileged

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not is_exempt(container.image)
          container.securityContext.privileged
          msg := sprintf("Container %v must not run as privileged", [container.name])
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not is_exempt(container.image)
          container.securityContext.allowPrivilegeEscalation
          msg := sprintf("Container %v must set allowPrivilegeEscalation to false", [container.name])
        }

        is_exempt(image) {
          exempt := input.parameters.exemptImages[_]
          startswith(image, exempt)
        }
```

#### Allowed Registries (templates/k8sallowedregistries.yaml)

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sallowedregistries
  annotations:
    description: Requires container images to come from allowed registries
spec:
  crd:
    spec:
      names:
        kind: K8sAllowedRegistries
      validation:
        openAPIV3Schema:
          type: object
          properties:
            registries:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sallowedregistries

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not registry_allowed(container.image)
          msg := sprintf("Container %v uses image %v from disallowed registry. Allowed registries: %v", [container.name, container.image, input.parameters.registries])
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.initContainers[_]
          not registry_allowed(container.image)
          msg := sprintf("Init container %v uses image %v from disallowed registry. Allowed registries: %v", [container.name, container.image, input.parameters.registries])
        }

        registry_allowed(image) {
          registry := input.parameters.registries[_]
          startswith(image, registry)
        }
```

### Constraint Instances

```yaml
# constraints/require-nonroot.yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequireNonRoot
metadata:
  name: require-nonroot
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    namespaces:
      - "app-team-a-prod"
      - "app-team-b-prod"
  parameters:
    exemptImages:
      - "mcr.microsoft.com/"

---
# constraints/require-resources.yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequireResources
metadata:
  name: require-resources
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    namespaces:
      - "app-team-a-prod"
      - "app-team-b-prod"
  parameters:
    exemptImages:
      - "mcr.microsoft.com/"

---
# constraints/allowed-registries.yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sAllowedRegistries
metadata:
  name: allowed-registries
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    namespaces:
      - "app-team-a-prod"
      - "app-team-b-prod"
  parameters:
    registries:
      - "contosoprodacr.azurecr.io/"
      - "mcr.microsoft.com/"
```

---

## Observability Configuration

### Prometheus ServiceMonitor Examples

```yaml
# monitoring/servicemonitor-apps.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: application-metrics
  namespace: monitoring
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/monitored: "true"
  namespaceSelector:
    matchNames:
      - app-team-a-prod
      - app-team-b-prod
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
      scrapeTimeout: 10s
      honorLabels: true

---
# monitoring/podmonitor-sidecars.yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: sidecar-metrics
  namespace: monitoring
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      sidecar.istio.io/inject: "true"
  namespaceSelector:
    any: true
  podMetricsEndpoints:
    - port: http-envoy-prom
      path: /stats/prometheus
      interval: 15s
```

### Prometheus Rules for SLO Monitoring

```yaml
# monitoring/prometheus-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: slo-rules
  namespace: monitoring
  labels:
    release: prometheus
spec:
  groups:
    - name: slo.rules
      interval: 30s
      rules:
        # Error budget calculation
        - record: slo:error_budget:ratio
          expr: |
            1 - (
              sum(rate(http_requests_total{status=~"5.."}[30d]))
              /
              sum(rate(http_requests_total[30d]))
            )
        
        # Burn rate (1h window)
        - record: slo:burn_rate:1h
          expr: |
            sum(rate(http_requests_total{status=~"5.."}[1h]))
            /
            sum(rate(http_requests_total[1h]))
            /
            (1 - 0.999)  # 99.9% SLO
        
        # Burn rate (6h window)
        - record: slo:burn_rate:6h
          expr: |
            sum(rate(http_requests_total{status=~"5.."}[6h]))
            /
            sum(rate(http_requests_total[6h]))
            /
            (1 - 0.999)
        
        # Latency SLI (p99 < 500ms)
        - record: slo:latency_sli:ratio
          expr: |
            sum(rate(http_request_duration_seconds_bucket{le="0.5"}[5m]))
            /
            sum(rate(http_request_duration_seconds_count[5m]))

    - name: slo.alerts
      rules:
        # Sev0: High burn rate (page immediately)
        - alert: SLOBurnRateCritical
          expr: slo:burn_rate:1h > 14.4 and slo:burn_rate:6h > 6
          for: 2m
          labels:
            severity: sev0
            team: platform
          annotations:
            summary: "High SLO burn rate detected"
            description: "Error budget is being consumed at {{ $value }}x the sustainable rate"
            runbook_url: "https://runbooks.contoso.com/slo-burn-rate"
        
        # Sev1: Elevated burn rate (page during business hours)
        - alert: SLOBurnRateElevated
          expr: slo:burn_rate:1h > 6 and slo:burn_rate:6h > 3
          for: 5m
          labels:
            severity: sev1
            team: platform
          annotations:
            summary: "Elevated SLO burn rate"
            description: "Error budget consumption is elevated at {{ $value }}x sustainable rate"
            runbook_url: "https://runbooks.contoso.com/slo-burn-rate"
        
        # Latency SLO breach
        - alert: LatencySLOBreach
          expr: slo:latency_sli:ratio < 0.99
          for: 5m
          labels:
            severity: sev1
            team: platform
          annotations:
            summary: "Latency SLO breach"
            description: "Only {{ $value | humanizePercentage }} of requests are meeting the 500ms latency target"
            runbook_url: "https://runbooks.contoso.com/latency-slo"

    - name: infrastructure.alerts
      rules:
        # Pod crash loop
        - alert: PodCrashLooping
          expr: |
            increase(kube_pod_container_status_restarts_total[15m]) > 3
          for: 3m
          labels:
            severity: sev1
            team: platform
          annotations:
            summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping"
            description: "Pod has restarted {{ $value }} times in the last 15 minutes"
            runbook_url: "https://runbooks.contoso.com/pod-crash-loop"
        
        # High memory usage
        - alert: ContainerMemoryHigh
          expr: |
            container_memory_working_set_bytes / container_spec_memory_limit_bytes > 0.9
          for: 5m
          labels:
            severity: sev2
            team: platform
          annotations:
            summary: "Container {{ $labels.container }} memory usage high"
            description: "Memory usage is at {{ $value | humanizePercentage }}"
            runbook_url: "https://runbooks.contoso.com/memory-pressure"
        
        # Node not ready
        - alert: NodeNotReady
          expr: kube_node_status_condition{condition="Ready",status="true"} == 0
          for: 5m
          labels:
            severity: sev1
            team: platform
          annotations:
            summary: "Node {{ $labels.node }} is not ready"
            description: "Node has been in NotReady state for more than 5 minutes"
            runbook_url: "https://runbooks.contoso.com/node-not-ready"
        
        # Cluster autoscaler unable to scale
        - alert: ClusterAutoscalerUnableToScale
          expr: |
            cluster_autoscaler_unschedulable_pods_count > 0
          for: 5m
          labels:
            severity: sev1
            team: platform
          annotations:
            summary: "Cluster autoscaler unable to schedule pods"
            description: "{{ $value }} pods are unschedulable"
            runbook_url: "https://runbooks.contoso.com/autoscaler-issues"

    - name: database.alerts
      rules:
        # Connection pool exhaustion warning
        - alert: DatabaseConnectionPoolWarning
          expr: |
            pgbouncer_pools_client_active_connections 
            / pgbouncer_pools_client_maxwait_connections > 0.8
          for: 2m
          labels:
            severity: sev2
            team: platform
          annotations:
            summary: "Database connection pool at 80% capacity"
            description: "Connection pool utilization is {{ $value | humanizePercentage }}"
            runbook_url: "https://runbooks.contoso.com/connection-pool"
        
        # Connection pool exhaustion critical
        - alert: DatabaseConnectionPoolCritical
          expr: |
            pgbouncer_pools_client_active_connections 
            / pgbouncer_pools_client_maxwait_connections > 0.95
          for: 1m
          labels:
            severity: sev1
            team: platform
          annotations:
            summary: "Database connection pool at 95% capacity"
            description: "Connection pool is nearly exhausted at {{ $value | humanizePercentage }}"
            runbook_url: "https://runbooks.contoso.com/connection-pool"
```

### Grafana Dashboard JSON (Cluster Overview)

```json
{
  "annotations": {
    "list": [
      {
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Deployments",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 1,
  "id": null,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "green", "value": null},
              {"color": "yellow", "value": 70},
              {"color": "red", "value": 90}
            ]
          },
          "unit": "percent"
        }
      },
      "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0},
      "id": 1,
      "options": {
        "orientation": "auto",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        },
        "showThresholdLabels": false,
        "showThresholdMarkers": true
      },
      "pluginVersion": "10.0.0",
      "targets": [
        {
          "expr": "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
          "legendFormat": "CPU Usage",
          "refId": "A"
        }
      ],
      "title": "Cluster CPU Usage",
      "type": "gauge"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "green", "value": null},
              {"color": "yellow", "value": 70},
              {"color": "red", "value": 90}
            ]
          },
          "unit": "percent"
        }
      },
      "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0},
      "id": 2,
      "options": {
        "orientation": "auto",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        }
      },
      "targets": [
        {
          "expr": "(1 - (sum(node_memory_MemAvailable_bytes) / sum(node_memory_MemTotal_bytes))) * 100",
          "legendFormat": "Memory Usage",
          "refId": "A"
        }
      ],
      "title": "Cluster Memory Usage",
      "type": "gauge"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {"mode": "thresholds"},
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "green", "value": null}
            ]
          }
        }
      },
      "gridPos": {"h": 4, "w": 3, "x": 12, "y": 0},
      "id": 3,
      "options": {
        "colorMode": "value",
        "graphMode": "none",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      },
      "targets": [
        {
          "expr": "count(kube_node_info)",
          "legendFormat": "Nodes",
          "refId": "A"
        }
      ],
      "title": "Total Nodes",
      "type": "stat"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {"mode": "thresholds"},
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "green", "value": null}
            ]
          }
        }
      },
      "gridPos": {"h": 4, "w": 3, "x": 15, "y": 0},
      "id": 4,
      "targets": [
        {
          "expr": "count(kube_pod_info)",
          "legendFormat": "Pods",
          "refId": "A"
        }
      ],
      "title": "Total Pods",
      "type": "stat"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "custom": {
            "drawStyle": "line",
            "lineInterpolation": "smooth",
            "lineWidth": 2,
            "fillOpacity": 10
          },
          "unit": "reqps"
        }
      },
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
      "id": 5,
      "targets": [
        {
          "expr": "sum(rate(http_requests_total[5m]))",
          "legendFormat": "Total Requests",
          "refId": "A"
        },
        {
          "expr": "sum(rate(http_requests_total{status=~\"5..\"}[5m]))",
          "legendFormat": "5xx Errors",
          "refId": "B"
        }
      ],
      "title": "Request Rate",
      "type": "timeseries"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "custom": {
            "drawStyle": "line",
            "lineInterpolation": "smooth"
          },
          "unit": "s"
        }
      },
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
      "id": 6,
      "targets": [
        {
          "expr": "histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))",
          "legendFormat": "p50",
          "refId": "A"
        },
        {
          "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))",
          "legendFormat": "p95",
          "refId": "B"
        },
        {
          "expr": "histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))",
          "legendFormat": "p99",
          "refId": "C"
        }
      ],
      "title": "Request Latency",
      "type": "timeseries"
    }
  ],
  "refresh": "30s",
  "schemaVersion": 38,
  "style": "dark",
  "tags": ["kubernetes", "aks", "overview"],
  "templating": {
    "list": [
      {
        "current": {},
        "datasource": "Prometheus",
        "definition": "label_values(kube_namespace_labels, namespace)",
        "name": "namespace",
        "query": "label_values(kube_namespace_labels, namespace)",
        "refresh": 2,
        "type": "query"
      }
    ]
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "title": "AKS Cluster Overview",
  "uid": "aks-cluster-overview",
  "version": 1
}
```

### OpenTelemetry Collector Configuration

```yaml
# monitoring/otel-collector-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector-config
  namespace: monitoring
data:
  config.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
      
      prometheus:
        config:
          scrape_configs:
            - job_name: 'otel-collector'
              scrape_interval: 10s
              static_configs:
                - targets: ['localhost:8888']
      
      k8s_cluster:
        collection_interval: 30s
        node_conditions_to_report:
          - Ready
          - MemoryPressure
          - DiskPressure
        allocatable_types_to_report:
          - cpu
          - memory

    processors:
      batch:
        timeout: 10s
        send_batch_size: 1024
      
      memory_limiter:
        check_interval: 1s
        limit_mib: 1000
        spike_limit_mib: 200
      
      resource:
        attributes:
          - key: environment
            value: production
            action: upsert
          - key: cluster
            value: contoso-prod-eastus-aks
            action: upsert
      
      k8sattributes:
        auth_type: serviceAccount
        passthrough: false
        extract:
          metadata:
            - k8s.pod.name
            - k8s.pod.uid
            - k8s.deployment.name
            - k8s.namespace.name
            - k8s.node.name
          labels:
            - tag_name: app
              key: app.kubernetes.io/name
            - tag_name: version
              key: app.kubernetes.io/version

    exporters:
      azuremonitor:
        connection_string: ${APPLICATIONINSIGHTS_CONNECTION_STRING}
      
      prometheus:
        endpoint: "0.0.0.0:8889"
        namespace: otel
      
      logging:
        loglevel: info

    extensions:
      health_check:
        endpoint: 0.0.0.0:13133
      
      zpages:
        endpoint: 0.0.0.0:55679

    service:
      extensions: [health_check, zpages]
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, k8sattributes, resource, batch]
          exporters: [azuremonitor, logging]
        
        metrics:
          receivers: [otlp, prometheus, k8s_cluster]
          processors: [memory_limiter, k8sattributes, resource, batch]
          exporters: [prometheus, azuremonitor]
        
        logs:
          receivers: [otlp]
          processors: [memory_limiter, k8sattributes, resource, batch]
          exporters: [azuremonitor, logging]

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector
  namespace: monitoring
spec:
  replicas: 2
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      serviceAccountName: otel-collector
      containers:
        - name: otel-collector
          image: otel/opentelemetry-collector-contrib:0.88.0
          args:
            - --config=/conf/config.yaml
          ports:
            - containerPort: 4317  # OTLP gRPC
            - containerPort: 4318  # OTLP HTTP
            - containerPort: 8889  # Prometheus exporter
            - containerPort: 13133 # Health check
          env:
            - name: APPLICATIONINSIGHTS_CONNECTION_STRING
              valueFrom:
                secretKeyRef:
                  name: app-insights
                  key: connection-string
          volumeMounts:
            - name: config
              mountPath: /conf
          resources:
            limits:
              cpu: 1000m
              memory: 2Gi
            requests:
              cpu: 200m
              memory: 400Mi
          livenessProbe:
            httpGet:
              path: /
              port: 13133
          readinessProbe:
            httpGet:
              path: /
              port: 13133
      volumes:
        - name: config
          configMap:
            name: otel-collector-config
```

---

## Production Incident Response Flows

### Incident 1: API Latency Spike (Requirement 25)

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                        API LATENCY SPIKE INCIDENT RESPONSE                               │
└─────────────────────────────────────────────────────────────────────────────────────────┘

Timeline: T+0 to T+30 minutes

┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│ App      │     │ App      │     │ Prometheus│    │ Alert    │     │ PagerDuty│
│ Insights │     │ Service  │     │           │    │ Manager  │     │          │
└────┬─────┘     └────┬─────┘     └─────┬─────┘    └────┬─────┘     └────┬─────┘
     │                │                 │               │                │
     │ T+0: Latency   │                 │               │                │
     │ increases      │                 │               │                │
     │ 50ms → 3s      │                 │               │                │
     │◄───────────────┤                 │               │                │
     │                │                 │               │                │
     │ T+1min: Detect │                 │               │                │
     │ anomaly        │                 │               │                │
     ├────────────────┼────────────────►│               │                │
     │                │                 │               │                │
     │                │                 │ T+2min: p99   │                │
     │                │                 │ > 500ms for   │                │
     │                │                 │ 2 minutes     │                │
     │                │                 ├──────────────►│                │
     │                │                 │               │                │
     │                │                 │               │ T+2min: Fire   │
     │                │                 │               │ Sev1 alert     │
     │                │                 │               ├───────────────►│
     │                │                 │               │                │
     │                │                 │               │                │ T+2min: Page
     │                │                 │               │                │ on-call SRE
     │                │                 │               │                ├──────────►
     │                │                 │               │                │
     │ T+3min: SRE    │                 │               │                │
     │ opens trace    │                 │               │                │
     │ links in alert │                 │               │                │
     │◄───────────────┼─────────────────┼───────────────┼────────────────┤
     │                │                 │               │                │
     │ T+5min: Identify slow span      │               │                │
     │ (database query taking 2.5s)    │               │                │
     ├─────────────────────────────────►│               │                │
     │                │                 │               │                │
     │ T+10min: Check │                 │               │                │
     │ deployment     │                 │               │                │
     │ timeline       │                 │               │                │
     │◄───────────────┤                 │               │                │
     │                │                 │               │                │
     │ T+15min: Correlate with         │               │                │
     │ recent deployment (missing index)│               │                │
     ├─────────────────────────────────►│               │                │
     │                │                 │               │                │
     │ T+20min: Rollback deployment    │               │                │
     │◄───────────────┼─────────────────┼───────────────┼────────────────┤
     │                │                 │               │                │
     │ T+25min: Latency returns to     │               │                │
     │ normal (50ms)  │                 │               │                │
     ├────────────────┼────────────────►│               │                │
     │                │                 │               │                │
     │                │                 │ T+30min:      │                │
     │                │                 │ Alert resolves│                │
     │                │                 ├──────────────►│                │
     │                │                 │               │                │
```

**Automated Response Mechanisms:**
1. Application Insights detects latency anomaly within 2 minutes
2. Alert includes direct links to distributed traces showing slow spans
3. Grafana dashboard auto-refreshes with latency percentiles
4. If deployment correlation detected, alert highlights recent deployment
5. One-click rollback available in deployment dashboard

### Incident 2: Database Connection Exhaustion (Requirement 26)

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                    DATABASE CONNECTION EXHAUSTION RESPONSE                               │
└─────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│ PgBouncer│     │ Prometheus│    │ Alert    │     │ KEDA     │     │ Grafana  │
│          │     │           │    │ Manager  │     │          │     │          │
└────┬─────┘     └─────┬─────┘    └────┬─────┘     └────┬─────┘     └────┬─────┘
     │                 │               │                │                │
     │ Connections at  │               │                │                │
     │ 80% capacity    │               │                │                │
     ├────────────────►│               │                │                │
     │                 │               │                │                │
     │                 │ Fire warning  │                │                │
     │                 │ alert (Sev2)  │                │                │
     │                 ├──────────────►│                │                │
     │                 │               │                │                │
     │                 │               │ Notify Teams   │                │
     │                 │               ├───────────────►│                │
     │                 │               │                │                │
     │ Connections at  │               │                │                │
     │ 95% capacity    │               │                │                │
     ├────────────────►│               │                │                │
     │                 │               │                │                │
     │                 │ Fire critical │                │                │
     │                 │ alert (Sev1)  │                │                │
     │                 ├──────────────►│                │                │
     │                 │               │                │                │
     │                 │               │ Page on-call   │                │
     │                 │               ├───────────────►│                │
     │                 │               │                │                │
     │                 │ Trigger KEDA  │                │                │
     │                 │ scale event   │                │                │
     │                 ├───────────────┼───────────────►│                │
     │                 │               │                │                │
     │                 │               │                │ Scale PgBouncer│
     │                 │               │                │ replicas 2→4   │
     │◄────────────────┼───────────────┼────────────────┤                │
     │                 │               │                │                │
     │ Queue new       │               │                │                │
     │ connections     │               │                │                │
     │ (don't reject)  │               │                │                │
     ├────────────────►│               │                │                │
     │                 │               │                │                │
     │                 │               │                │                │ Display
     │                 │               │                │                │ connection
     │                 │               │                │                │ metrics
     │                 ├───────────────┼───────────────┼───────────────►│
     │                 │               │                │                │
     │ Connections     │               │                │                │
     │ normalize       │               │                │                │
     ├────────────────►│               │                │                │
     │                 │               │                │                │
     │                 │ Alert resolves│                │                │
     │                 ├──────────────►│                │                │
     │                 │               │                │                │
```

**Automated Response Mechanisms:**
1. PgBouncer queues connections instead of rejecting (graceful degradation)
2. KEDA automatically scales PgBouncer replicas based on connection metrics
3. Runbook link in alert for identifying connection leaks
4. Grafana shows connection pool utilization, wait time, query duration

### Incident 3: Pod Crash Loops (Requirement 27)

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                         POD CRASH LOOP INCIDENT RESPONSE                                 │
└─────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│ Kubelet  │     │ Prometheus│    │ Alert    │     │ Argo     │     │ Log      │
│          │     │           │    │ Manager  │     │ Rollouts │     │ Analytics│
└────┬─────┘     └─────┬─────┘    └────┬─────┘     └────┬─────┘     └────┬─────┘
     │                 │               │                │                │
     │ Pod restarts    │               │                │                │
     │ (OOMKilled)     │               │                │                │
     ├────────────────►│               │                │                │
     │                 │               │                │                │
     │ 3 restarts in   │               │                │                │
     │ 15 minutes      │               │                │                │
     ├────────────────►│               │                │                │
     │                 │               │                │                │
     │                 │ T+3min: Fire  │                │                │
     │                 │ Sev1 alert    │                │                │
     │                 ├──────────────►│                │                │
     │                 │               │                │                │
     │                 │               │ Include pod    │                │
     │                 │               │ logs, events,  │                │
     │                 │               │ resource metrics                │
     │                 │               ├───────────────►│                │
     │                 │               │                │                │
     │                 │               │                │                │ Store crash
     │                 │               │                │                │ logs for
     │                 │               │                │                │ analysis
     │                 │               │                ├───────────────►│
     │                 │               │                │                │
     │ Check if >50%   │               │                │                │
     │ replicas affected               │                │                │
     ├────────────────►│               │                │                │
     │                 │               │                │                │
     │                 │ Escalate to   │                │                │
     │                 │ Sev0 if >50%  │                │                │
     │                 ├──────────────►│                │                │
     │                 │               │                │                │
     │ Check if within │               │                │                │
     │ 10min of deploy │               │                │                │
     ├────────────────►│               │                │                │
     │                 │               │                │                │
     │                 │ Trigger auto  │                │                │
     │                 │ rollback      │                │                │
     │                 ├───────────────┼───────────────►│                │
     │                 │               │                │                │
     │                 │               │                │ Rollback to    │
     │                 │               │                │ previous       │
     │                 │               │                │ revision       │
     │◄────────────────┼───────────────┼────────────────┤                │
     │                 │               │                │                │
     │ Pods stabilize  │               │                │                │
     ├────────────────►│               │                │                │
     │                 │               │                │                │
     │                 │ Alert resolves│                │                │
     │                 ├──────────────►│                │                │
     │                 │               │                │                │
```

**Automated Response Mechanisms:**
1. Alert fires within 3 minutes of CrashLoopBackOff
2. Alert context includes pod logs, events, and resource metrics
3. Automatic escalation to Sev0 if >50% replicas affected
4. Auto-rollback if crash occurs within 10 minutes of deployment
5. Crash logs retained in Log Analytics for post-mortem

### Incident 4: Traffic Spike Scaling (Requirement 28)

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                         TRAFFIC SPIKE SCALING RESPONSE                                   │
└─────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│ Ingress  │     │ HPA      │     │ Cluster  │     │ Prometheus│    │ Grafana  │
│          │     │          │     │ Autoscaler│    │           │     │          │
└────┬─────┘     └────┬─────┘     └─────┬─────┘    └─────┬─────┘     └────┬─────┘
     │                │                 │                │                │
     │ Traffic spike  │                 │                │                │
     │ detected       │                 │                │                │
     ├───────────────►│                 │                │                │
     │                │                 │                │                │
     │                │ T+30s: CPU >70% │                │                │
     │                │ Scale 2→10 pods │                │                │
     │                ├────────────────►│                │                │
     │                │                 │                │                │
     │                │                 │ Pending pods   │                │
     │                │                 │ detected       │                │
     │                │                 ├───────────────►│                │
     │                │                 │                │                │
     │                │                 │ T+1min: Scale  │                │
     │                │                 │ node pool      │                │
     │                │                 │ 5→10 nodes     │                │
     │                │                 ├───────────────►│                │
     │                │                 │                │                │
     │                │                 │                │                │ Display
     │                │                 │                │                │ scaling
     │                │                 │                │                │ events
     │                │                 │                ├───────────────►│
     │                │                 │                │                │
     │                │ T+3min: Nodes   │                │                │
     │                │ ready, pods     │                │                │
     │                │ scheduled       │                │                │
     │                ├────────────────►│                │                │
     │                │                 │                │                │
     │                │ Continue scaling│                │                │
     │                │ 10→50 pods      │                │                │
     │                ├────────────────►│                │                │
     │                │                 │                │                │
     │                │                 │ Scale nodes    │                │
     │                │                 │ 10→15 nodes    │                │
     │                │                 ├───────────────►│                │
     │                │                 │                │                │
     │ T+5min: All    │                 │                │                │
     │ pods running   │                 │                │                │
     │ traffic served │                 │                │                │
     │◄───────────────┤                 │                │                │
     │                │                 │                │                │
     │ Traffic        │                 │                │                │
     │ subsides       │                 │                │                │
     ├───────────────►│                 │                │                │
     │                │                 │                │                │
     │                │ T+15min: Scale  │                │                │
     │                │ down gradually  │                │                │
     │                │ (cool-down)     │                │                │
     │                ├────────────────►│                │                │
     │                │                 │                │                │
```

**Automated Response Mechanisms:**
1. HPA initiates pod scaling within 30 seconds of threshold breach
2. Cluster Autoscaler provisions nodes within 3 minutes
3. Buffer capacity pre-provisioned for initial surge
4. Alert if pending pods exist for >5 minutes
5. Gradual scale-down with configurable cool-down period

### Incident 5: Failed Deployment Rollback (Requirement 29)

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                       FAILED DEPLOYMENT ROLLBACK RESPONSE                                │
└─────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│ GitHub   │     │ Helm     │     │ Kubernetes│    │ Alert    │     │ Grafana  │
│ Actions  │     │          │     │ Probes    │    │ Manager  │     │          │
└────┬─────┘     └────┬─────┘     └─────┬─────┘    └─────┬─────┘     └────┬─────┘
     │                │                 │                │                │
     │ Deploy new     │                 │                │                │
     │ version        │                 │                │                │
     ├───────────────►│                 │                │                │
     │                │                 │                │                │
     │                │ Create new      │                │                │
     │                │ ReplicaSet      │                │                │
     │                ├────────────────►│                │                │
     │                │                 │                │                │
     │                │                 │ Readiness      │                │
     │                │                 │ probe fails    │                │
     │                │                 ├───────────────►│                │
     │                │                 │                │                │
     │                │                 │                │ T+2min: Alert  │
     │                │                 │                │ deployment     │
     │                │                 │                │ failing        │
     │                │                 │                ├───────────────►│
     │                │                 │                │                │
     │                │ T+5min: Health  │                │                │
     │                │ check timeout   │                │                │
     │                │ exceeded        │                │                │
     │                ├────────────────►│                │                │
     │                │                 │                │                │
     │                │ Automatic       │                │                │
     │                │ rollback        │                │                │
     │                │ initiated       │                │                │
     │                ├────────────────►│                │                │
     │                │                 │                │                │
     │                │                 │ Previous       │                │
     │                │                 │ ReplicaSet     │                │
     │                │                 │ scaled up      │                │
     │                │                 ├───────────────►│                │
     │                │                 │                │                │
     │ Mark deployment│                 │                │                │
     │ as failed      │                 │                │                │
     │◄───────────────┤                 │                │                │
     │                │                 │                │                │
     │ Notify team    │                 │                │                │
     ├───────────────►│                 │                │                │
     │                │                 │                │                │
     │                │                 │                │                │ Display
     │                │                 │                │                │ rollback
     │                │                 │                │                │ event
     │                │                 │                ├───────────────►│
     │                │                 │                │                │
     │ Retain failed  │                 │                │                │
     │ artifacts for  │                 │                │                │
     │ post-mortem    │                 │                │                │
     ├───────────────►│                 │                │                │
     │                │                 │                │                │
```

**Automated Response Mechanisms:**
1. Health check failure triggers automatic rollback within 5 minutes
2. GitHub Actions marks deployment as failed and notifies team
3. Failed deployment artifacts retained for post-mortem
4. Grafana displays deployment timeline with success/failure status
5. One-click manual rollback available if auto-rollback fails

---

## Runbook Templates

### Runbook: API Latency Spike

```markdown
# Runbook: API Latency Spike

## Alert Details
- **Alert Name**: LatencySLOBreach / SLOBurnRateCritical
- **Severity**: Sev1 / Sev0
- **Team**: Platform

## Symptoms
- API response times increased significantly (p99 > 500ms)
- Error budget burn rate elevated
- User-facing impact possible

## Diagnostic Steps

### 1. Check Distributed Traces
```bash
# Open Application Insights trace link from alert
# Look for slow spans in the trace waterfall
```

### 2. Identify Slow Component
```bash
# Check if latency is in:
# - Application code (CPU-bound)
# - Database queries
# - External API calls
# - Network latency
```

### 3. Check Recent Deployments
```bash
kubectl get deployments -n <namespace> -o wide
kubectl rollout history deployment/<name> -n <namespace>
```

### 4. Check Resource Utilization
```bash
kubectl top pods -n <namespace>
kubectl top nodes
```

### 5. Check Database Performance
```sql
-- Check slow queries
SELECT * FROM pg_stat_activity 
WHERE state = 'active' 
AND query_start < now() - interval '1 second';
```

## Remediation Steps

### If Recent Deployment
```bash
kubectl rollout undo deployment/<name> -n <namespace>
```

### If Database Issue
1. Check for missing indexes
2. Review query execution plans
3. Scale read replicas if needed

### If Resource Exhaustion
```bash
# Scale horizontally
kubectl scale deployment/<name> --replicas=<count> -n <namespace>
```

## Escalation
- If unresolved after 15 minutes, escalate to Sev0
- Contact database team if DB-related
- Contact application team if code-related

## Post-Incident
- Create incident report
- Update runbook with new findings
- Schedule post-mortem if Sev0/Sev1
```

### Runbook: Database Connection Exhaustion

```markdown
# Runbook: Database Connection Exhaustion

## Alert Details
- **Alert Name**: DatabaseConnectionPoolCritical
- **Severity**: Sev1
- **Team**: Platform

## Symptoms
- Connection pool utilization > 95%
- Application errors: "connection pool exhausted"
- Increased query wait times

## Diagnostic Steps

### 1. Check Connection Pool Status
```bash
kubectl exec -n data pgbouncer-0 -- pgbouncer -c "SHOW POOLS"
kubectl exec -n data pgbouncer-0 -- pgbouncer -c "SHOW CLIENTS"
```

### 2. Identify Connection Leaks
```sql
-- Check connections by application
SELECT application_name, count(*) 
FROM pg_stat_activity 
GROUP BY application_name;

-- Check long-running queries
SELECT pid, now() - query_start as duration, query 
FROM pg_stat_activity 
WHERE state = 'active' 
ORDER BY duration DESC;
```

### 3. Check for Idle Connections
```sql
SELECT count(*) FROM pg_stat_activity WHERE state = 'idle';
```

## Remediation Steps

### Immediate: Scale PgBouncer
```bash
kubectl scale deployment/pgbouncer --replicas=4 -n data
```

### Kill Long-Running Queries
```sql
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE state = 'active' 
AND query_start < now() - interval '5 minutes';
```

### Increase Pool Size (if needed)
```bash
# Update PgBouncer config
kubectl edit configmap pgbouncer-config -n data
# Restart PgBouncer
kubectl rollout restart deployment/pgbouncer -n data
```

## Prevention
- Review application connection handling
- Implement connection timeouts
- Add connection pool monitoring to dashboards

## Escalation
- Contact DBA team if queries cannot be killed
- Contact application team for connection leak investigation
```

---

## Error Handling

### Infrastructure Error Handling

| Error Type | Detection | Response | Recovery |
|------------|-----------|----------|----------|
| Terraform State Lock | Backend returns 409 | Wait and retry with exponential backoff | Manual unlock if stuck |
| Azure API Rate Limit | HTTP 429 | Automatic retry with backoff | Reduce parallelism |
| Resource Quota Exceeded | Deployment fails | Alert platform team | Request quota increase |
| Private Endpoint DNS Failure | Health check fails | Failover to secondary | Recreate PE |
| Node Pool Scale Failure | Pending pods timeout | Alert, try alternative VM sizes | Manual intervention |

### Application Error Handling

| Error Type | Detection | Response | Recovery |
|------------|-----------|----------|----------|
| Pod OOMKilled | Container restart | Alert, check memory limits | Increase limits or optimize |
| Liveness Probe Failure | Pod restart | Log event, alert if repeated | Check application health |
| Readiness Probe Failure | Traffic removed | Log event, investigate | Fix application issue |
| Image Pull Failure | Pod pending | Alert, check ACR connectivity | Verify image exists, check PE |
| Secret Mount Failure | Pod fails to start | Alert, check Key Vault access | Verify workload identity |

### Network Error Handling

| Error Type | Detection | Response | Recovery |
|------------|-----------|----------|----------|
| Firewall Rule Block | Connection timeout | Log to analytics, alert | Add required FQDN rule |
| NSG Deny | Connection refused | Log flow, alert | Update NSG rules |
| DNS Resolution Failure | Name not resolved | Check Private DNS zone | Verify zone link |
| VNet Peering Down | Cross-VNet timeout | Alert, check peering status | Recreate peering |

### Database Error Handling

| Error Type | Detection | Response | Recovery |
|------------|-----------|----------|----------|
| Connection Timeout | Query fails | Retry with backoff | Check network, scale pool |
| Deadlock | Transaction aborted | Automatic retry | Review query patterns |
| Replication Lag | Metrics threshold | Alert, reduce read load | Wait for catch-up |
| Failover Event | Connection reset | Automatic reconnect | PgBouncer handles |

### Circuit Breaker Configuration

```yaml
# Istio DestinationRule for circuit breaking
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: circuit-breaker
  namespace: app-team-a-prod
spec:
  host: backend-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        h2UpgradePolicy: UPGRADE
        http1MaxPendingRequests: 100
        http2MaxRequests: 1000
        maxRequestsPerConnection: 10
        maxRetries: 3
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
      minHealthPercent: 30
```

---

## Testing Strategy

### Overview

This feature is primarily Infrastructure as Code (Terraform, Kubernetes YAML, Helm charts, GitHub Actions pipelines). Property-based testing is **not appropriate** for this type of feature because:

1. **IaC is declarative configuration**, not functions with inputs/outputs
2. **Behavior doesn't vary meaningfully** with random inputs
3. **Testing infrastructure requires real or mocked cloud environments**

Instead, we use the following testing approaches:

### 1. Terraform Testing

#### Static Analysis
- **Checkov**: Security and compliance scanning
- **tfsec**: Terraform-specific security scanner
- **terraform validate**: Syntax and configuration validation
- **terraform fmt**: Code formatting verification

#### Unit Testing with Terratest
```go
// test/terraform_test.go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestAKSModule(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/aks",
        Vars: map[string]interface{}{
            "cluster_name":            "test-aks",
            "location":                "eastus",
            "resource_group_name":     "test-rg",
            "private_cluster_enabled": true,
        },
    })

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndPlan(t, terraformOptions)
    
    // Validate plan output
    plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Assert private cluster is enabled
    aksResource := plan.ResourcePlannedValuesMap["azurerm_kubernetes_cluster.main"]
    assert.Equal(t, true, aksResource.AttributeValues["private_cluster_enabled"])
}
```

#### Integration Testing
```go
func TestFullDeployment(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../environments/test",
        VarFiles:     []string{"terraform.tfvars"},
    })

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    // Validate outputs
    aksClusterName := terraform.Output(t, terraformOptions, "aks_cluster_name")
    assert.NotEmpty(t, aksClusterName)

    // Validate cluster is accessible
    kubeconfig := terraform.Output(t, terraformOptions, "kube_config")
    assert.NotEmpty(t, kubeconfig)
}
```

### 2. Kubernetes Manifest Testing

#### Schema Validation with kubeconform
```bash
# Validate all manifests against Kubernetes schemas
kubeconform -strict -kubernetes-version 1.28.0 \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  charts/myapp/templates/*.yaml
```

#### Policy Testing with Conftest
```rego
# policy/deployment_test.rego
package main

deny[msg] {
    input.kind == "Deployment"
    not input.spec.template.spec.securityContext.runAsNonRoot
    msg := "Deployments must set runAsNonRoot: true"
}

deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.limits.memory
    msg := sprintf("Container %s must have memory limits", [container.name])
}
```

```bash
# Run policy tests
conftest test charts/myapp/templates/*.yaml -p policy/
```

#### Helm Chart Testing
```bash
# Lint chart
helm lint charts/myapp

# Template and validate
helm template myapp charts/myapp -f charts/myapp/values-prod.yaml | kubeconform -strict

# Run chart tests
helm test myapp -n app-team-a-prod
```

### 3. OPA Gatekeeper Policy Testing

```rego
# test/gatekeeper_test.rego
package k8srequirenonroot

test_deny_root_user {
    input := {
        "review": {
            "object": {
                "spec": {
                    "containers": [{
                        "name": "test",
                        "image": "nginx",
                        "securityContext": {
                            "runAsUser": 0
                        }
                    }]
                }
            }
        },
        "parameters": {
            "exemptImages": []
        }
    }
    count(violation) > 0
}

test_allow_nonroot_user {
    input := {
        "review": {
            "object": {
                "spec": {
                    "containers": [{
                        "name": "test",
                        "image": "nginx",
                        "securityContext": {
                            "runAsNonRoot": true,
                            "runAsUser": 1000
                        }
                    }]
                }
            }
        },
        "parameters": {
            "exemptImages": []
        }
    }
    count(violation) == 0
}
```

```bash
# Run OPA tests
opa test policies/ -v
```

### 4. GitHub Actions Pipeline Testing

#### act for Local Testing
```bash
# Test workflow locally
act -j validate -W .github/workflows/terraform.yml

# Test with specific event
act pull_request -W .github/workflows/terraform.yml
```

#### Workflow Syntax Validation
```bash
# Validate workflow syntax
actionlint .github/workflows/*.yml
```

### 5. Integration and E2E Testing

#### Smoke Tests
```bash
#!/bin/bash
# test/smoke_test.sh

# Test AKS connectivity
kubectl cluster-info

# Test DNS resolution
kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup kubernetes

# Test ACR pull
kubectl run acr-test --image=${ACR_NAME}.azurecr.io/myapp:latest --rm -it --restart=Never -- echo "ACR pull successful"

# Test Key Vault access
kubectl exec -n app-team-a-prod deploy/myapp -- cat /mnt/secrets-store/db-connection-string

# Test database connectivity
kubectl exec -n app-team-a-prod deploy/myapp -- pg_isready -h ${DB_HOST} -p 5432
```

#### Load Testing with k6
```javascript
// test/load_test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
    stages: [
        { duration: '2m', target: 10 },   // Ramp up
        { duration: '5m', target: 50 },   // Stay at 50
        { duration: '2m', target: 0 },    // Ramp down
    ],
    thresholds: {
        http_req_duration: ['p(99)<500'],  // 99% of requests under 500ms
        http_req_failed: ['rate<0.01'],    // Error rate under 1%
    },
};

export default function () {
    const res = http.get('https://api.contoso.com/health');
    check(res, {
        'status is 200': (r) => r.status === 200,
        'response time < 500ms': (r) => r.timings.duration < 500,
    });
    sleep(1);
}
```

### 6. Chaos Testing with Chaos Mesh

```yaml
# test/chaos/pod-failure.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-failure-test
  namespace: chaos-testing
spec:
  action: pod-failure
  mode: one
  selector:
    namespaces:
      - app-team-a-prod
    labelSelectors:
      app.kubernetes.io/name: myapp
  duration: "60s"
  scheduler:
    cron: "@every 1h"
```

### Test Coverage Matrix

| Requirement | Static Analysis | Unit Test | Integration Test | E2E Test |
|-------------|-----------------|-----------|------------------|----------|
| Req 1: Modular Terraform | ✅ Checkov, tfsec | ✅ Terratest | ✅ Full deploy | - |
| Req 2: Hub-Spoke Network | ✅ Checkov | ✅ Terratest | ✅ Connectivity | ✅ DNS resolution |
| Req 3: Private AKS | ✅ Checkov | ✅ Terratest | ✅ API access | ✅ kubectl |
| Req 4: Private Endpoints | ✅ Checkov | ✅ Terratest | ✅ PE creation | ✅ Service access |
| Req 5: Network Security | ✅ Checkov | ✅ Terratest | ✅ NSG rules | ✅ Traffic flow |
| Req 6: Azure AD RBAC | ✅ Checkov | ✅ Terratest | ✅ Role assignment | ✅ Auth flow |
| Req 7: Workload Identity | ✅ Checkov | ✅ Terratest | ✅ Identity creation | ✅ Secret access |
| Req 8: Multi-Pool AKS | ✅ Checkov | ✅ Terratest | ✅ Pool creation | ✅ Scheduling |
| Req 9: Autoscaling | - | ✅ HPA config | ✅ Scale trigger | ✅ Load test |
| Req 10: PDB/Resources | ✅ Conftest | ✅ Helm test | ✅ Deploy | ✅ Drain test |
| Req 11: Terraform CI/CD | ✅ actionlint | ✅ act | ✅ PR workflow | ✅ Full deploy |
| Req 12: App CI/CD | ✅ actionlint | ✅ act | ✅ Build/push | ✅ Deploy |
| Req 13: Container Security | ✅ Trivy | ✅ SBOM gen | ✅ Scan | ✅ Policy block |
| Req 14: OPA Gatekeeper | ✅ OPA test | ✅ Policy test | ✅ Constraint | ✅ Admission |
| Req 15: Blue-Green/Canary | - | ✅ Helm test | ✅ Traffic split | ✅ Rollback |
| Req 16: Prometheus/Grafana | ✅ kubeconform | ✅ Config test | ✅ Scrape | ✅ Dashboard |
| Req 17: Logging | ✅ kubeconform | - | ✅ Log flow | ✅ Query |
| Req 18: Tracing | ✅ kubeconform | - | ✅ Trace export | ✅ Correlation |
| Req 19: SLO Alerting | ✅ promtool | ✅ Rule test | ✅ Alert fire | ✅ Notification |
| Req 20: Cost Optimization | ✅ Checkov | ✅ Terratest | ✅ Budget | ✅ Spot usage |
| Req 21: PostgreSQL HA | ✅ Checkov | ✅ Terratest | ✅ Failover | ✅ Connection |
| Req 22: Resilience | ✅ kubeconform | ✅ Config test | ✅ Circuit breaker | ✅ Chaos test |
| Req 23: DR | ✅ Checkov | ✅ Terratest | ✅ Backup | ✅ Recovery |
| Req 24: Azure Policy | ✅ Checkov | ✅ Terratest | ✅ Assignment | ✅ Compliance |
| Req 25-31: Incidents | - | ✅ Alert rules | ✅ Alert fire | ✅ Response |
| Req 32: Runbooks | - | - | ✅ Link valid | ✅ Procedure |

---

## Requirements Traceability Matrix

| Requirement | Design Section | Implementation Files | Test Coverage |
|-------------|----------------|---------------------|---------------|
| Req 1: Modular Terraform | Terraform Folder Structure | `terraform/modules/*`, `terraform/environments/*` | Terratest, Checkov |
| Req 2: Hub-Spoke Network | Architecture, Network Module | `modules/network/hub/*`, `modules/network/spoke/*` | Terratest, Connectivity |
| Req 3: Private AKS | Architecture, AKS Module | `modules/aks/main.tf` | Terratest, kubectl |
| Req 4: Private Endpoints | Architecture, Security Module | `modules/security/private_endpoints.tf` | Terratest, Service access |
| Req 5: Network Security | Architecture, Network Module | `modules/network/hub/main.tf` (Firewall) | Checkov, Traffic flow |
| Req 6: Azure AD RBAC | AKS Module | `modules/aks/rbac.tf` | Terratest, Auth flow |
| Req 7: Workload Identity | Security Module, Helm Values | `modules/security/managed_identities.tf`, `values-prod.yaml` | Terratest, Secret access |
| Req 8: Multi-Pool AKS | AKS Module | `modules/aks/node_pools.tf` | Terratest, Scheduling |
| Req 9: Autoscaling | Helm Templates | `templates/hpa.yaml`, `modules/aks/main.tf` | Load test |
| Req 10: PDB/Resources | Helm Templates | `templates/pdb.yaml`, `templates/deployment.yaml` | Conftest, Drain test |
| Req 11: Terraform CI/CD | GitHub Actions | `.github/workflows/terraform.yml` | actionlint, act |
| Req 12: App CI/CD | GitHub Actions | `.github/workflows/app-deploy.yml` | actionlint, act |
| Req 13: Container Security | GitHub Actions, OPA | `.github/workflows/app-deploy.yml`, `constraints/*` | Trivy, Policy test |
| Req 14: OPA Gatekeeper | OPA Policies | `templates/*.yaml`, `constraints/*.yaml` | OPA test, Admission |
| Req 15: Blue-Green/Canary | GitHub Actions, Helm | `.github/workflows/app-deploy.yml` | Helm test, Rollback |
| Req 16: Prometheus/Grafana | Observability Config | `monitoring/servicemonitor-*.yaml`, Dashboard JSON | Config test, Dashboard |
| Req 17: Logging | Observability Module | `modules/observability/log_analytics.tf` | Log flow test |
| Req 18: Tracing | OpenTelemetry Config | `monitoring/otel-collector-config.yaml` | Trace export test |
| Req 19: SLO Alerting | Prometheus Rules | `monitoring/prometheus-rules.yaml` | promtool, Alert test |
| Req 20: Cost Optimization | Governance Module | `modules/governance/budgets.tf` | Budget test |
| Req 21: PostgreSQL HA | Data Module | `modules/data/postgresql.tf` | Failover test |
| Req 22: Resilience | Istio Config | Circuit breaker YAML | Chaos test |
| Req 23: DR | Architecture, Terraform | `modules/*` (geo-redundant) | Recovery test |
| Req 24: Azure Policy | Governance Module | `modules/governance/policies.tf` | Compliance test |
| Req 25: Latency Incident | Incident Response | Runbook, Alert rules | Alert fire test |
| Req 26: Connection Exhaustion | Incident Response | Runbook, Alert rules | Alert fire test |
| Req 27: Pod Crash Loops | Incident Response | Runbook, Alert rules | Alert fire test |
| Req 28: Traffic Spike | Incident Response | HPA, Cluster Autoscaler | Load test |
| Req 29: Failed Deployment | Incident Response | Helm rollback, Alert rules | Rollback test |
| Req 30: PE Connectivity | Incident Response | Runbook, Alert rules | Connectivity test |
| Req 31: Cost Spike | Incident Response | Runbook, Budget alerts | Budget test |
| Req 32: Runbooks | Runbook Templates | `runbooks/*.md` | Link validation |

---

## Appendix: Environment-Specific Configurations

### Development Environment (terraform.tfvars)

```hcl
# environments/dev/terraform.tfvars
environment    = "dev"
location       = "eastus"
owner_email    = "platform-team@contoso.com"
cost_center    = "CC-DEV-001"

# Network
hub_vnet_address_space   = ["10.100.0.0/16"]
spoke_vnet_address_space = ["10.101.0.0/16"]

# AKS
kubernetes_version = "1.28"
system_node_pool = {
  vm_size    = "Standard_D2s_v5"
  node_count = 1
  min_count  = 1
  max_count  = 3
}
user_node_pools = {
  user = {
    vm_size    = "Standard_D4s_v5"
    node_count = 1
    min_count  = 1
    max_count  = 5
  }
}

# AKS API Server Access - Authorized IP Ranges
# Enable public FQDN so authorized IPs can access the cluster
enable_public_fqdn_for_authorized_ips = true

# List of authorized IP ranges for API server access
# Add your laptop IP, office network, VPN exit points, CI/CD runners
# Use CIDR notation: /32 for single IP, /24 for subnet
api_server_authorized_ip_ranges = [
  # Developer IPs
  "2.221.35.167/32",             # Developer laptop
  
  # Add more IPs as needed:
  # "203.0.113.51/32",           # Another developer
  # "198.51.100.0/24",           # Office network
  # "192.0.2.0/24",              # VPN exit range
  
  # GitHub Actions runners (if using GitHub-hosted runners)
  # Note: GitHub-hosted runners have dynamic IPs, consider self-hosted runners
  # or use Azure DevOps with service connections instead
]

# Database
postgresql_sku_name   = "B_Standard_B1ms"
postgresql_ha_enabled = false

# Observability
log_retention_days = 30

# Budget
monthly_budget = 5000
```

### Production Environment (terraform.tfvars)

```hcl
# environments/prod/terraform.tfvars
environment    = "prod"
location       = "eastus"
owner_email    = "platform-team@contoso.com"
cost_center    = "CC-PROD-001"

# Network
hub_vnet_address_space   = ["10.0.0.0/16"]
spoke_vnet_address_space = ["10.1.0.0/16"]
enable_ddos_protection   = true

# AKS
kubernetes_version = "1.28"
system_node_pool = {
  vm_size    = "Standard_D4s_v5"
  node_count = 2
  min_count  = 2
  max_count  = 5
}
user_node_pools = {
  user = {
    vm_size    = "Standard_D8s_v5"
    node_count = 2
    min_count  = 2
    max_count  = 20
  }
  spot = {
    vm_size       = "Standard_D8s_v5"
    node_count    = 0
    min_count     = 0
    max_count     = 10
    priority      = "Spot"
    spot_max_price = -1
  }
}

# AKS API Server Access - Authorized IP Ranges (Production)
# More restrictive than dev - only essential access
enable_public_fqdn_for_authorized_ips = true

# Production authorized IPs - strictly controlled
api_server_authorized_ip_ranges = [
  # CI/CD Systems (required for deployments)
  # "CICD_RUNNER_IP/32",           # Self-hosted CI/CD runner
  
  # On-call/Emergency Access
  # "VPN_EXIT_IP/32",              # Corporate VPN exit point
  # "JUMP_BOX_IP/32",              # Bastion/Jump box public IP
  
  # Office Networks (if applicable)
  # "OFFICE_NETWORK/24",           # Main office
  
  # NOTE: For production, prefer VPN/Bastion access over direct IP allowlisting
  # Only add IPs here for CI/CD systems that cannot use VPN
]

# Database
postgresql_sku_name   = "GP_Standard_D4s_v3"
postgresql_ha_enabled = true
postgresql_backup_retention_days = 35

# Observability
log_retention_days = 90

# Budget
monthly_budget = 50000
budget_alert_emails = ["finops@contoso.com", "platform-team@contoso.com"]
```

### Variables Definition (modules/aks/variables.tf)

```hcl
# API Server Access Configuration
variable "enable_public_fqdn_for_authorized_ips" {
  description = "Enable public FQDN for the private cluster to allow authorized IP access"
  type        = bool
  default     = false
}

variable "api_server_authorized_ip_ranges" {
  description = <<-EOT
    List of authorized IP ranges (CIDR notation) that can access the Kubernetes API server.
    This enables developers and CI/CD systems to access the cluster from specific IPs.
    
    Examples:
    - "203.0.113.50/32"  - Single IP (your laptop)
    - "198.51.100.0/24"  - IP range (office network)
    - "10.0.0.0/8"       - Private range (VPN)
    
    To find your current IP: curl -s ifconfig.me
    
    SECURITY NOTE: 
    - Use /32 for individual IPs to minimize exposure
    - Regularly audit and remove stale IPs
    - Prefer VPN access for production environments
  EOT
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for ip in var.api_server_authorized_ip_ranges : can(cidrhost(ip, 0))
    ])
    error_message = "All entries must be valid CIDR notation (e.g., '192.168.1.1/32')."
  }
}

variable "api_server_subnet_id" {
  description = "Subnet ID for API server VNet integration (for private cluster)"
  type        = string
  default     = null
}
```

### Helper Script: Get Your Current IP

```bash
#!/bin/bash
# scripts/get-my-ip.sh
# Helper script to get your current public IP for AKS authorized IP ranges

echo "Your current public IP address:"
MY_IP=$(curl -s ifconfig.me)
echo "$MY_IP"
echo ""
echo "Add this to your terraform.tfvars:"
echo "api_server_authorized_ip_ranges = ["
echo "  \"$MY_IP/32\",  # $(whoami)@$(hostname) - $(date +%Y-%m-%d)"
echo "]"
```

---

*Document Version: 1.0*
*Last Updated: 2024*
*Author: Platform Team*
