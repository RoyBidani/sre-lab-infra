# 🔄 Runbook: Pod Crash Loop

## Alert Information
- **Alert Name**: PodCrashLoopingBackOff
- **Severity**: Critical
- **Impact**: Service degradation or unavailability
- **Service**: SRE Shop

## Immediate Response (First 2 minutes)

### 1. Identify the Crashing Pod
```bash
# Find pods with high restart count
kubectl get pods -n sre-shop -o wide

# Check pod status details
kubectl describe pod <pod-name> -n sre-shop
```

### 2. Quick Assessment
```bash
# Check if service is still functional
kubectl get endpoints -n sre-shop

# Test service availability
curl -I http://$(kubectl get service frontend-service -n sre-shop -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

## Investigation Steps (2-10 minutes)

### 1. Examine Pod Logs
```bash
# Current logs
kubectl logs <pod-name> -n sre-shop

# Previous instance logs (if pod restarted)
kubectl logs <pod-name> -n sre-shop --previous

# Follow logs in real-time
kubectl logs <pod-name> -n sre-shop -f
```

### 2. Check Pod Events
```bash
# Get recent events for the pod
kubectl describe pod <pod-name> -n sre-shop | grep -A 20 "Events:"

# Check all recent events in namespace
kubectl get events -n sre-shop --sort-by='.lastTimestamp' | tail -10
```

### 3. Check Resource Usage
```bash
# Current resource consumption
kubectl top pod <pod-name> -n sre-shop

# Resource limits and requests
kubectl describe pod <pod-name> -n sre-shop | grep -A 10 "Limits\|Requests"

# Node resource availability
kubectl describe node $(kubectl get pod <pod-name> -n sre-shop -o jsonpath='{.spec.nodeName}')
```

## Common Causes and Solutions

### Cause 1: Out of Memory (OOMKilled)
**Symptoms**: Exit code 137, "OOMKilled" in pod status

```bash
# Check memory usage pattern
kubectl top pod <pod-name> -n sre-shop --containers

# Solution: Increase memory limits
kubectl patch deployment <deployment-name> -n sre-shop -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container-name>","resources":{"limits":{"memory":"256Mi"}}}]}}}}'
```

### Cause 2: Application Error/Exception
**Symptoms**: Exit code 1, application error logs

```bash
# Examine application logs for errors
kubectl logs <pod-name> -n sre-shop | grep -i "error\|exception\|panic\|fatal"

# Solution: Rollback to previous working version
kubectl rollout undo deployment/<deployment-name> -n sre-shop
kubectl rollout status deployment/<deployment-name> -n sre-shop
```

### Cause 3: Failed Health Checks
**Symptoms**: "Readiness probe failed", "Liveness probe failed"

```bash
# Check probe configuration
kubectl describe pod <pod-name> -n sre-shop | grep -A 5 "Liveness\|Readiness"

# Test health endpoint manually
kubectl exec -it <pod-name> -n sre-shop -- wget -qO- localhost:8080/health
```

**Solution**: Adjust probe timing or fix health endpoint
```bash
kubectl patch deployment <deployment-name> -n sre-shop -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "<container-name>",
          "readinessProbe": {
            "initialDelaySeconds": 30,
            "periodSeconds": 10,
            "timeoutSeconds": 5
          }
        }]
      }
    }
  }
}'
```

### Cause 4: Configuration Issues
**Symptoms**: "Config file not found", "Invalid configuration"

```bash
# Check ConfigMap and Secret mounts
kubectl describe pod <pod-name> -n sre-shop | grep -A 5 "Mounts:"

# Verify ConfigMap content
kubectl get configmap -n sre-shop -o yaml

# Solution: Fix configuration
kubectl edit configmap <configmap-name> -n sre-shop
```

### Cause 5: Dependency Issues
**Symptoms**: "Connection refused", "Service unavailable"

```bash
# Check if dependent services are running
kubectl get pods -n sre-shop -l app=redis
kubectl get service redis-service -n sre-shop

