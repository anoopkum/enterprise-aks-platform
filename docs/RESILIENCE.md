# Resilience Patterns Guide

This document covers resilience patterns and configurations for the Enterprise AKS Platform, including service mesh options and chaos engineering practices.

## Table of Contents

1. [Service Mesh Options](#service-mesh-options)
2. [Circuit Breaker Patterns](#circuit-breaker-patterns)
3. [Retry Policies](#retry-policies)
4. [Chaos Engineering](#chaos-engineering)
5. [Best Practices](#best-practices)

---

## Service Mesh Options

A service mesh provides automatic retries, circuit breakers, and observability for service-to-service communication. This section documents two popular options for AKS.

### Option 1: Istio Service Mesh

#### Installation

```bash
# Download Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*

# Install Istio with production profile
istioctl install --set profile=production \
  --set meshConfig.accessLogFile=/dev/stdout \
  --set meshConfig.enableTracing=true \
  --set values.global.tracer.zipkin.address=otel-collector.monitoring:9411

# Enable sidecar injection for application namespaces
kubectl label namespace app-team-a-prod istio-injection=enabled
kubectl label namespace app-team-a-dev istio-injection=enabled
```

#### Circuit Breaker Configuration

```yaml
# kubernetes/istio/destination-rule.yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: api-gateway-circuit-breaker
  namespace: app-team-a-prod
spec:
  host: api-gateway.app-team-a-prod.svc.cluster.local
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
        connectTimeout: 5s
      http:
        h2UpgradePolicy: UPGRADE
        http1MaxPendingRequests: 100
        http2MaxRequests: 1000
        maxRequestsPerConnection: 100
        maxRetries: 3
    outlierDetection:
      # Eject hosts with 5xx errors
      consecutive5xxErrors: 5
      interval: 10s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
      minHealthPercent: 30
```

#### Retry Policy Configuration

```yaml
# kubernetes/istio/virtual-service.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api-gateway-retry
  namespace: app-team-a-prod
spec:
  hosts:
    - api-gateway.app-team-a-prod.svc.cluster.local
  http:
    - route:
        - destination:
            host: api-gateway.app-team-a-prod.svc.cluster.local
      retries:
        attempts: 3
        perTryTimeout: 2s
        retryOn: connect-failure,refused-stream,unavailable,cancelled,retriable-4xx,5xx
      timeout: 10s
```

#### Timeout Configuration

```yaml
# kubernetes/istio/timeout-policy.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: order-service-timeout
  namespace: app-team-a-prod
spec:
  hosts:
    - order-service.app-team-a-prod.svc.cluster.local
  http:
    - route:
        - destination:
            host: order-service.app-team-a-prod.svc.cluster.local
      timeout: 30s
      retries:
        attempts: 2
        perTryTimeout: 10s
```

### Option 2: Linkerd Service Mesh

Linkerd is a lighter-weight alternative to Istio with simpler configuration.

#### Installation

```bash
# Install Linkerd CLI
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh

# Validate cluster
linkerd check --pre

# Install Linkerd CRDs
linkerd install --crds | kubectl apply -f -

# Install Linkerd control plane
linkerd install | kubectl apply -f -

# Verify installation
linkerd check

# Enable injection for namespaces
kubectl annotate namespace app-team-a-prod linkerd.io/inject=enabled
kubectl annotate namespace app-team-a-dev linkerd.io/inject=enabled
```

#### Service Profile with Retries

```yaml
# kubernetes/linkerd/service-profile.yaml
apiVersion: linkerd.io/v1alpha2
kind: ServiceProfile
metadata:
  name: api-gateway.app-team-a-prod.svc.cluster.local
  namespace: app-team-a-prod
spec:
  routes:
    - name: GET /api/orders
      condition:
        method: GET
        pathRegex: /api/orders.*
      isRetryable: true
      timeout: 10s
    - name: POST /api/orders
      condition:
        method: POST
        pathRegex: /api/orders
      isRetryable: false  # Don't retry non-idempotent operations
      timeout: 30s
  retryBudget:
    retryRatio: 0.2  # Max 20% of requests can be retries
    minRetriesPerSecond: 10
    ttl: 10s
```

### Service Mesh Comparison

| Feature | Istio | Linkerd |
|---------|-------|---------|
| Resource Usage | Higher | Lower |
| Configuration Complexity | Higher | Lower |
| Feature Set | Comprehensive | Essential |
| mTLS | Yes | Yes |
| Circuit Breaker | Yes | Via Service Profiles |
| Traffic Splitting | Yes | Yes |
| Multi-cluster | Yes | Yes |

### Recommendation

- **Start with Linkerd** for simpler deployments and lower overhead
- **Use Istio** when you need advanced traffic management features

---

## Circuit Breaker Patterns

### Application-Level Circuit Breaker (Without Service Mesh)

If not using a service mesh, implement circuit breakers in application code.

#### .NET Example (Polly)

```csharp
// Program.cs
services.AddHttpClient<IOrderService, OrderService>()
    .AddPolicyHandler(GetCircuitBreakerPolicy());

static IAsyncPolicy<HttpResponseMessage> GetCircuitBreakerPolicy()
{
    return HttpPolicyExtensions
        .HandleTransientHttpError()
        .CircuitBreakerAsync(
            handledEventsAllowedBeforeBreaking: 5,
            durationOfBreak: TimeSpan.FromSeconds(30),
            onBreak: (result, duration) =>
            {
                Console.WriteLine($"Circuit breaker opened for {duration}");
            },
            onReset: () =>
            {
                Console.WriteLine("Circuit breaker reset");
            });
}
```

#### Node.js Example (opossum)

```javascript
// circuit-breaker.js
const CircuitBreaker = require('opossum');

const options = {
  timeout: 3000,           // 3 second timeout
  errorThresholdPercentage: 50,  // Open circuit at 50% errors
  resetTimeout: 30000      // Try again after 30 seconds
};

const breaker = new CircuitBreaker(callExternalService, options);

breaker.on('open', () => console.log('Circuit opened'));
breaker.on('halfOpen', () => console.log('Circuit half-open'));
breaker.on('close', () => console.log('Circuit closed'));

// Use the breaker
breaker.fire(params)
  .then(result => handleResult(result))
  .catch(err => handleError(err));
```

#### Java Example (Resilience4j)

```java
// CircuitBreakerConfig.java
@Configuration
public class CircuitBreakerConfig {
    
    @Bean
    public CircuitBreaker orderServiceCircuitBreaker() {
        CircuitBreakerConfig config = CircuitBreakerConfig.custom()
            .failureRateThreshold(50)
            .waitDurationInOpenState(Duration.ofSeconds(30))
            .permittedNumberOfCallsInHalfOpenState(3)
            .slidingWindowSize(10)
            .build();
        
        return CircuitBreaker.of("orderService", config);
    }
}
```

---

## Retry Policies

### Kubernetes Native Retries

Configure retries at the ingress level:

```yaml
# kubernetes/ingress/retry-annotations.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-gateway
  namespace: app-team-a-prod
  annotations:
    nginx.ingress.kubernetes.io/proxy-next-upstream: "error timeout http_502 http_503 http_504"
    nginx.ingress.kubernetes.io/proxy-next-upstream-tries: "3"
    nginx.ingress.kubernetes.io/proxy-next-upstream-timeout: "10s"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "5"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "30"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "30"
spec:
  ingressClassName: nginx
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-gateway
                port:
                  number: 80
```

### Retry Best Practices

1. **Only retry idempotent operations** (GET, PUT, DELETE)
2. **Use exponential backoff** to avoid thundering herd
3. **Set retry budgets** to prevent cascade failures
4. **Add jitter** to spread out retry attempts

```yaml
# Example retry configuration with backoff
retries:
  attempts: 3
  perTryTimeout: 2s
  retryOn: connect-failure,refused-stream,unavailable,cancelled,5xx
  backoff:
    baseInterval: 100ms
    maxInterval: 1s
```

---

## Chaos Engineering

Chaos engineering helps validate system resilience by intentionally introducing failures.

### Chaos Mesh Installation

```bash
# Add Chaos Mesh Helm repo
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm repo update

# Install Chaos Mesh
helm install chaos-mesh chaos-mesh/chaos-mesh \
  --namespace chaos-testing \
  --create-namespace \
  --set chaosDaemon.runtime=containerd \
  --set chaosDaemon.socketPath=/run/containerd/containerd.sock

# Verify installation
kubectl get pods -n chaos-testing
```

### Pod Failure Experiment

```yaml
# kubernetes/chaos-mesh/pod-failure.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-failure-test
  namespace: chaos-testing
spec:
  action: pod-failure
  mode: one
  duration: "60s"
  selector:
    namespaces:
      - app-team-a-dev  # Only test in dev!
    labelSelectors:
      app: api-gateway
  scheduler:
    cron: "@every 2h"  # Run every 2 hours
```

### Network Latency Experiment

```yaml
# kubernetes/chaos-mesh/network-latency.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-latency-test
  namespace: chaos-testing
spec:
  action: delay
  mode: all
  selector:
    namespaces:
      - app-team-a-dev
    labelSelectors:
      app: order-service
  delay:
    latency: "200ms"
    correlation: "25"
    jitter: "50ms"
  duration: "5m"
  scheduler:
    cron: "@every 4h"
```

### Network Partition Experiment

```yaml
# kubernetes/chaos-mesh/network-partition.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-partition-test
  namespace: chaos-testing
spec:
  action: partition
  mode: all
  selector:
    namespaces:
      - app-team-a-dev
    labelSelectors:
      app: api-gateway
  direction: both
  target:
    selector:
      namespaces:
        - app-team-a-dev
      labelSelectors:
        app: order-service
  duration: "2m"
```

### CPU Stress Experiment

```yaml
# kubernetes/chaos-mesh/cpu-stress.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: cpu-stress-test
  namespace: chaos-testing
spec:
  mode: one
  selector:
    namespaces:
      - app-team-a-dev
    labelSelectors:
      app: api-gateway
  stressors:
    cpu:
      workers: 2
      load: 80
  duration: "5m"
```

### Memory Stress Experiment

```yaml
# kubernetes/chaos-mesh/memory-stress.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: memory-stress-test
  namespace: chaos-testing
spec:
  mode: one
  selector:
    namespaces:
      - app-team-a-dev
    labelSelectors:
      app: api-gateway
  stressors:
    memory:
      workers: 2
      size: "512MB"
  duration: "5m"
```

### Chaos Engineering Workflow

```yaml
# kubernetes/chaos-mesh/workflow.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: Workflow
metadata:
  name: resilience-test-workflow
  namespace: chaos-testing
spec:
  entry: serial-tests
  templates:
    - name: serial-tests
      templateType: Serial
      deadline: 30m
      children:
        - pod-failure
        - network-delay
        - cpu-stress
    
    - name: pod-failure
      templateType: PodChaos
      deadline: 5m
      podChaos:
        action: pod-failure
        mode: one
        selector:
          namespaces:
            - app-team-a-dev
          labelSelectors:
            app: api-gateway
    
    - name: network-delay
      templateType: NetworkChaos
      deadline: 5m
      networkChaos:
        action: delay
        mode: all
        selector:
          namespaces:
            - app-team-a-dev
          labelSelectors:
            app: api-gateway
        delay:
          latency: "100ms"
    
    - name: cpu-stress
      templateType: StressChaos
      deadline: 5m
      stressChaos:
        mode: one
        selector:
          namespaces:
            - app-team-a-dev
          labelSelectors:
            app: api-gateway
        stressors:
          cpu:
            workers: 1
            load: 50
```

### Chaos Engineering Safety Rules

1. **Never run chaos experiments in production without approval**
2. **Start with dev/test environments**
3. **Have monitoring in place before running experiments**
4. **Define clear abort conditions**
5. **Run experiments during business hours initially**
6. **Document expected vs actual behavior**

---

## Best Practices

### Resilience Checklist

#### Application Level
- [ ] Circuit breakers implemented for external calls
- [ ] Retry logic with exponential backoff
- [ ] Timeouts configured for all external calls
- [ ] Graceful degradation when dependencies fail
- [ ] Health checks properly implemented

#### Kubernetes Level
- [ ] Pod Disruption Budgets configured
- [ ] Resource requests and limits set
- [ ] Liveness and readiness probes configured
- [ ] Topology spread constraints for zone distribution
- [ ] Pod anti-affinity for high availability

#### Infrastructure Level
- [ ] Multi-zone deployment
- [ ] Autoscaling configured (HPA, Cluster Autoscaler)
- [ ] Database with zone-redundant HA
- [ ] Geo-redundant backups
- [ ] DDoS protection enabled

### Timeout Guidelines

| Call Type | Recommended Timeout |
|-----------|---------------------|
| Database query | 5-10 seconds |
| Cache lookup | 100-500 ms |
| Internal service call | 2-5 seconds |
| External API call | 10-30 seconds |
| File upload | 60-300 seconds |

### Circuit Breaker Settings

| Setting | Recommended Value |
|---------|-------------------|
| Failure threshold | 50% |
| Minimum requests | 10 |
| Open duration | 30 seconds |
| Half-open requests | 3-5 |

---

## Related Documentation

- [Architecture Overview](./ARCHITECTURE.md)
- [Autoscaling Guide](./AUTOSCALING.md)
- [Incident Response Runbooks](./runbooks/INCIDENT_RESPONSE.md)
- [Troubleshooting Guide](./runbooks/TROUBLESHOOTING.md)
