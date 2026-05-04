# Troubleshooting Guide

This guide provides systematic approaches to diagnosing and resolving common issues in the Enterprise AKS Platform.

## Table of Contents

1. [Networking Issues](#1-networking-issues)
2. [Scaling Issues](#2-scaling-issues)
3. [Deployment Issues](#3-deployment-issues)
4. [Authentication & Authorization Issues](#4-authentication--authorization-issues)
5. [Monitoring & Logging Issues](#5-monitoring--logging-issues)

---

## 1. Networking Issues

### 1.1 DNS Resolution Failures

#### Symptoms
- Pods cannot resolve internal or external DNS names
- `nslookup` or `dig` commands fail
- Application connection timeouts

#### Diagnosis
```bash
# Check CoreDNS pods are running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=100

# Test DNS from a debug pod
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Test external DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup google.com

# Test Private DNS zone resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup myacr.privatelink.azurecr.io
```

#### Common Causes & Solutions

**CoreDNS pods not running:**
```bash
# Check for resource issues
kubectl describe pods -n kube-system -l k8s-app=kube-dns

# Restart CoreDNS
kubectl rollout restart deployment/coredns -n kube-system
```

**Private DNS zone not linked:**
```bash
# Check DNS zone links
az network private-dns link vnet list -g <rg> -z privatelink.azurecr.io -o table

# Create missing link
az network private-dns link vnet create \
  -g <rg> \
  -z privatelink.azurecr.io \
  -n spoke-vnet-link \
  -v /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet> \
  -e false
```

**DNS policy blocking:**
```bash
# Check if pod has custom DNS config
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A10 dnsConfig

# Check network policy blocking DNS
kubectl get networkpolicy -n <namespace> -o yaml | grep -A20 "egress"
```

### 1.2 Network Security Group (NSG) Blocking Traffic

#### Symptoms
- Pods cannot reach external services
- Inter-pod communication failing
- Load balancer health probes failing

#### Diagnosis
```bash
# Check NSG rules
az network nsg rule list -g <rg> --nsg-name <nsg-name> -o table

# Check NSG flow logs (if enabled)
# Review in Azure Portal > NSG > Diagnostic settings > NSG flow logs

# Test connectivity from pod
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  curl -v http://<target-ip>:<port>

# Check for denied flows
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  tcpdump -i any host <target-ip>
```

#### Common Causes & Solutions

**Missing allow rule:**
```bash
# Add NSG rule via Azure CLI
az network nsg rule create \
  -g <rg> \
  --nsg-name <nsg-name> \
  -n AllowAppTraffic \
  --priority 200 \
  --source-address-prefixes <source-cidr> \
  --destination-address-prefixes <dest-cidr> \
  --destination-port-ranges 443 \
  --protocol Tcp \
  --access Allow
```

**Load balancer health probe blocked:**
```bash
# Ensure NSG allows Azure Load Balancer
az network nsg rule create \
  -g <rg> \
  --nsg-name <nsg-name> \
  -n AllowAzureLoadBalancer \
  --priority 100 \
  --source-address-prefixes AzureLoadBalancer \
  --destination-port-ranges '*' \
  --access Allow
```

### 1.3 Azure Firewall Blocking Traffic

#### Symptoms
- Pods cannot reach internet
- AKS cannot pull images from external registries
- Outbound connections timing out

#### Diagnosis
```bash
# Check firewall logs in Log Analytics
# Query:
# AzureDiagnostics
# | where Category == "AzureFirewallNetworkRule" or Category == "AzureFirewallApplicationRule"
# | where msg_s contains "Deny"
# | project TimeGenerated, msg_s
# | order by TimeGenerated desc

# Test outbound connectivity
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  curl -v https://mcr.microsoft.com
```

#### Common Causes & Solutions

**Missing application rule:**
```bash
# Add application rule to firewall policy
az network firewall policy rule-collection-group collection add-filter-collection \
  -g <rg> \
  --policy-name <policy-name> \
  --rcg-name DefaultApplicationRuleCollectionGroup \
  --name AllowAKS \
  --collection-priority 200 \
  --action Allow \
  --rule-type ApplicationRule \
  --rule-name AllowMCR \
  --source-addresses "10.1.0.0/22" \
  --protocols Https=443 \
  --target-fqdns "mcr.microsoft.com" "*.data.mcr.microsoft.com"
```

**Missing network rule:**
```bash
# Add network rule for NTP
az network firewall policy rule-collection-group collection add-filter-collection \
  -g <rg> \
  --policy-name <policy-name> \
  --rcg-name DefaultNetworkRuleCollectionGroup \
  --name AllowNTP \
  --collection-priority 200 \
  --action Allow \
  --rule-type NetworkRule \
  --rule-name AllowNTP \
  --source-addresses "10.1.0.0/22" \
  --destination-addresses "*" \
  --destination-ports 123 \
  --ip-protocols UDP
```

### 1.4 Network Policy Blocking Pod Communication

#### Symptoms
- Pods cannot communicate with each other
- Service discovery working but connections fail
- Specific namespace-to-namespace traffic blocked

#### Diagnosis
```bash
# List network policies
kubectl get networkpolicy -n <namespace>

# Describe network policy
kubectl describe networkpolicy <policy-name> -n <namespace>

# Test pod-to-pod connectivity
kubectl exec -it <source-pod> -n <namespace> -- curl -v http://<target-service>:<port>
```

#### Common Causes & Solutions

**Ingress policy too restrictive:**
```yaml
# Allow traffic from specific namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-ingress
  namespace: app-team-a-prod
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
```

**Egress policy blocking:**
```yaml
# Allow egress to monitoring namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring-egress
  namespace: app-team-a-prod
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: monitoring
      ports:
        - protocol: TCP
          port: 9090
```

---

## 2. Scaling Issues

### 2.1 Horizontal Pod Autoscaler (HPA) Not Scaling

#### Symptoms
- HPA shows `<unknown>` for current metrics
- Pods not scaling despite high load
- HPA events show errors

#### Diagnosis
```bash
# Check HPA status
kubectl get hpa -n <namespace>

# Describe HPA for events
kubectl describe hpa <hpa-name> -n <namespace>

# Check metrics server
kubectl get pods -n kube-system | grep metrics-server
kubectl top pods -n <namespace>

# Check if resource requests are set
kubectl get deployment <deployment-name> -n <namespace> -o yaml | grep -A5 resources
```

#### Common Causes & Solutions

**Metrics server not running:**
```bash
# Check metrics server logs
kubectl logs -n kube-system -l k8s-app=metrics-server

# Restart metrics server
kubectl rollout restart deployment/metrics-server -n kube-system
```

**Missing resource requests:**
```yaml
# Add resource requests to deployment
spec:
  containers:
    - name: app
      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "500m"
          memory: "512Mi"
```

**Custom metrics not available:**
```bash
# Check Prometheus adapter (for custom metrics)
kubectl get pods -n monitoring | grep prometheus-adapter

# Check custom metrics API
kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1
```

### 2.2 Cluster Autoscaler Not Adding Nodes

#### Symptoms
- Pods stuck in Pending state
- Cluster autoscaler not scaling up
- Node pool at minimum count

#### Diagnosis
```bash
# Check pending pods
kubectl get pods --all-namespaces | grep Pending

# Check why pods are pending
kubectl describe pod <pending-pod> -n <namespace>

# Check cluster autoscaler status
kubectl describe configmap cluster-autoscaler-status -n kube-system

# Check cluster autoscaler logs
kubectl logs -n kube-system -l app=cluster-autoscaler --tail=100
```

#### Common Causes & Solutions

**Node pool at max count:**
```bash
# Check node pool limits
az aks nodepool show -g <rg> --cluster-name <cluster> -n <nodepool> \
  --query "{min:minCount,max:maxCount,current:count}"

# Increase max count
az aks nodepool update -g <rg> --cluster-name <cluster> -n <nodepool> \
  --max-count <new-max>
```

**Resource quota exceeded:**
```bash
# Check resource quota
kubectl describe resourcequota -n <namespace>

# Increase quota if needed
kubectl patch resourcequota <quota-name> -n <namespace> -p '
{
  "spec": {
    "hard": {
      "requests.cpu": "100",
      "requests.memory": "200Gi"
    }
  }
}'
```

**Pod affinity/anti-affinity preventing scheduling:**
```bash
# Check pod affinity rules
kubectl get pod <pending-pod> -n <namespace> -o yaml | grep -A20 affinity

# Consider relaxing anti-affinity for scaling
```

### 2.3 Cluster Autoscaler Not Removing Nodes

#### Symptoms
- Nodes underutilized but not scaling down
- Cost higher than expected
- Scale-down events not occurring

#### Diagnosis
```bash
# Check node utilization
kubectl top nodes

# Check cluster autoscaler logs for scale-down decisions
kubectl logs -n kube-system -l app=cluster-autoscaler | grep -i "scale-down"

# Check for pods preventing scale-down
kubectl get pods --all-namespaces -o wide | grep <node-name>
```

#### Common Causes & Solutions

**Pods with local storage:**
```bash
# Find pods with local storage
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.spec.volumes[]?.emptyDir != null) | .metadata.name'

# Consider using PVCs instead of emptyDir for important data
```

**Pods without PDB:**
```bash
# Check for missing PDBs
kubectl get pdb --all-namespaces

# Create PDB to allow safe eviction
kubectl apply -f - <<EOF
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
  namespace: <namespace>
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: <app-name>
EOF
```

**System pods preventing scale-down:**
```bash
# Check for kube-system pods on node
kubectl get pods -n kube-system -o wide | grep <node-name>

# DaemonSet pods are expected and don't block scale-down
```

---

## 3. Deployment Issues

### 3.1 Image Pull Failures

#### Symptoms
- Pod status: `ImagePullBackOff` or `ErrImagePull`
- Events show authentication or network errors

#### Diagnosis
```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace> | grep -A10 Events

# Check image name
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[0].image}'

# Test ACR connectivity
kubectl run -it --rm debug --image=mcr.microsoft.com/azure-cli --restart=Never -- \
  az acr repository list --name <acr-name>
```

#### Common Causes & Solutions

**ACR authentication failure:**
```bash
# Check AcrPull role assignment
az role assignment list --scope /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.ContainerRegistry/registries/<acr> \
  --query "[?roleDefinitionName=='AcrPull']"

# Assign AcrPull role to kubelet identity
az role assignment create \
  --assignee <kubelet-identity-object-id> \
  --role AcrPull \
  --scope /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.ContainerRegistry/registries/<acr>
```

**Private endpoint not working:**
```bash
# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup <acr-name>.azurecr.io

# Should resolve to private IP, not public
```

**Image doesn't exist:**
```bash
# List images in ACR
az acr repository show-tags --name <acr-name> --repository <repo-name>

# Check image digest
az acr repository show-manifests --name <acr-name> --repository <repo-name>
```

### 3.2 Resource Limit Issues

#### Symptoms
- Pods being OOMKilled
- Pods stuck in Pending due to insufficient resources
- CPU throttling causing slow performance

#### Diagnosis
```bash
# Check pod resource usage
kubectl top pod <pod-name> -n <namespace>

# Check for OOMKilled
kubectl describe pod <pod-name> -n <namespace> | grep -A5 "Last State"

# Check resource requests vs limits
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A10 resources

# Check node capacity
kubectl describe node <node-name> | grep -A10 "Allocated resources"
```

#### Common Causes & Solutions

**Memory limit too low:**
```bash
# Increase memory limit
kubectl patch deployment <deployment-name> -n <namespace> --type=json -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value": "2Gi"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value": "1Gi"}
]'
```

**CPU throttling:**
```bash
# Check CPU throttling metrics
# Query: container_cpu_cfs_throttled_seconds_total

# Increase CPU limit or remove limit (use requests only)
kubectl patch deployment <deployment-name> -n <namespace> --type=json -p='[
  {"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}
]'
```

### 3.3 Liveness/Readiness Probe Failures

#### Symptoms
- Pods being restarted frequently
- Pods not receiving traffic
- Events show probe failures

#### Diagnosis
```bash
# Check probe configuration
kubectl get deployment <deployment-name> -n <namespace> -o yaml | grep -A15 livenessProbe
kubectl get deployment <deployment-name> -n <namespace> -o yaml | grep -A15 readinessProbe

# Check pod events
kubectl describe pod <pod-name> -n <namespace> | grep -i probe

# Test probe endpoint manually
kubectl exec -it <pod-name> -n <namespace> -- curl -v http://localhost:<port>/health
```

#### Common Causes & Solutions

**Probe timeout too short:**
```yaml
# Increase probe timeouts
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

**Application slow to start:**
```yaml
# Add startup probe for slow-starting apps
startupProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 30  # 5 minutes to start
```

---

## 4. Authentication & Authorization Issues

### 4.1 Azure AD Authentication Failures

#### Symptoms
- `kubectl` commands fail with authentication errors
- "Unauthorized" errors in application logs
- Azure AD token issues

#### Diagnosis
```bash
# Check kubeconfig
kubectl config view

# Test authentication
kubectl auth whoami

# Check Azure AD integration
az aks show -g <rg> -n <cluster> --query "aadProfile"
```

#### Common Causes & Solutions

**Expired credentials:**
```bash
# Re-authenticate
az login
az aks get-credentials -g <rg> -n <cluster> --overwrite-existing

# For kubelogin
kubelogin convert-kubeconfig -l azurecli
```

**User not in admin group:**
```bash
# Check group membership
az ad group member list -g <admin-group-id> --query "[].userPrincipalName"

# Add user to group
az ad group member add -g <admin-group-id> --member-id <user-object-id>
```

### 4.2 RBAC Permission Denied

#### Symptoms
- "Forbidden" errors when accessing resources
- Users cannot perform expected actions
- Service accounts lacking permissions

#### Diagnosis
```bash
# Check user permissions
kubectl auth can-i <verb> <resource> -n <namespace>

# Check all permissions
kubectl auth can-i --list -n <namespace>

# Check role bindings
kubectl get rolebindings -n <namespace>
kubectl get clusterrolebindings | grep <user-or-group>
```

#### Common Causes & Solutions

**Missing RoleBinding:**
```bash
# Create RoleBinding for user
kubectl create rolebinding <name> \
  --clusterrole=<role> \
  --user=<user-email> \
  -n <namespace>

# Create RoleBinding for group
kubectl create rolebinding <name> \
  --clusterrole=<role> \
  --group=<azure-ad-group-id> \
  -n <namespace>
```

**Service account missing permissions:**
```bash
# Create ServiceAccount
kubectl create serviceaccount <sa-name> -n <namespace>

# Bind role to ServiceAccount
kubectl create rolebinding <name> \
  --clusterrole=<role> \
  --serviceaccount=<namespace>:<sa-name> \
  -n <namespace>
```

---

## 5. Monitoring & Logging Issues

### 5.1 Missing Metrics

#### Symptoms
- Grafana dashboards showing no data
- Prometheus targets down
- HPA showing unknown metrics

#### Diagnosis
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-server 9090:9090
# Visit http://localhost:9090/targets

# Check ServiceMonitor
kubectl get servicemonitor -n <namespace>
kubectl describe servicemonitor <name> -n <namespace>

# Check if metrics endpoint is accessible
kubectl exec -it <prometheus-pod> -n monitoring -- \
  curl http://<service>.<namespace>.svc.cluster.local:<port>/metrics
```

#### Common Causes & Solutions

**ServiceMonitor selector mismatch:**
```yaml
# Ensure labels match
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: app-monitor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: myapp  # Must match Service labels
  namespaceSelector:
    matchNames:
      - app-team-a-prod
```

**Network policy blocking Prometheus:**
```yaml
# Allow Prometheus to scrape
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-prometheus
  namespace: app-team-a-prod
spec:
  podSelector: {}
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: monitoring
      ports:
        - port: 8080
          protocol: TCP
```

### 5.2 Missing Logs

#### Symptoms
- Container Insights not showing logs
- Log Analytics queries return no results
- Application logs not appearing

#### Diagnosis
```bash
# Check OMS agent pods
kubectl get pods -n kube-system | grep omsagent

# Check OMS agent logs
kubectl logs -n kube-system -l component=oms-agent --tail=100

# Verify Log Analytics workspace connection
az aks show -g <rg> -n <cluster> --query "addonProfiles.omsagent"
```

#### Common Causes & Solutions

**OMS agent not running:**
```bash
# Restart OMS agent
kubectl rollout restart daemonset/omsagent -n kube-system

# Check for resource issues
kubectl describe pod -n kube-system -l component=oms-agent
```

**Log Analytics workspace issue:**
```bash
# Verify workspace exists
az monitor log-analytics workspace show -g <rg> -n <workspace-name>

# Re-enable monitoring addon
az aks disable-addons -g <rg> -n <cluster> -a monitoring
az aks enable-addons -g <rg> -n <cluster> -a monitoring \
  --workspace-resource-id <workspace-id>
```

---

## Quick Reference Commands

```bash
# Get cluster info
kubectl cluster-info

# Check all pod status
kubectl get pods --all-namespaces -o wide

# Check events
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -50

# Check node status
kubectl get nodes -o wide
kubectl describe nodes | grep -A5 "Conditions"

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Debug networking
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash

# Check logs
kubectl logs -f <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous
```

---

## Related Documentation

- [Incident Response Runbooks](./INCIDENT_RESPONSE.md)
- [Deployment Checklist](./DEPLOYMENT_CHECKLIST.md)
- [Architecture Overview](./ARCHITECTURE.md)
