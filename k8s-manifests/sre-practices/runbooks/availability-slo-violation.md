# 🚨 Runbook: Availability SLO Violation

## Alert Information
- **Alert Name**: SLOViolationAvailabilityCritical
- **Severity**: Critical
- **Service**: SRE Shop
- **SLO Target**: 99.9% availability

## Immediate Response (First 5 minutes)

### 1. Acknowledge the Alert
```bash
# Acknowledge in AlertManager/PagerDuty to stop further notifications
# Update incident channel: #incident-response
```

### 2. Quick Health Check
```bash
# Check overall cluster health
kubectl get nodes
kubectl get pods --all-namespaces

# Check SRE Shop application status
kubectl get pods -n sre-shop
kubectl get services -n sre-shop
```

### 3. Identify Scope of Impact
```bash
# Check which components are down
kubectl describe pods -n sre-shop | grep -E "(Status|Restart)"

# Test external accessibility
curl -I http://$(kubectl get service frontend-service -n sre-shop -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

## Investigation Steps (5-15 minutes)

### 1. Check Application Logs
```bash
# Backend logs
kubectl logs -l app=backend-api -n sre-shop --tail=100

# Frontend logs  
kubectl logs -l app=frontend -n sre-shop --tail=100

# Redis logs
kubectl logs -l app=redis -n sre-shop --tail=100
```

### 2. Check Resource Usage
```bash
# Pod resource consumption
kubectl top pods -n sre-shop

# Node resource availability
kubectl top nodes

# Check for resource limits
kubectl describe pods -n sre-shop | grep -A 5 -B 5 "Limits\|Requests"
```

### 3. Check Recent Changes
```bash
# Check recent deployments
kubectl rollout history deployment/backend-api -n sre-shop
kubectl rollout history deployment/frontend -n sre-shop

# Check recent events
kubectl get events -n sre-shop --sort-by='.lastTimestamp' | tail -20
```

### 4. Check Dependencies
```bash
# Test Redis connectivity
kubectl exec -it deployment/backend-api -n sre-shop -- wget -qO- redis-service:6379 || echo "Redis unreachable"

# Check service endpoints
kubectl get endpoints -n sre-shop
```

## Common Causes and Solutions

### Cause 1: Pod Crashes/Restarts
```bash
# Check restart count
kubectl get pods -n sre-shop -o wide

# If high restart count, check resource limits
kubectl describe pod <pod-name> -n sre-shop | grep -A 10 "Last State\|Restart Count"

# Solution: Scale up resources or fix application bug
kubectl patch deployment backend-api -n sre-shop -p '{"spec":{"template":{"spec":{"containers":[{"name":"backend","resources":{"limits":{"memory":"128Mi","cpu":"200m"}}}]}}}}'
```

### Cause 2: Resource Exhaustion
```bash
# Check node capacity
kubectl describe nodes | grep -A 5 "Allocated resources"

# Solution: Scale cluster or optimize resources
kubectl scale deployment backend-api --replicas=3 -n sre-shop
```

### Cause 3: Network Issues
```bash
# Check service connectivity
kubectl get services -n sre-shop
kubectl describe service frontend-service -n sre-shop

# Test internal networking
kubectl run debug --image=nicolaka/netshoot -it --rm -- nslookup backend-service.sre-shop.svc.cluster.local
```

### Cause 4: Database Issues
```bash
# Check Redis status
kubectl exec -it deployment/redis -n sre-shop -- redis-cli ping

# If Redis is down, restart it
kubectl rollout restart deployment/redis -n sre-shop
kubectl wait --for=condition=ready pod -l app=redis -n sre-shop --timeout=120s
```

## Escalation Procedures

### Escalate if:
- **Cannot identify root cause within 15 minutes**
- **Multiple services affected**
- **Customer data at risk**
- **Security incident suspected**

### Escalation Contacts:
- **L2 Engineer**: @senior-sre-engineer
- **Engineering Manager**: @engineering-manager  
- **Incident Commander**: @incident-commander
- **On-call Security**: @security-oncall

## Communication Templates

### Initial Incident Declaration
```
🚨 INCIDENT DECLARED: SRE Shop Availability Issue

Status: Investigating
Impact: Users may be unable to access the SRE Shop application
ETA for update: 15 minutes

Investigation lead: @your-name
Incident channel: #incident-sre-shop-availability
```

### Status Updates (every 15 minutes)
```
📊 INCIDENT UPDATE - SRE Shop Availability

Status: [Investigating/Identified/Fixing/Monitoring]
Root Cause: [Brief description or "Still investigating"]
Actions Taken: [Bullet points of actions]
Next Steps: [What's being done next]
ETA for next update: [Time]
```

### Resolution Communication
```
✅ INCIDENT RESOLVED - SRE Shop Availability

Root Cause: [Brief description]
Resolution: [What was done to fix it]
Prevention: [Steps to prevent recurrence]
Post-mortem: [Link to post-mortem document]

Service is now fully operational.
```

## Recovery Actions

### 1. Immediate Fixes
```bash
# Restart failed pods
kubectl delete pods -l app=backend-api -n sre-shop

# Scale up if needed
kubectl scale deployment backend-api --replicas=3 -n sre-shop

# Rollback if recent deployment caused issue
kubectl rollout undo deployment/backend-api -n sre-shop
```

### 2. Verification
```bash
# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=backend-api -n sre-shop --timeout=300s

# Test application functionality
curl http://$(kubectl get service frontend-service -n sre-shop -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')/health

# Check metrics recovery
# Prometheus query: up{job="sre-shop-backend"}
```

### 3. Monitor Recovery
```bash
# Watch pod status
kubectl get pods -n sre-shop -w

# Monitor application metrics in Grafana
# Dashboard: SRE Shop Application Overview
```

## Post-Incident Actions

### 1. Document Timeline
- **Detection time**: When alert fired
- **Response time**: When on-call responded  
- **Resolution time**: When service restored
- **Total downtime**: Duration of impact

### 2. Calculate SLO Impact
```bash
# Check current availability over last 7 days
# Prometheus query: avg_over_time(up{job="sre-shop-backend"}[7d])

# Calculate error budget consumption
# Formula: (Downtime minutes / Total minutes) / (1 - SLO target)
```

### 3. Schedule Post-Mortem
- **Within 24 hours for critical incidents**
- **Include timeline, root cause, and action items**
- **Focus on prevention, not blame**

## Prevention Measures

### 1. Monitoring Improvements
```bash
# Add more granular health checks
# Implement synthetic monitoring
# Set up dependency monitoring
```

### 2. Infrastructure Hardening
```bash
# Implement resource quotas
kubectl create quota compute-quota --hard=cpu=4,memory=8Gi,pods=10 -n sre-shop

# Add pod disruption budgets
kubectl apply -f - <<EOF
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
EOF
```

### 3. Testing
```bash
# Regular chaos testing
# Load testing
# Disaster recovery drills
```

## Related Documentation
- [SRE Shop Architecture](../docs/architecture.md)
- [Deployment Guide](../docs/deployment.md)
- [Monitoring Setup](../docs/monitoring.md)
- [Post-Mortem Template](./post-mortem-template.md)