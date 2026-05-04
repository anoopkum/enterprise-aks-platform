# Disaster Recovery Guide

This document covers disaster recovery (DR) procedures for the Enterprise AKS Platform, including backup strategies, recovery procedures, and multi-region failover.

## Table of Contents

1. [Recovery Objectives](#recovery-objectives)
2. [Backup Strategy](#backup-strategy)
3. [Velero Installation](#velero-installation)
4. [Backup Procedures](#backup-procedures)
5. [Recovery Procedures](#recovery-procedures)
6. [Multi-Region Failover](#multi-region-failover)
7. [DR Testing](#dr-testing)

---

## Recovery Objectives

### Recovery Time Objective (RTO)

| Component | RTO | Notes |
|-----------|-----|-------|
| AKS Cluster | 4 hours | Full cluster rebuild |
| Application Workloads | 1 hour | Restore from backup |
| Database | 1 hour | Point-in-time restore |
| Stateless Services | 15 minutes | Redeploy from CI/CD |

### Recovery Point Objective (RPO)

| Component | RPO | Notes |
|-----------|-----|-------|
| Cluster Configuration | 1 hour | Hourly Velero backups |
| Persistent Volumes | 1 hour | Hourly snapshots |
| Database | 5 minutes | Continuous replication |
| Application State | 0 | Stateless design |

---

## Backup Strategy

### What to Backup

| Component | Method | Frequency | Retention |
|-----------|--------|-----------|-----------|
| Kubernetes Resources | Velero | Hourly | 30 days |
| Persistent Volumes | Velero + Azure Snapshots | Hourly | 30 days |
| PostgreSQL Database | Azure Backup | Continuous | 35 days |
| Container Images | ACR Geo-replication | Real-time | N/A |
| Terraform State | Azure Storage GRS | On change | Versioned |
| Secrets | Key Vault Backup | Daily | 90 days |

### Backup Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Primary Region (uksouth)                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ AKS Cluster │  │  PostgreSQL │  │    Azure Storage        │  │
│  │             │  │  (Primary)  │  │    (Velero Backups)     │  │
│  └──────┬──────┘  └──────┬──────┘  └───────────┬─────────────┘  │
│         │                │                      │                │
│         │ Velero         │ Geo-replication      │ GRS            │
│         ▼                ▼                      ▼                │
└─────────────────────────────────────────────────────────────────┘
                           │
                           │ Cross-region replication
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Secondary Region (ukwest)                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ AKS Cluster │  │  PostgreSQL │  │    Azure Storage        │  │
│  │  (Standby)  │  │  (Replica)  │  │    (Backup Copy)        │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Velero Installation

### Prerequisites

```bash
# Create storage account for Velero backups
az storage account create \
  --name velerobackups${RANDOM} \
  --resource-group <rg> \
  --location uksouth \
  --sku Standard_GRS \
  --kind StorageV2

# Create blob container
az storage container create \
  --name velero \
  --account-name <storage-account>

# Create service principal for Velero
az ad sp create-for-rbac \
  --name velero-sp \
  --role Contributor \
  --scopes /subscriptions/<subscription-id>
```

### Install Velero

```bash
# Download Velero CLI
wget https://github.com/vmware-tanzu/velero/releases/download/v1.13.0/velero-v1.13.0-linux-amd64.tar.gz
tar -xvf velero-v1.13.0-linux-amd64.tar.gz
sudo mv velero-v1.13.0-linux-amd64/velero /usr/local/bin/

# Create credentials file
cat << EOF > credentials-velero
AZURE_SUBSCRIPTION_ID=<subscription-id>
AZURE_TENANT_ID=<tenant-id>
AZURE_CLIENT_ID=<client-id>
AZURE_CLIENT_SECRET=<client-secret>
AZURE_RESOURCE_GROUP=<rg>
AZURE_CLOUD_NAME=AzurePublicCloud
EOF

# Install Velero with Azure plugin
velero install \
  --provider azure \
  --plugins velero/velero-plugin-for-microsoft-azure:v1.9.0 \
  --bucket velero \
  --secret-file ./credentials-velero \
  --backup-location-config resourceGroup=<rg>,storageAccount=<storage-account>,subscriptionId=<subscription-id> \
  --snapshot-location-config apiTimeout=5m,resourceGroup=<rg>,subscriptionId=<subscription-id> \
  --use-node-agent \
  --default-volumes-to-fs-backup

# Verify installation
velero version
kubectl get pods -n velero
```

### Velero with Workload Identity (Recommended)

```yaml
# kubernetes/velero/velero-values.yaml
configuration:
  backupStorageLocation:
    - name: azure
      provider: azure
      bucket: velero
      config:
        resourceGroup: <rg>
        storageAccount: <storage-account>
        subscriptionId: <subscription-id>
        useAAD: "true"
  
  volumeSnapshotLocation:
    - name: azure
      provider: azure
      config:
        resourceGroup: <rg>
        subscriptionId: <subscription-id>

credentials:
  useSecret: false

serviceAccount:
  server:
    annotations:
      azure.workload.identity/client-id: <managed-identity-client-id>

podLabels:
  azure.workload.identity/use: "true"

deployNodeAgent: true
```

---

## Backup Procedures

### Scheduled Backups

```yaml
# kubernetes/velero/backup-schedule.yaml
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: hourly-cluster-backup
  namespace: velero
spec:
  schedule: "0 * * * *"  # Every hour
  template:
    # Include all namespaces except system
    includedNamespaces:
      - app-team-a-dev
      - app-team-a-test
      - app-team-a-prod
      - app-team-b-dev
      - app-team-b-test
      - app-team-b-prod
    
    # Include cluster-scoped resources
    includeClusterResources: true
    
    # Backup persistent volumes
    defaultVolumesToFsBackup: true
    
    # Snapshot persistent volumes
    snapshotVolumes: true
    
    # TTL for backup retention
    ttl: 720h  # 30 days
    
    # Labels for backup identification
    metadata:
      labels:
        backup-type: scheduled
        frequency: hourly

---
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-full-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"  # 2 AM daily
  template:
    includedNamespaces:
      - "*"
    excludedNamespaces:
      - kube-system
      - velero
    includeClusterResources: true
    defaultVolumesToFsBackup: true
    snapshotVolumes: true
    ttl: 2160h  # 90 days
    metadata:
      labels:
        backup-type: scheduled
        frequency: daily
```

### On-Demand Backup

```bash
# Backup specific namespace
velero backup create app-team-a-prod-backup \
  --include-namespaces app-team-a-prod \
  --snapshot-volumes \
  --default-volumes-to-fs-backup \
  --ttl 720h

# Backup with label selector
velero backup create critical-apps-backup \
  --selector "tier=critical" \
  --snapshot-volumes \
  --ttl 720h

# Backup before major change
velero backup create pre-upgrade-backup \
  --include-namespaces "*" \
  --exclude-namespaces kube-system,velero \
  --snapshot-volumes \
  --ttl 168h  # 7 days

# Check backup status
velero backup describe app-team-a-prod-backup
velero backup logs app-team-a-prod-backup
```

### Backup Verification

```bash
# List all backups
velero backup get

# Describe specific backup
velero backup describe <backup-name> --details

# Check backup logs for errors
velero backup logs <backup-name> | grep -i error

# Verify backup contents
velero backup describe <backup-name> --details | grep -A100 "Resource List"
```

---

## Recovery Procedures

### Full Cluster Recovery

```bash
# 1. Create new AKS cluster (if needed)
cd terraform/environments/prod
terraform apply

# 2. Install Velero on new cluster
velero install \
  --provider azure \
  --plugins velero/velero-plugin-for-microsoft-azure:v1.9.0 \
  --bucket velero \
  --secret-file ./credentials-velero \
  --backup-location-config resourceGroup=<rg>,storageAccount=<storage-account>,subscriptionId=<subscription-id> \
  --snapshot-location-config apiTimeout=5m,resourceGroup=<rg>,subscriptionId=<subscription-id> \
  --use-node-agent

# 3. Wait for Velero to sync backups
velero backup get

# 4. Restore from backup
velero restore create --from-backup <backup-name>

# 5. Monitor restore progress
velero restore describe <restore-name>
velero restore logs <restore-name>
```

### Namespace Recovery

```bash
# Restore specific namespace
velero restore create app-team-a-prod-restore \
  --from-backup <backup-name> \
  --include-namespaces app-team-a-prod

# Restore with resource filtering
velero restore create deployment-restore \
  --from-backup <backup-name> \
  --include-namespaces app-team-a-prod \
  --include-resources deployments,services,configmaps

# Restore to different namespace
velero restore create restore-to-test \
  --from-backup <backup-name> \
  --include-namespaces app-team-a-prod \
  --namespace-mappings app-team-a-prod:app-team-a-test
```

### Database Recovery

```bash
# Point-in-time restore for PostgreSQL
az postgres flexible-server restore \
  --resource-group <rg> \
  --name <new-server-name> \
  --source-server <original-server> \
  --restore-time "2024-01-15T10:00:00Z"

# Geo-restore from secondary region
az postgres flexible-server geo-restore \
  --resource-group <rg> \
  --name <new-server-name> \
  --source-server <original-server> \
  --location ukwest

# Update application connection strings
kubectl create secret generic db-connection \
  --from-literal=host=<new-server>.postgres.database.azure.com \
  --from-literal=database=mydb \
  -n app-team-a-prod \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart applications to pick up new connection
kubectl rollout restart deployment -n app-team-a-prod
```

### Recovery Validation

```bash
# Verify pods are running
kubectl get pods -n app-team-a-prod

# Check service endpoints
kubectl get endpoints -n app-team-a-prod

# Verify persistent volumes
kubectl get pvc -n app-team-a-prod

# Test application health
kubectl exec -it <pod-name> -n app-team-a-prod -- curl http://localhost:8080/health

# Run smoke tests
kubectl run smoke-test --image=<test-image> --restart=Never -n app-team-a-prod -- /run-tests.sh
```

---

## Multi-Region Failover

### Infrastructure Requirements

#### Secondary Region Setup

```hcl
# terraform/environments/dr/main.tf
module "network_hub_dr" {
  source = "../../modules/network/hub"
  
  location            = "ukwest"
  resource_group_name = "rg-enterprise-aks-dr"
  vnet_name           = "vnet-hub-dr"
  vnet_address_space  = ["10.2.0.0/16"]
  
  # ... other configuration
}

module "aks_dr" {
  source = "../../modules/aks"
  
  location            = "ukwest"
  resource_group_name = "rg-enterprise-aks-dr"
  cluster_name        = "aks-enterprise-dr"
  
  # Smaller footprint for standby
  system_node_pool = {
    min_count = 1
    max_count = 3
    # ... other configuration
  }
}
```

### Failover Procedure

#### Pre-Failover Checklist

- [ ] Confirm primary region is unavailable
- [ ] Notify stakeholders of failover initiation
- [ ] Verify secondary region infrastructure is healthy
- [ ] Confirm latest backup is available
- [ ] Document current state and timeline

#### Failover Steps

```bash
# 1. Scale up DR cluster
az aks nodepool scale \
  -g rg-enterprise-aks-dr \
  --cluster-name aks-enterprise-dr \
  -n user \
  -c 3

# 2. Restore workloads from backup
velero restore create dr-restore \
  --from-backup <latest-backup> \
  --include-namespaces app-team-a-prod,app-team-b-prod

# 3. Promote database replica
az postgres flexible-server replica promote \
  -g rg-enterprise-aks-dr \
  -n postgres-enterprise-dr

# 4. Update DNS to point to DR region
az network dns record-set a update \
  -g rg-dns \
  -z example.com \
  -n api \
  --set aRecords[0].ipv4Address=<dr-ingress-ip>

# 5. Verify application health
kubectl get pods --all-namespaces
curl -v https://api.example.com/health

# 6. Monitor for issues
kubectl logs -f -n app-team-a-prod -l app=api-gateway
```

#### Post-Failover Tasks

- [ ] Verify all services are operational
- [ ] Update monitoring dashboards
- [ ] Notify stakeholders of successful failover
- [ ] Document failover timeline and issues
- [ ] Plan failback procedure

### Failback Procedure

```bash
# 1. Verify primary region is recovered
az aks show -g rg-enterprise-aks -n aks-enterprise --query "provisioningState"

# 2. Sync data from DR to primary
# (Application-specific data sync procedures)

# 3. Restore latest state to primary
velero restore create failback-restore \
  --from-backup <dr-backup> \
  --include-namespaces app-team-a-prod,app-team-b-prod

# 4. Verify primary cluster health
kubectl get pods --all-namespaces

# 5. Update DNS to point back to primary
az network dns record-set a update \
  -g rg-dns \
  -z example.com \
  -n api \
  --set aRecords[0].ipv4Address=<primary-ingress-ip>

# 6. Scale down DR cluster
az aks nodepool scale \
  -g rg-enterprise-aks-dr \
  --cluster-name aks-enterprise-dr \
  -n user \
  -c 1
```

---

## DR Testing

### Quarterly DR Test Procedure

1. **Preparation** (1 week before)
   - Schedule maintenance window
   - Notify stakeholders
   - Review runbooks
   - Verify backup integrity

2. **Test Execution**
   - Simulate primary region failure
   - Execute failover procedure
   - Validate application functionality
   - Measure RTO/RPO

3. **Documentation**
   - Record actual RTO/RPO
   - Document issues encountered
   - Update runbooks as needed
   - Report to stakeholders

### DR Test Checklist

```markdown
## DR Test: [Date]

### Pre-Test
- [ ] Backup verified: [backup-name]
- [ ] DR infrastructure ready
- [ ] Stakeholders notified
- [ ] Monitoring in place

### Failover
- [ ] Start time: ___
- [ ] Workloads restored
- [ ] Database promoted
- [ ] DNS updated
- [ ] End time: ___
- [ ] Actual RTO: ___

### Validation
- [ ] All pods running
- [ ] Health checks passing
- [ ] Data integrity verified
- [ ] Actual RPO: ___

### Failback
- [ ] Primary region recovered
- [ ] Data synced
- [ ] DNS reverted
- [ ] DR cluster scaled down

### Post-Test
- [ ] Issues documented
- [ ] Runbooks updated
- [ ] Report submitted
```

---

## Related Documentation

- [Architecture Overview](./ARCHITECTURE.md)
- [Incident Response Runbooks](./runbooks/INCIDENT_RESPONSE.md)
- [Troubleshooting Guide](./runbooks/TROUBLESHOOTING.md)
- [Deployment Checklist](./runbooks/DEPLOYMENT_CHECKLIST.md)
