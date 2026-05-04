# Enterprise AKS Platform Architecture

This document provides a comprehensive overview of the Enterprise AKS Platform architecture, design decisions, and operational guidance.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Network Architecture](#network-architecture)
3. [Security Architecture](#security-architecture)
4. [Compute Architecture](#compute-architecture)
5. [Data Architecture](#data-architecture)
6. [Observability Architecture](#observability-architecture)
7. [CI/CD Architecture](#cicd-architecture)
8. [Architecture Decision Records](#architecture-decision-records)

---

## Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Azure Cloud                                     │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                         Hub Virtual Network                            │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐  │  │
│  │  │   Azure     │  │   Azure     │  │   Azure     │  │  Private     │  │  │
│  │  │  Firewall   │  │  Bastion    │  │  VPN GW     │  │  DNS Zones   │  │  │
│  │  │  (Egress)   │  │  (Access)   │  │  (Optional) │  │              │  │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └──────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                    │ VNet Peering                            │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                        Spoke Virtual Network                           │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │                    AKS Cluster (Private)                         │  │  │
│  │  │  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────────┐ │  │  │
│  │  │  │  System   │  │   User    │  │   Spot    │  │   Ingress     │ │  │  │
│  │  │  │  Pool     │  │   Pool    │  │   Pool    │  │   Controller  │ │  │  │
│  │  │  └───────────┘  └───────────┘  └───────────┘  └───────────────┘ │  │  │
│  │  └─────────────────────────────────────────────────────────────────┘  │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                    │  │
│  │  │  Private    │  │    ILB      │  │  App GW     │                    │  │
│  │  │  Endpoints  │  │   Subnet    │  │  Subnet     │                    │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                    │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │    ACR      │  │  Key Vault  │  │  PostgreSQL │  │  Log Analytics      │ │
│  │  (Private)  │  │  (Private)  │  │  (Private)  │  │  + App Insights     │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Design Principles

1. **Zero Trust Security**: All traffic is authenticated and authorized; no implicit trust
2. **Defense in Depth**: Multiple security layers (network, identity, policy)
3. **Infrastructure as Code**: All resources defined in Terraform
4. **GitOps**: Declarative configuration with version control
5. **Observability First**: Comprehensive monitoring, logging, and tracing
6. **Cost Optimization**: Right-sizing, autoscaling, and spot instances

### Environment Strategy

| Environment | Purpose | SLA | Cost Tier |
|-------------|---------|-----|-----------|
| **Dev** | Development and experimentation | None | Minimal |
| **Test** | Integration testing, QA | 99% | Standard |
| **Prod** | Production workloads | 99.9% | Premium |

---

## Network Architecture

### Hub-Spoke Topology

The platform uses a hub-spoke network topology for centralized security and connectivity.

#### Hub Network (10.0.0.0/16)

| Subnet | CIDR | Purpose |
|--------|------|---------|
| AzureFirewallSubnet | 10.0.1.0/26 | Azure Firewall deployment |
| AzureBastionSubnet | 10.0.2.0/26 | Azure Bastion for secure access |
| GatewaySubnet | 10.0.3.0/27 | VPN Gateway (optional) |

#### Spoke Network (10.1.0.0/16)

| Subnet | CIDR | Purpose |
|--------|------|---------|
| AKS | 10.1.0.0/22 | AKS nodes and pods (Azure CNI Overlay) |
| ILB | 10.1.4.0/24 | Internal Load Balancers |
| PrivateEndpoints | 10.1.5.0/24 | Private endpoints for PaaS services |
| AppGateway | 10.1.6.0/24 | Application Gateway (optional) |

### Network Security

```
Internet → Azure Firewall → AKS Ingress → Application Pods
                ↓
         Egress filtering (FQDN rules)
```

#### Egress Control
- All outbound traffic routes through Azure Firewall
- FQDN-based application rules for allowed destinations
- Network rules for required protocols (NTP, DNS)

#### Ingress Control
- NGINX Ingress Controller with internal load balancer
- TLS termination with cert-manager
- Network policies for pod-to-pod traffic

### Private DNS Zones

| Zone | Purpose |
|------|---------|
| privatelink.azurecr.io | Azure Container Registry |
| privatelink.vaultcore.azure.net | Azure Key Vault |
| privatelink.postgres.database.azure.com | PostgreSQL Flexible Server |
| privatelink.blob.core.windows.net | Azure Storage |
| privatelink.azmk8s.io | AKS API Server |

---

## Security Architecture

### Identity & Access Management

```
┌─────────────────────────────────────────────────────────────────┐
│                        Azure AD                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │   Users     │  │   Groups    │  │  Service Principals     │  │
│  │             │  │             │  │  (Workload Identity)    │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     AKS RBAC                                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ platform-admin  │  │    developer    │  │     reader      │  │
│  │ (Full access)   │  │ (Namespace)     │  │ (Read-only)     │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

#### Authentication
- Azure AD integration with managed identity
- Local accounts disabled
- OIDC issuer enabled for Workload Identity

#### Authorization
- Azure RBAC for cluster access
- Kubernetes RBAC for fine-grained permissions
- Namespace-scoped roles for development teams

### Secrets Management

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Application   │────▶│  Secrets Store  │────▶│   Key Vault     │
│      Pod        │     │   CSI Driver    │     │   (Premium)     │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                                               │
        │              Workload Identity                │
        └───────────────────────────────────────────────┘
```

- Secrets stored in Azure Key Vault (Premium SKU with HSM)
- Secrets Store CSI Driver mounts secrets as volumes
- Automatic secret rotation (2-minute interval)
- No secrets in ConfigMaps or environment variables

### Policy Enforcement

#### OPA Gatekeeper Policies

| Policy | Effect | Purpose |
|--------|--------|---------|
| K8sRequireNonRoot | Deny | Prevent root containers |
| K8sBlockPrivileged | Deny | Block privileged containers |
| K8sRequireResources | Deny | Enforce resource limits |
| K8sAllowedRegistries | Deny | Restrict image sources |
| K8sBlockHostPath | Deny | Prevent host path mounts |
| K8sRequireTLS | Audit | Ensure TLS on ingress |

#### Azure Policy
- Allowed VM sizes for node pools
- Mandatory tags on resources
- Private endpoints required for PaaS
- Encryption at rest and in transit

---

## Compute Architecture

### AKS Cluster Configuration

| Setting | Value | Rationale |
|---------|-------|-----------|
| SKU Tier | Standard (Prod) / Free (Dev) | SLA requirements |
| Kubernetes Version | 1.31 | Latest stable |
| Network Plugin | Azure CNI Overlay | IP efficiency |
| Network Policy | Azure | Native integration |
| Private Cluster | Yes | Security |
| Authorized IPs | CI/CD + Developer IPs | Controlled access |

### Node Pool Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                        AKS Cluster                               │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ System Pool (Standard_D4s_v5)                                ││
│  │ - 2-5 nodes, Zones 1,2,3                                     ││
│  │ - Critical addons only (CoreDNS, metrics-server, etc.)       ││
│  │ - Taint: CriticalAddonsOnly=true:NoSchedule                  ││
│  └─────────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ User Pool (Standard_D8s_v5)                                  ││
│  │ - 2-20 nodes, Zones 1,2,3                                    ││
│  │ - General application workloads                              ││
│  │ - Autoscaling enabled                                        ││
│  └─────────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Spot Pool (Standard_D8s_v5)                                  ││
│  │ - 0-10 nodes, Zones 1,2,3                                    ││
│  │ - Batch processing, non-critical workloads                   ││
│  │ - Taint: kubernetes.azure.com/scalesetpriority=spot:NoSchedule│
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### Autoscaling Strategy

| Component | Type | Configuration |
|-----------|------|---------------|
| Cluster Autoscaler | Node-level | Scale nodes based on pending pods |
| HPA | Pod-level | Scale pods based on CPU/memory |
| KEDA | Event-driven | Scale based on external metrics |

---

## Data Architecture

### Azure Container Registry

- **SKU**: Premium (geo-replication, private endpoint)
- **Security**: Vulnerability scanning, content trust
- **Access**: AcrPull role for kubelet identity

### Azure PostgreSQL Flexible Server

- **SKU**: GP_Standard_D4s_v3
- **HA**: Zone-redundant (Production)
- **Backup**: 35-day retention, geo-redundant
- **Connection Pooling**: PgBouncer enabled
- **Authentication**: Azure AD + password

### Azure Storage

- **Replication**: GRS (geo-redundant)
- **Features**: Versioning, soft delete
- **Access**: Private endpoint only
- **Lifecycle**: Auto-tier to cool storage

---

## Observability Architecture

### Monitoring Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                     Observability Stack                          │
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ Prometheus  │  │   Grafana   │  │   Azure Monitor         │  │
│  │ (Metrics)   │──│ (Dashboards)│  │   (Container Insights)  │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
│         │                                      │                 │
│         ▼                                      ▼                 │
│  ┌─────────────┐                    ┌─────────────────────────┐  │
│  │ AlertManager│                    │   Log Analytics         │  │
│  │ (Alerting)  │                    │   (90-day retention)    │  │
│  └─────────────┘                    └─────────────────────────┘  │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              OpenTelemetry Collector                         ││
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────────────┐ ││
│  │  │  OTLP   │  │ Jaeger  │  │Prometheus│  │ Azure Monitor   │ ││
│  │  │Receiver │  │Receiver │  │ Receiver │  │   Exporter      │ ││
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────────────┘ ││
│  └─────────────────────────────────────────────────────────────┘│
│                              │                                   │
│                              ▼                                   │
│                    ┌─────────────────────────┐                   │
│                    │   Application Insights  │                   │
│                    │   (Distributed Tracing) │                   │
│                    └─────────────────────────┘                   │
└─────────────────────────────────────────────────────────────────┘
```

### Metrics Collection

| Source | Collector | Storage |
|--------|-----------|---------|
| Application metrics | Prometheus ServiceMonitor | Prometheus |
| Node metrics | Container Insights | Log Analytics |
| Custom metrics | OTEL Collector | Application Insights |

### Alerting Strategy

| Severity | Response Time | Channel | Examples |
|----------|---------------|---------|----------|
| Sev0 (Critical) | 5 min | PagerDuty | Service down, data loss |
| Sev1 (High) | 15 min | PagerDuty + Teams | Degraded performance |
| Sev2 (Medium) | 1 hour | Teams | Elevated error rates |
| Sev3 (Low) | 24 hours | Email | Warnings, capacity |

---

## CI/CD Architecture

### Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Actions                                │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                 Terraform Pipeline                           ││
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────────────┐ ││
│  │  │Security │  │Validate │  │  Plan   │  │     Apply       │ ││
│  │  │  Scan   │─▶│  (All)  │─▶│  (PR)   │─▶│ (Dev→Test→Prod) │ ││
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────────────┘ ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                Application Pipeline                          ││
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────────────┐ ││
│  │  │  Build  │  │Security │  │ Deploy  │  │     Canary      │ ││
│  │  │ & Test  │─▶│  Scan   │─▶│  (Dev)  │─▶│    (Prod)       │ ││
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────────────┘ ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ OIDC Federation
                              ▼
                    ┌─────────────────────┐
                    │      Azure AD       │
                    │  (Workload Identity)│
                    └─────────────────────┘
```

### Deployment Strategy

| Environment | Strategy | Approval |
|-------------|----------|----------|
| Dev | Direct deploy | None |
| Test | Direct deploy | Auto (after dev) |
| Prod | Canary (10% → 100%) | Manual |

---

## Architecture Decision Records

### ADR-001: Private AKS Cluster with Authorized IPs

**Status**: Accepted

**Context**: Need to balance security (private cluster) with developer/CI-CD access.

**Decision**: Use private cluster with public FQDN enabled and authorized IP ranges.

**Consequences**:
- ✅ API server not exposed to internet
- ✅ Developers can access via authorized IPs
- ✅ CI/CD can access via GitHub-hosted runner IPs
- ⚠️ Requires IP allowlist management

### ADR-002: Azure CNI Overlay Network Plugin

**Status**: Accepted

**Context**: Need efficient IP address management for large clusters.

**Decision**: Use Azure CNI with Overlay mode instead of traditional Azure CNI.

**Consequences**:
- ✅ Pods get IPs from overlay network, not VNet
- ✅ Supports larger clusters without IP exhaustion
- ✅ Maintains Azure CNI features (network policy, etc.)
- ⚠️ Slightly higher latency than traditional CNI

### ADR-003: Hub-Spoke Network Topology

**Status**: Accepted

**Context**: Need centralized security controls and potential multi-cluster support.

**Decision**: Implement hub-spoke topology with Azure Firewall in hub.

**Consequences**:
- ✅ Centralized egress control
- ✅ Shared security services
- ✅ Supports future spoke networks
- ⚠️ Additional complexity and cost

### ADR-004: Workload Identity for Pod Authentication

**Status**: Accepted

**Context**: Need secure, credential-free authentication from pods to Azure services.

**Decision**: Use Azure AD Workload Identity instead of pod-managed identity.

**Consequences**:
- ✅ No credentials stored in cluster
- ✅ Fine-grained identity per workload
- ✅ Supports federated identity scenarios
- ⚠️ Requires service account annotation

### ADR-005: OPA Gatekeeper for Policy Enforcement

**Status**: Accepted

**Context**: Need to enforce security policies at admission time.

**Decision**: Use OPA Gatekeeper with custom constraint templates.

**Consequences**:
- ✅ Prevents policy violations before deployment
- ✅ Customizable policies via Rego
- ✅ Audit mode for gradual rollout
- ⚠️ Learning curve for Rego language

### ADR-006: KEDA for Event-Driven Autoscaling

**Status**: Accepted

**Context**: Need to scale workloads based on external metrics (queues, events).

**Decision**: Deploy KEDA alongside HPA for event-driven scaling.

**Consequences**:
- ✅ Scale-to-zero capability
- ✅ Native Azure service integration
- ✅ Complements HPA for different use cases
- ⚠️ Additional component to manage

---

## Onboarding Guide

### For Developers

1. **Get Access**
   - Request Azure AD group membership from platform team
   - Add your IP to authorized IP ranges (see below)

2. **Configure kubectl**
   ```bash
   az login
   az aks get-credentials -g <rg> -n <cluster>
   kubelogin convert-kubeconfig -l azurecli
   ```

3. **Deploy Applications**
   - Use provided Helm chart template
   - Follow deployment checklist
   - Request namespace access if needed

### For Administrators

1. **Access Requirements**
   - Azure AD Global Admin or Privileged Role Admin
   - platform-admin group membership

2. **Key Operations**
   - Terraform changes via PR workflow
   - Emergency access via Azure Bastion
   - Monitoring via Grafana dashboards

### Requesting Authorized IP Access

1. Submit request to platform team with:
   - Your static IP address or CIDR range
   - Business justification
   - Expected duration

2. Platform team will:
   - Review and approve request
   - Add IP to `api_server_authorized_ip_ranges` in Terraform
   - Apply change via CI/CD pipeline

3. Access will be reviewed quarterly and removed if no longer needed.

---

## Related Documentation

- [Autoscaling Guide](./AUTOSCALING.md)
- [Incident Response Runbooks](./runbooks/INCIDENT_RESPONSE.md)
- [Troubleshooting Guide](./runbooks/TROUBLESHOOTING.md)
- [Deployment Checklist](./runbooks/DEPLOYMENT_CHECKLIST.md)
- [GitHub Setup Guide](./GITHUB_SETUP.md)
