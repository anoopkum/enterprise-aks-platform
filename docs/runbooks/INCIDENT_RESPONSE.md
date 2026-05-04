# Incident Response Runbooks

This document contains runbooks for common incidents in the Enterprise AKS Platform. Each runbook provides step-by-step guidance for investigation and resolution.

## Table of Contents

1. [API Latency Spike](#1-api-latency-spike)
2. [Database Connection Exhaustion](#2-database-connection-exhaustion)
3. [Pod Crash Loop](#3-pod-crash-loop)
4. [Traffic Spike Scaling](#4-traffic-spike-scaling)
5. [Failed Deployment Rollback](#5-failed-deployment-rollback)
6. [Private Endpoint Connectivity Failure](#6-private-endpoint-connectivity-failure)
7. [Cost Spike from Autoscaling](#7-cost-spike-from-autoscaling)

---

## 1. API Latency Spike

### Symptoms
- P99 latency exceeds SLO threshold (>500ms)
- Increased error rates
- User complaints about slow responses
- Alert: `HighLatencyP99` firing

### Severity
- **Sev1** if affecting >10% of requests
- **Sev2** if affecting <10% of requests

### Investigation Steps

#### Step 1: Identify Affected Services
```bash
# Check which services have high latency
kubectl top pods -n <namespace> --sort-by=cpu

# Check Prometheus for latency metrics
# Query: histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))
```

#### Step 2: Check Resource Utilization
```bash
# Check node resource usage
kubectl top nodes

# Check pod resource usage
kubectl top pods -n <namespace>

# Check for resource throttling
kubectl describe pod <pod-name> -n <namespace> | grep -A5 "Limits"
```

#### Step 3: Check Dependencies
```bash
# Check database latency
# Query: avg(pg_stat_activity_max_tx_duration{datname="mydb"})

# Check external service latency
kubectl logs -n <namespace> <pod-name> | grep -i "timeout\|slow\|latency"
```

#### Step 4: Check for Recent Changes
```bash
# Check recent deployments
kubectl rollout history deployment/<deployment-name> -n <namespace>

# Check recent config changes
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -20
```

### Resolution Actions

#### If CPU/Memory Constrained:
```bash
# Scale up replicas
kubectl scale deployment/<deployment-name> -n <namespace> --replicas=<new-count>

# Or trigger HPA
kubectl patch hpa <hpa-name> -n <namespace> -p '{"spec":{"minReplicas":<new-min>}}'
```

#### If Database is Slow:
1. Check connection pool utilization
2. Review slow query logs
3. Consider scaling database tier

#### If External Dependency is Slow:
1. Enable circuit breaker if not already
2. Increase timeout values temporarily
3. Contact external service owner

### Post-Incident
- [ ] Update SLO if threshold was unrealistic
- [ ] Add missing monitoring/alerting
- [ ] Document root cause in incident report
- [ ] Schedule capacity planning review

---

## 2. Database Connection Exhaustion

### Symptoms
- Application errors: "too many connections"
- Database connection pool at 100%
- Alert: `DatabaseConnectionPoolExhausted` firing
- Increased application latency

### Severity
- **Sev1** - Service degradation affecting users

### Investigation Steps

#### Step 1: Check Connection Pool Status
```bash
# Check PgBouncer stats (if using)
kubectl exec -n <namespace> <pgbouncer-pod> -- pgbouncer -c "SHOW POOLS;"

# Check PostgreSQL connections
# Connect to database and run:
# SELECT count(*) FROM pg_stat_activity;
# SELECT * FROM pg_stat_activity WHERE state = 'active';
```

#### Step 2: Identify Connection Leaks
```bash
# Check application logs for connection errors
kubectl logs -n <namespace> -l app=<app-name> | grep -i "connection\|pool\|database"

# Check for long-running transactions
# SELECT pid, now() - pg_stat_activity.query_start AS duration, query
# FROM pg_stat_activity
# WHERE state != 'idle'
# ORDER BY duration DESC;
```

#### Step 3: Check Pod Count
```bash
# Each pod maintains its own connection pool
kubectl get pods -n <namespace> -l app=<app-name> | wc -l

# Calculate: pods * pool_size = total connections
```

### Resolution Actions

#### Immediate Mitigation:
```bash
# Kill idle connections (PostgreSQL)
# SELECT pg_terminate_backend(pid) FROM pg_stat_activity 
# WHERE state = 'idle' AND query_start < now() - interval '10 minutes';

# Restart affected pods to reset connection pools
kubectl rollout restart deployment/<deployment-name> -n <namespace>
```

#### If Too Many Pods:
```bash
# Reduce replica count
kubectl scale deployment/<deployment-name> -n <namespace> --replicas=<lower-count>

# Adjust HPA max replicas
kubectl patch hpa <hpa-name> -n <namespace> -p '{"spec":{"maxReplicas":<new-max>}}'
```

#### Long-term Fixes:
1. Reduce connection pool size per pod
2. Enable PgBouncer for connection pooling
3. Increase PostgreSQL max_connections (requires restart)
4. Review application for connection leaks

### Post-Incident
- [ ] Review connection pool configuration
- [ ] Add connection pool monitoring
- [ ] Document optimal pool size per pod
- [ ] Consider implementing PgBouncer if not using

---

## 3. Pod Crash Loop

### Symptoms
- Pod status: `CrashLoopBackOff`
- Alert: `PodCrashLooping` firing
- Service degradation or outage

### Severity
- **Sev1** if affecting production service
- **Sev2** if affecting non-critical service

### Investigation Steps

#### Step 1: Get Pod Status
```bash
# Check pod status
kubectl get pods -n <namespace> -l app=<app-name>

# Get detailed pod information
kubectl describe pod <pod-name> -n <namespace>

# Check restart count
kubectl get pods -n <namespace> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}'
```

#### Step 2: Check Logs
```bash
# Get current logs
kubectl logs <pod-name> -n <namespace>

# Get previous container logs (before crash)
kubectl logs <pod-name> -n <namespace> --previous

# Stream logs
kubectl logs -f <pod-name> -n <namespace>
```

#### Step 3: Check Events
```bash
# Get pod events
kubectl get events -n <namespace> --field-selector involvedObject.name=<pod-name>

# Check for OOMKilled
kubectl describe pod <pod-name> -n <namespace> | grep -A5 "Last State"
```

#### Step 4: Check Resource Limits
```bash
# Check if OOMKilled
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'

# Check resource usage before crash
kubectl top pod <pod-name> -n <namespace>
```

### Resolution Actions

#### If OOMKilled:
```bash
# Increase memory limits
kubectl patch deployment <deployment-name> -n <namespace> -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "<container-name>",
          "resources": {
            "limits": {"memory": "2Gi"},
            "requests": {"memory": "1Gi"}
          }
        }]
      }
    }
  }
}'
```

#### If Application Error:
```bash
# Rollback to previous version
kubectl rollout undo deployment/<deployment-name> -n <namespace>

# Or rollback to specific revision
kubectl rollout undo deployment/<deployment-name> -n <namespace> --to-revision=<revision>
```

#### If Configuration Error:
```bash
# Check ConfigMaps and Secrets
kubectl get configmap -n <namespace>
kubectl get secrets -n <namespace>

# Verify environment variables
kubectl exec <pod-name> -n <namespace> -- env | sort
```

#### If Liveness Probe Failing:
```bash
# Check probe configuration
kubectl get deployment <deployment-name> -n <namespace> -o yaml | grep -A10 livenessProbe

# Temporarily increase probe thresholds
kubectl patch deployment <deployment-name> -n <namespace> -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "<container-name>",
          "livenessProbe": {
            "failureThreshold": 10,
            "periodSeconds": 30
          }
        }]
      }
    }
  }
}'
```

### Post-Incident
- [ ] Review resource limits
- [ ] Add memory profiling
- [ ] Review probe configurations
- [ ] Update deployment checklist

---

## 4. Traffic Spike Scaling

### Symptoms
- Sudden increase in request rate
- HPA scaling to max replicas
- Cluster autoscaler adding nodes
- Potential latency increase during scale-up

### Severity
- **Sev2** if handling traffic successfully
- **Sev1** if service degradation occurs

### Investigation Steps

#### Step 1: Assess Current State
```bash
# Check HPA status
kubectl get hpa -n <namespace>

# Check current replica count
kubectl get deployment <deployment-name> -n <namespace>

# Check node count
kubectl get nodes | wc -l
```

#### Step 2: Check Scaling Progress
```bash
# Check HPA events
kubectl describe hpa <hpa-name> -n <namespace>

# Check cluster autoscaler status
kubectl describe configmap cluster-autoscaler-status -n kube-system

# Check pending pods
kubectl get pods --all-namespaces | grep Pending
```

#### Step 3: Identify Traffic Source
```bash
# Check ingress metrics
# Query: sum(rate(nginx_ingress_controller_requests[5m])) by (ingress)

# Check for potential DDoS
# Query: topk(10, sum(rate(nginx_ingress_controller_requests[1m])) by (remote_addr))
```

### Resolution Actions

#### If Legitimate Traffic:
```bash
# Manually scale if HPA is too slow
kubectl scale deployment/<deployment-name> -n <namespace> --replicas=<higher-count>

# Increase HPA max if needed
kubectl patch hpa <hpa-name> -n <namespace> -p '{"spec":{"maxReplicas":<new-max>}}'

# Pre-warm node pool
az aks nodepool scale -g <rg> --cluster-name <cluster> -n <nodepool> -c <count>
```

#### If Potential Attack:
```bash
# Enable rate limiting at ingress
kubectl annotate ingress <ingress-name> -n <namespace> \
  nginx.ingress.kubernetes.io/limit-rps="100" \
  nginx.ingress.kubernetes.io/limit-connections="50"

# Block suspicious IPs via Azure Firewall
# Add to firewall policy deny rules
```

#### If Scaling is Stuck:
```bash
# Check for resource quota limits
kubectl describe resourcequota -n <namespace>

# Check node pool max count
az aks nodepool show -g <rg> --cluster-name <cluster> -n <nodepool> --query maxCount
```

### Post-Incident
- [ ] Review HPA configuration
- [ ] Consider pre-scaling for known events
- [ ] Review rate limiting configuration
- [ ] Update capacity planning

---

## 5. Failed Deployment Rollback

### Symptoms
- New deployment failing health checks
- Increased error rates after deployment
- Alert: `DeploymentFailed` firing

### Severity
- **Sev1** if production affected
- **Sev2** if non-production

### Investigation Steps

#### Step 1: Assess Deployment Status
```bash
# Check deployment status
kubectl rollout status deployment/<deployment-name> -n <namespace>

# Check rollout history
kubectl rollout history deployment/<deployment-name> -n <namespace>

# Check new pods
kubectl get pods -n <namespace> -l app=<app-name> --sort-by='.metadata.creationTimestamp'
```

#### Step 2: Check New Pod Logs
```bash
# Get logs from new pods
kubectl logs -n <namespace> -l app=<app-name> --since=10m

# Check for startup errors
kubectl describe pod <new-pod-name> -n <namespace>
```

### Resolution Actions

#### Immediate Rollback:
```bash
# Rollback to previous revision
kubectl rollout undo deployment/<deployment-name> -n <namespace>

# Verify rollback
kubectl rollout status deployment/<deployment-name> -n <namespace>

# Confirm service is healthy
kubectl get pods -n <namespace> -l app=<app-name>
```

#### If Rollback Fails:
```bash
# Rollback to specific known-good revision
kubectl rollout history deployment/<deployment-name> -n <namespace>
kubectl rollout undo deployment/<deployment-name> -n <namespace> --to-revision=<revision>

# Or manually set image
kubectl set image deployment/<deployment-name> -n <namespace> \
  <container-name>=<known-good-image>
```

#### Helm Rollback:
```bash
# List Helm releases
helm history <release-name> -n <namespace>

# Rollback to previous release
helm rollback <release-name> <revision> -n <namespace>
```

### Post-Incident
- [ ] Review deployment pipeline
- [ ] Add/improve canary deployment
- [ ] Review health check configuration
- [ ] Update deployment checklist

---

## 6. Private Endpoint Connectivity Failure

### Symptoms
- Application cannot connect to Azure PaaS services
- DNS resolution failures for privatelink domains
- Alert: `PrivateEndpointUnhealthy` firing

### Severity
- **Sev1** if affecting production services

### Investigation Steps

#### Step 1: Check DNS Resolution
```bash
# Test DNS resolution from a pod
kubectl run -it --rm debug --image=busybox -n <namespace> -- nslookup <service>.privatelink.azurecr.io

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Verify Private DNS zone link
az network private-dns link vnet list -g <rg> -z <zone-name>
```

#### Step 2: Check Private Endpoint Status
```bash
# Check private endpoint status in Azure
az network private-endpoint show -g <rg> -n <pe-name> --query "provisioningState"

# Check private endpoint connection
az network private-endpoint show -g <rg> -n <pe-name> --query "privateLinkServiceConnections[0].privateLinkServiceConnectionState"
```

#### Step 3: Check Network Connectivity
```bash
# Test connectivity from a pod
kubectl run -it --rm debug --image=nicolaka/netshoot -n <namespace> -- \
  nc -zv <private-ip> <port>

# Check NSG rules
az network nsg rule list -g <rg> --nsg-name <nsg-name> -o table
```

### Resolution Actions

#### If DNS Issue:
```bash
# Verify DNS zone has correct A record
az network private-dns record-set a list -g <rg> -z <zone-name>

# Re-link DNS zone to VNet if needed
az network private-dns link vnet create -g <rg> -z <zone-name> \
  -n <link-name> -v <vnet-id> -e false
```

#### If Private Endpoint Issue:
```bash
# Recreate private endpoint (Terraform)
cd terraform/environments/<env>
terraform taint module.security.azurerm_private_endpoint.<pe-name>
terraform apply
```

#### If NSG Blocking:
```bash
# Add NSG rule to allow traffic
az network nsg rule create -g <rg> --nsg-name <nsg-name> \
  -n AllowPrivateEndpoint --priority 100 \
  --destination-address-prefixes <pe-subnet-cidr> \
  --destination-port-ranges '*' --access Allow
```

### Post-Incident
- [ ] Review Private DNS zone configuration
- [ ] Verify all VNet links are in place
- [ ] Add connectivity monitoring
- [ ] Document network topology

---

## 7. Cost Spike from Autoscaling

### Symptoms
- Azure Cost Management alert triggered
- Unexpected increase in node count
- Budget threshold exceeded
- Alert: `BudgetThresholdExceeded` firing

### Severity
- **Sev3** - Financial impact, not service affecting

### Investigation Steps

#### Step 1: Identify Cost Drivers
```bash
# Check current node count
kubectl get nodes -o wide

# Check node pool sizes
az aks nodepool list -g <rg> --cluster-name <cluster> -o table

# Check HPA status
kubectl get hpa --all-namespaces
```

#### Step 2: Review Scaling Events
```bash
# Check cluster autoscaler logs
kubectl logs -n kube-system -l app=cluster-autoscaler --since=24h | grep -i "scale"

# Check scaling events
kubectl get events --all-namespaces --field-selector reason=ScaledUp
kubectl get events --all-namespaces --field-selector reason=ScaledDown
```

#### Step 3: Identify Root Cause
```bash
# Check for resource-hungry workloads
kubectl top pods --all-namespaces --sort-by=cpu | head -20

# Check for pending pods that triggered scale-up
kubectl get events --all-namespaces | grep -i "insufficient"
```

### Resolution Actions

#### Immediate Cost Control:
```bash
# Scale down node pools
az aks nodepool scale -g <rg> --cluster-name <cluster> -n <nodepool> -c <lower-count>

# Reduce HPA max replicas
kubectl patch hpa <hpa-name> -n <namespace> -p '{"spec":{"maxReplicas":<lower-max>}}'

# Scale down non-critical workloads
kubectl scale deployment/<deployment-name> -n <namespace> --replicas=<lower-count>
```

#### If Legitimate Scaling:
1. Review and update budget
2. Consider Reserved Instances for baseline capacity
3. Optimize workload resource requests

#### If Runaway Scaling:
```bash
# Set node pool max count
az aks nodepool update -g <rg> --cluster-name <cluster> -n <nodepool> \
  --max-count <new-max>

# Review and fix HPA configuration
kubectl edit hpa <hpa-name> -n <namespace>
```

### Post-Incident
- [ ] Review autoscaling limits
- [ ] Update budget alerts
- [ ] Consider spot instances for batch workloads
- [ ] Schedule cost optimization review

---

## Escalation Contacts

| Role | Contact | When to Escalate |
|------|---------|------------------|
| Platform Team Lead | platform-lead@company.com | Sev1 incidents |
| Database Admin | dba-team@company.com | Database issues |
| Security Team | security@company.com | Security incidents |
| Azure Support | Azure Portal | Infrastructure issues |

## Related Documentation

- [Troubleshooting Guide](./TROUBLESHOOTING.md)
- [Deployment Checklist](./DEPLOYMENT_CHECKLIST.md)
- [Architecture Overview](./ARCHITECTURE.md)
