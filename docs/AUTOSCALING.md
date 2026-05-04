# Autoscaling Configuration Guide

This document covers the autoscaling configurations for the Enterprise AKS Platform, including Cluster Autoscaler settings and KEDA (Kubernetes Event-Driven Autoscaling) examples.

## Table of Contents

- [Cluster Autoscaler](#cluster-autoscaler)
  - [Overview](#overview)
  - [Configuration Parameters](#configuration-parameters)
  - [Node Pool Settings](#node-pool-settings)
  - [Best Practices](#best-practices)
- [Horizontal Pod Autoscaler (HPA)](#horizontal-pod-autoscaler-hpa)
- [KEDA - Event-Driven Autoscaling](#keda---event-driven-autoscaling)
  - [Installation](#installation)
  - [Azure Service Bus Scaling](#azure-service-bus-scaling)
  - [HTTP Request Scaling](#http-request-scaling)
  - [Scale to Zero](#scale-to-zero)
- [Cost Optimization](#cost-optimization)

---

## Cluster Autoscaler

### Overview

The Cluster Autoscaler automatically adjusts the number of nodes in your AKS cluster based on pending pods and node utilization. It's enabled by default when you configure `min_count` and `max_count` on node pools.

### Configuration Parameters

The following parameters are configured in the AKS Terraform module:

| Parameter | Description | Default | Recommendation |
|-----------|-------------|---------|----------------|
| `min_count` | Minimum number of nodes | Varies by pool | Set based on baseline workload |
| `max_count` | Maximum number of nodes | Varies by pool | Cap to prevent runaway costs |
| `node_count` | Initial node count | Varies by pool | Set to min_count |

### Node Pool Settings

#### System Node Pool

```hcl
# terraform/environments/{env}/terraform.tfvars

system_node_pool = {
  name                         = "system"
  vm_size                      = "Standard_D4s_v5"
  node_count                   = 2
  min_count                    = 2      # Always maintain 2 nodes for HA
  max_count                    = 5      # Cap at 5 to control costs
  availability_zones           = ["1", "2", "3"]
  os_disk_size_gb              = 128
  os_disk_type                 = "Ephemeral"
  only_critical_addons_enabled = true
  node_labels = {
    "nodepool-type" = "system"
    "workload-type" = "system"
  }
}
```

#### User Node Pool

```hcl
user_node_pools = {
  user = {
    name               = "user"
    vm_size            = "Standard_D8s_v5"
    node_count         = 2
    min_count          = 2       # Baseline capacity
    max_count          = 20      # Scale up to 20 nodes max
    availability_zones = ["1", "2", "3"]
    os_disk_size_gb    = 256
    os_disk_type       = "Ephemeral"
    priority           = "Regular"
    eviction_policy    = null
    spot_max_price     = null
    node_labels = {
      "nodepool-type" = "user"
      "workload-type" = "general"
    }
    node_taints = []
  }
}
```

#### Spot Node Pool (Cost Optimization)

```hcl
user_node_pools = {
  spot = {
    name               = "spot"
    vm_size            = "Standard_D8s_v5"
    node_count         = 0
    min_count          = 0       # Scale to zero when not needed
    max_count          = 10      # Cap spot instances
    availability_zones = ["1", "2", "3"]
    os_disk_size_gb    = 256
    os_disk_type       = "Ephemeral"
    priority           = "Spot"
    eviction_policy    = "Delete"
    spot_max_price     = -1      # Pay up to on-demand price
    node_labels = {
      "nodepool-type"                        = "spot"
      "workload-type"                        = "batch"
      "kubernetes.azure.com/scalesetpriority" = "spot"
    }
    node_taints = [
      "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
    ]
  }
}
```

### Best Practices

1. **Set Appropriate Max Counts**: Always set `max_count` to prevent runaway scaling and unexpected costs.

2. **Use Pod Disruption Budgets**: Ensure workloads have PDBs to prevent disruption during scale-down.

3. **Configure Resource Requests**: Accurate resource requests help the autoscaler make better decisions.

4. **Use Node Affinity**: Direct workloads to appropriate node pools using node selectors or affinity rules.

5. **Monitor Autoscaler Events**: Check cluster-autoscaler logs for scaling decisions:
   ```bash
   kubectl logs -n kube-system -l app=cluster-autoscaler
   ```

---

## Horizontal Pod Autoscaler (HPA)

HPA scales pods based on CPU, memory, or custom metrics. The Helm chart includes HPA configuration:

```yaml
# charts/myapp/values-prod.yaml
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
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
```

### HPA Best Practices

1. **Set Conservative Scale-Down**: Use stabilization windows to prevent flapping.
2. **Aggressive Scale-Up**: Allow rapid scale-up to handle traffic spikes.
3. **Use Multiple Metrics**: Combine CPU and memory metrics for better scaling decisions.

---

## KEDA - Event-Driven Autoscaling

KEDA extends Kubernetes autoscaling with event-driven triggers, enabling scale-to-zero and scaling based on external metrics.

### Installation

Install KEDA using Helm:

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

helm install keda kedacore/keda \
  --namespace keda \
  --create-namespace \
  --set podIdentity.azureWorkload.enabled=true
```

### Azure Service Bus Scaling

Scale based on Azure Service Bus queue length:

```yaml
# kubernetes/keda/servicebus-scaledobject.yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: order-processor-scaler
  namespace: app-team-a-prod
spec:
  scaleTargetRef:
    name: order-processor
  pollingInterval: 15
  cooldownPeriod: 300
  minReplicaCount: 0          # Scale to zero when queue is empty
  maxReplicaCount: 50
  triggers:
    - type: azure-servicebus
      metadata:
        queueName: orders
        namespace: myservicebus
        messageCount: "5"     # Scale up when > 5 messages per replica
      authenticationRef:
        name: azure-servicebus-auth
---
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: azure-servicebus-auth
  namespace: app-team-a-prod
spec:
  podIdentity:
    provider: azure-workload
    identityId: <managed-identity-client-id>
```

### HTTP Request Scaling

Scale based on HTTP requests using the KEDA HTTP Add-on:

```yaml
# kubernetes/keda/http-scaledobject.yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: api-gateway-scaler
  namespace: app-team-a-prod
spec:
  scaleTargetRef:
    name: api-gateway
  pollingInterval: 5
  cooldownPeriod: 60
  minReplicaCount: 2          # Keep minimum 2 replicas for HA
  maxReplicaCount: 100
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://prometheus-server.monitoring.svc.cluster.local
        metricName: http_requests_per_second
        query: |
          sum(rate(http_requests_total{deployment="api-gateway"}[1m]))
        threshold: "100"      # Scale when > 100 RPS per replica
```

### Scale to Zero

KEDA enables scale-to-zero for event-driven workloads:

```yaml
# kubernetes/keda/scale-to-zero-example.yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: batch-processor-scaler
  namespace: app-team-a-prod
spec:
  scaleTargetRef:
    name: batch-processor
  pollingInterval: 30
  cooldownPeriod: 300         # Wait 5 minutes before scaling to zero
  idleReplicaCount: 0         # Scale to zero when idle
  minReplicaCount: 0
  maxReplicaCount: 20
  triggers:
    - type: azure-queue
      metadata:
        queueName: batch-jobs
        accountName: mystorageaccount
        queueLength: "1"      # Scale up when any messages exist
      authenticationRef:
        name: azure-storage-auth
---
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: azure-storage-auth
  namespace: app-team-a-prod
spec:
  podIdentity:
    provider: azure-workload
    identityId: <managed-identity-client-id>
```

### KEDA with Azure Event Hubs

Scale based on Event Hub partition lag:

```yaml
# kubernetes/keda/eventhub-scaledobject.yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: event-processor-scaler
  namespace: app-team-a-prod
spec:
  scaleTargetRef:
    name: event-processor
  pollingInterval: 10
  cooldownPeriod: 120
  minReplicaCount: 1
  maxReplicaCount: 32         # Match partition count
  triggers:
    - type: azure-eventhub
      metadata:
        consumerGroup: $Default
        unprocessedEventThreshold: "64"
        blobContainer: checkpoints
      authenticationRef:
        name: azure-eventhub-auth
```

---

## Cost Optimization

### Spot Instance Workloads

Deploy batch workloads to spot nodes:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch-processor
spec:
  template:
    spec:
      nodeSelector:
        kubernetes.azure.com/scalesetpriority: spot
      tolerations:
        - key: kubernetes.azure.com/scalesetpriority
          operator: Equal
          value: spot
          effect: NoSchedule
      containers:
        - name: processor
          resources:
            requests:
              cpu: "500m"
              memory: "512Mi"
            limits:
              cpu: "2"
              memory: "2Gi"
```

### Scaling Recommendations by Environment

| Environment | System Pool | User Pool | Spot Pool | HPA Min |
|-------------|-------------|-----------|-----------|---------|
| Dev         | 1-3 nodes   | 1-5 nodes | 0-3 nodes | 1       |
| Test        | 2-4 nodes   | 2-10 nodes| 0-5 nodes | 2       |
| Prod        | 2-5 nodes   | 3-20 nodes| 0-10 nodes| 3       |

### Cost Alerts

Configure Azure Cost Management alerts to monitor autoscaling costs:

```hcl
# Already configured in terraform/modules/governance/budgets.tf
# Alerts at 50%, 75%, and 90% of budget
```

---

## Monitoring Autoscaling

### Key Metrics to Monitor

1. **Cluster Autoscaler**:
   - `cluster_autoscaler_unschedulable_pods_count`
   - `cluster_autoscaler_scaled_up_nodes_total`
   - `cluster_autoscaler_scaled_down_nodes_total`

2. **HPA**:
   - `kube_horizontalpodautoscaler_status_current_replicas`
   - `kube_horizontalpodautoscaler_status_desired_replicas`

3. **KEDA**:
   - `keda_scaler_metrics_value`
   - `keda_scaled_object_errors`

### Grafana Dashboard

Import the autoscaling dashboard from `kubernetes/monitoring/grafana/dashboards/` for visualization.

---

## Troubleshooting

### Cluster Autoscaler Not Scaling Up

1. Check for pending pods:
   ```bash
   kubectl get pods --all-namespaces | grep Pending
   ```

2. Check autoscaler status:
   ```bash
   kubectl describe configmap cluster-autoscaler-status -n kube-system
   ```

3. Check node pool limits:
   ```bash
   az aks nodepool show -g <rg> --cluster-name <cluster> -n <nodepool> \
     --query "{min:minCount,max:maxCount,current:count}"
   ```

### HPA Not Scaling

1. Verify metrics server is running:
   ```bash
   kubectl get pods -n kube-system | grep metrics-server
   ```

2. Check HPA status:
   ```bash
   kubectl describe hpa <hpa-name> -n <namespace>
   ```

3. Verify resource requests are set on pods.

### KEDA Issues

1. Check KEDA operator logs:
   ```bash
   kubectl logs -n keda -l app=keda-operator
   ```

2. Verify ScaledObject status:
   ```bash
   kubectl describe scaledobject <name> -n <namespace>
   ```