# Test connectivity to dependencies
kubectl exec -it <pod-name> -n sre-shop -- nslookup redis-service.sre-shop.svc.cluster.local
```

## Recovery Actions

### 1. Temporary Fixes
```bash
# Scale down the problematic deployment
kubectl scale deployment <deployment-name> --replicas=0 -n sre-shop

# Wait for pods to terminate
kubectl wait --for=delete pod -l app=<app-label> -n sre-shop --timeout=60s

# Scale back up
kubectl scale deployment <deployment-name> --replicas=2 -n sre-shop
```

### 2. Rollback Strategy
```bash
# Check rollout history
kubectl rollout history deployment/<deployment-name> -n sre-shop

# Rollback to previous revision
kubectl rollout undo deployment/<deployment-name> -n sre-shop

# Monitor rollback progress
kubectl rollout status deployment/<deployment-name> -n sre-shop
```

### 3. Emergency Workaround
```bash
# If specific pod keeps failing, cordon the node
kubectl cordon <node-name>

# Manually delete the problematic pod
kubectl delete pod <pod-name> -n sre-shop --force --grace-period=0

# Uncordon the node once issue is resolved
kubectl uncordon <node-name>
```

## Advanced Debugging

### 1. Pod Shell Access
```bash
# Get shell access to debug
kubectl exec -it <pod-name> -n sre-shop -- /bin/sh

# If pod keeps crashing, use debug container
kubectl debug <pod-name> -n sre-shop -it --image=nicolaka/netshoot
```

### 2. Container Runtime Debugging
```bash
# Check container runtime logs
# (Node access required)
sudo journalctl -u containerd | grep <pod-name>

# Check kubelet logs
sudo journalctl -u kubelet | grep <pod-name>
```

### 3. Resource Monitoring
```bash
# Monitor resource usage over time
kubectl top pod <pod-name> -n sre-shop --containers

# Check if hitting resource quotas
kubectl describe quota -n sre-shop
```

## Prevention Measures

### 1. Implement Proper Resource Limits
```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "50m"
  limits:
    memory: "128Mi"
    cpu: "100m"
```

### 2. Add Pod Disruption Budget
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: backend-pdb
  namespace: sre-shop
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: backend-api
```

### 3. Improve Health Checks
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

### 4. Implement Circuit Breakers
```bash
# Add retry logic and circuit breakers in application code
# Implement graceful degradation
# Add dependency health checks
```

## Monitoring and Alerting

### 1. Key Metrics to Watch
```promql
# Pod restart rate
rate(kube_pod_container_status_restarts_total{namespace="sre-shop"}[15m])

# Pod status
kube_pod_status_phase{namespace="sre-shop"}

# Resource usage trends
container_memory_usage_bytes{namespace="sre-shop"}
```

### 2. Additional Alerts
```yaml
- alert: HighPodRestartRate
  expr: rate(kube_pod_container_status_restarts_total{namespace="sre-shop"}[15m]) > 0.1
  for: 5m
  
- alert: PodStuckInPending
  expr: kube_pod_status_phase{namespace="sre-shop",phase="Pending"} > 0
  for: 10m
```

## Communication

### Status Update Template
```
🔄 Pod Crash Loop - SRE Shop

Affected Component: [Pod/Service name]
Impact: [Service degradation/unavailability]
Root Cause: [Brief description]
Actions Taken: [List of actions]
Current Status: [Investigating/Fixing/Monitoring]
ETA: [Expected resolution time]
```

## Post-Incident Actions

### 1. Root Cause Analysis
- **Was this preventable?**
- **What monitoring gaps exist?**
- **Are resource limits appropriate?**
- **Is the application handling errors gracefully?**

### 2. Improvement Actions
- Update resource requests/limits based on actual usage
- Improve application error handling
- Add more comprehensive monitoring
- Update deployment strategies

## Related Runbooks
- [High Memory Usage](./high-memory-usage.md)
- [Application Error Investigation](./application-errors.md)
- [Resource Exhaustion](./resource-exhaustion.md)
- [Rollback Procedures](./rollback-procedures.md)