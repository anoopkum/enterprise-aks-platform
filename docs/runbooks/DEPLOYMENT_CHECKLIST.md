# Deployment Checklists

This document provides comprehensive checklists for infrastructure and application deployments to the Enterprise AKS Platform.

## Table of Contents

1. [Infrastructure Deployment Checklist](#1-infrastructure-deployment-checklist)
2. [Application Deployment Checklist](#2-application-deployment-checklist)
3. [Post-Deployment Verification](#3-post-deployment-verification)
4. [Rollback Procedures](#4-rollback-procedures)

---

## 1. Infrastructure Deployment Checklist

Use this checklist when deploying Terraform infrastructure changes.

### Pre-Deployment

#### Planning & Review
- [ ] Change request approved and documented
- [ ] Impact assessment completed
- [ ] Rollback plan documented
- [ ] Maintenance window scheduled (if required)
- [ ] Stakeholders notified

#### Code Review
- [ ] Terraform code reviewed and approved
- [ ] Security scan passed (Checkov, tfsec)
- [ ] No hardcoded secrets or sensitive data
- [ ] Naming conventions followed
- [ ] Required tags included
- [ ] Documentation updated

#### Environment Preparation
- [ ] Target environment identified (dev/test/prod)
- [ ] Azure credentials configured (OIDC)
- [ ] Terraform state backend accessible
- [ ] Required permissions verified
- [ ] Resource quotas checked

### Deployment Steps

#### Terraform Validation
```bash
# Navigate to environment directory
cd terraform/environments/<env>

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format check
terraform fmt -check -recursive
```
- [ ] `terraform init` successful
- [ ] `terraform validate` passed
- [ ] `terraform fmt` check passed

#### Plan Review
```bash
# Generate plan
terraform plan -out=tfplan

# Review plan output
terraform show tfplan
```
- [ ] Plan reviewed for expected changes
- [ ] No unexpected resource deletions
- [ ] No security group rule removals
- [ ] No breaking changes to existing resources
- [ ] Cost impact assessed

#### Apply Changes
```bash
# Apply with plan file
terraform apply tfplan
```
- [ ] Apply completed successfully
- [ ] All resources created/updated as expected
- [ ] No errors in apply output

### Post-Deployment Verification

- [ ] Resources visible in Azure Portal
- [ ] AKS cluster accessible via kubectl
- [ ] Network connectivity verified
- [ ] DNS resolution working
- [ ] Monitoring data flowing
- [ ] Alerts configured and tested

---

## 2. Application Deployment Checklist

Use this checklist when deploying applications to AKS.

### Pre-Deployment

#### Code & Build
- [ ] Code changes reviewed and approved
- [ ] All tests passing (unit, integration)
- [ ] Security scan passed (Trivy, SAST)
- [ ] SBOM generated
- [ ] Container image built and pushed to ACR
- [ ] Image tag documented

#### Configuration
- [ ] Helm values reviewed for target environment
- [ ] Secrets stored in Key Vault
- [ ] ConfigMaps updated if needed
- [ ] Resource requests/limits appropriate
- [ ] Health check endpoints verified
- [ ] Environment variables configured

#### Dependencies
- [ ] Database migrations ready (if applicable)
- [ ] External service dependencies available
- [ ] Feature flags configured
- [ ] API versioning considered

### Deployment Steps

#### Pre-Flight Checks
```bash
# Check cluster connectivity
kubectl cluster-info

# Check namespace exists
kubectl get namespace <namespace>

# Check current deployment status
kubectl get deployment <deployment-name> -n <namespace>

# Check current replica count
kubectl get pods -n <namespace> -l app=<app-name>
```
- [ ] Cluster accessible
- [ ] Namespace exists
- [ ] Current deployment healthy

#### Database Migration (if applicable)
```bash
# Run migrations in a job
kubectl apply -f migration-job.yaml -n <namespace>

# Wait for completion
kubectl wait --for=condition=complete job/migration -n <namespace> --timeout=300s

# Check migration logs
kubectl logs job/migration -n <namespace>
```
- [ ] Migration job completed successfully
- [ ] Database schema updated
- [ ] Data integrity verified

#### Helm Deployment
```bash
# Dry run first
helm upgrade --install <release-name> ./charts/myapp \
  -n <namespace> \
  -f ./charts/myapp/values-<env>.yaml \
  --dry-run

# Deploy
helm upgrade --install <release-name> ./charts/myapp \
  -n <namespace> \
  -f ./charts/myapp/values-<env>.yaml \
  --wait \
  --timeout 10m
```
- [ ] Dry run successful
- [ ] Helm upgrade completed
- [ ] All pods running

#### Canary Deployment (Production)
```bash
# Deploy canary (10% traffic)
helm upgrade --install <release-name>-canary ./charts/myapp \
  -n <namespace> \
  -f ./charts/myapp/values-prod.yaml \
  --set replicaCount=1 \
  --set canary.enabled=true \
  --set canary.weight=10

# Monitor canary metrics for 15 minutes
# Check error rates, latency, success rates

# If successful, promote to full deployment
helm upgrade --install <release-name> ./charts/myapp \
  -n <namespace> \
  -f ./charts/myapp/values-prod.yaml

# Remove canary
helm uninstall <release-name>-canary -n <namespace>
```
- [ ] Canary deployed
- [ ] Canary metrics healthy for observation period
- [ ] Full deployment promoted
- [ ] Canary removed

### Post-Deployment Verification

#### Health Checks
```bash
# Check pod status
kubectl get pods -n <namespace> -l app=<app-name>

# Check pod logs
kubectl logs -n <namespace> -l app=<app-name> --tail=100

# Check readiness
kubectl get endpoints <service-name> -n <namespace>
```
- [ ] All pods in Running state
- [ ] No error logs
- [ ] Endpoints populated

#### Functional Verification
```bash
# Test health endpoint
kubectl exec -it <pod-name> -n <namespace> -- curl http://localhost:8080/health

# Test via ingress
curl -v https://<app-url>/health
```
- [ ] Health endpoint responding
- [ ] Application accessible via ingress
- [ ] Core functionality working

#### Monitoring Verification
- [ ] Metrics appearing in Prometheus
- [ ] Logs appearing in Log Analytics
- [ ] Traces appearing in Application Insights
- [ ] Dashboards showing data
- [ ] Alerts not firing

---

## 3. Post-Deployment Verification

### Infrastructure Verification

#### Network Connectivity
```bash
# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup <service>.<namespace>.svc.cluster.local

# Test private endpoint connectivity
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  nc -zv <private-endpoint-ip> <port>

# Test egress through firewall
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  curl -v https://mcr.microsoft.com
```

#### Security Verification
```bash
# Check Gatekeeper constraints
kubectl get constraints

# Check for policy violations
kubectl get constraints -o json | jq '.items[].status.totalViolations'

# Verify RBAC
kubectl auth can-i --list -n <namespace>
```

#### Scaling Verification
```bash
# Check HPA status
kubectl get hpa -n <namespace>

# Check cluster autoscaler
kubectl describe configmap cluster-autoscaler-status -n kube-system

# Verify PDB
kubectl get pdb -n <namespace>
```

### Application Verification

#### Performance Baseline
```bash
# Check response times
kubectl exec -it <pod-name> -n <namespace> -- \
  curl -w "@curl-format.txt" -o /dev/null -s http://localhost:8080/api/health

# Check resource usage
kubectl top pod -n <namespace> -l app=<app-name>
```

#### Integration Tests
```bash
# Run smoke tests
kubectl run -it --rm smoke-test --image=<test-image> --restart=Never -- \
  /run-smoke-tests.sh

# Verify external integrations
# - Database connectivity
# - Cache connectivity
# - Message queue connectivity
# - External API connectivity
```

### Verification Checklist Summary

| Category | Check | Status |
|----------|-------|--------|
| **Pods** | All pods Running | ☐ |
| **Pods** | No restarts in last 10 min | ☐ |
| **Services** | Endpoints populated | ☐ |
| **Ingress** | External access working | ☐ |
| **DNS** | Internal DNS resolving | ☐ |
| **DNS** | Private DNS resolving | ☐ |
| **Metrics** | Prometheus scraping | ☐ |
| **Logs** | Logs in Log Analytics | ☐ |
| **Traces** | Traces in App Insights | ☐ |
| **Alerts** | No critical alerts | ☐ |
| **HPA** | Metrics available | ☐ |
| **PDB** | Configured correctly | ☐ |

---

## 4. Rollback Procedures

### Application Rollback

#### Helm Rollback
```bash
# List release history
helm history <release-name> -n <namespace>

# Rollback to previous revision
helm rollback <release-name> -n <namespace>

# Rollback to specific revision
helm rollback <release-name> <revision> -n <namespace>

# Verify rollback
kubectl get pods -n <namespace> -l app=<app-name>
kubectl rollout status deployment/<deployment-name> -n <namespace>
```

#### Kubernetes Rollback
```bash
# View rollout history
kubectl rollout history deployment/<deployment-name> -n <namespace>

# Rollback to previous revision
kubectl rollout undo deployment/<deployment-name> -n <namespace>

# Rollback to specific revision
kubectl rollout undo deployment/<deployment-name> -n <namespace> --to-revision=<revision>

# Verify rollback
kubectl rollout status deployment/<deployment-name> -n <namespace>
```

### Infrastructure Rollback

#### Terraform Rollback
```bash
# Option 1: Revert code and apply
git revert <commit-hash>
terraform plan -out=rollback.tfplan
terraform apply rollback.tfplan

# Option 2: Use previous state (if available)
# Restore state from backup
az storage blob download \
  --account-name <storage-account> \
  --container-name tfstate \
  --name <env>/terraform.tfstate.backup \
  --file terraform.tfstate

terraform plan -out=rollback.tfplan
terraform apply rollback.tfplan
```

### Database Rollback

```bash
# Restore from point-in-time backup
az postgres flexible-server restore \
  --resource-group <rg> \
  --name <new-server-name> \
  --source-server <original-server> \
  --restore-time "2024-01-15T10:00:00Z"

# Update application connection string
kubectl create secret generic db-connection \
  --from-literal=connection-string="<new-connection-string>" \
  -n <namespace> \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart application to pick up new connection
kubectl rollout restart deployment/<deployment-name> -n <namespace>
```

### Rollback Decision Matrix

| Scenario | Action | Time to Recover |
|----------|--------|-----------------|
| Bad application code | Helm/kubectl rollback | < 5 minutes |
| Bad configuration | Update ConfigMap/Secret, restart | < 5 minutes |
| Database migration issue | Restore from backup | 15-60 minutes |
| Infrastructure change | Terraform revert | 10-30 minutes |
| Complete cluster failure | Restore from Velero backup | 1-4 hours |

---

## Quick Reference

### Common Commands

```bash
# Check deployment status
kubectl rollout status deployment/<name> -n <namespace>

# Watch pods
kubectl get pods -n <namespace> -w

# Get recent events
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -20

# Check logs
kubectl logs -f deployment/<name> -n <namespace>

# Describe resource
kubectl describe deployment/<name> -n <namespace>

# Helm status
helm status <release-name> -n <namespace>

# Helm history
helm history <release-name> -n <namespace>
```

### Emergency Contacts

| Role | Contact | Availability |
|------|---------|--------------|
| Platform Team | platform-team@company.com | 24/7 |
| Database Admin | dba-team@company.com | Business hours |
| Security Team | security@company.com | 24/7 for incidents |
| Azure Support | Azure Portal | 24/7 |

---

## Related Documentation

- [Incident Response Runbooks](./INCIDENT_RESPONSE.md)
- [Troubleshooting Guide](./TROUBLESHOOTING.md)
- [Architecture Overview](./ARCHITECTURE.md)
