# 🛠️ Operational Procedures Guide
## Complete Day-2 Operations Manual

This comprehensive guide covers all operational aspects of maintaining and managing the SRE Lab Infrastructure in production. It includes step-by-step procedures, troubleshooting guides, and best practices for ongoing operations.

---

## 📅 **Daily Operations**

### **Morning Health Check Routine (15 minutes)**

#### **Step 1: SLO Dashboard Review**
```bash
# Access Grafana Dashboard
1. Open: http://your-grafana-url:3000
2. Login: admin / admin123
3. Navigate to "SRE Shop - SLO Dashboard"

# Check Critical Metrics (2 minutes)
✅ Availability SLI: Should be >99.9% (green)
✅ Success Rate SLI: Should be 99.9-100% (green)  
✅ Error Budget: Should be <50% consumed (green)
✅ CPU Usage: Should be <50% (green)

# Red Flags (Immediate Investigation Required)
🚨 Availability <99%: Service outage likely
🚨 Error rate >1%: Application errors
🚨 Error budget >75%: SLO violation risk
🚨 CPU >80%: Resource exhaustion
```

#### **Step 2: Infrastructure Health Check**
```bash
# Kubernetes Cluster Health
kubectl get nodes
# Expected: All nodes Ready status

kubectl get pods --all-namespaces
# Expected: All pods Running or Completed

kubectl top nodes
# Expected: CPU <80%, Memory <85%

# AWS EKS Cluster Status
aws eks describe-cluster --name sre-training-cluster --region eu-central-1
# Expected: Status "ACTIVE"

# Check for Failed Pods
kubectl get pods --all-namespaces --field-selector=status.phase=Failed
# Expected: No output (no failed pods)
```

#### **Step 3: Monitoring Stack Verification**
```bash
# Prometheus Health
kubectl port-forward -n monitoring svc/prometheus-service 9090:9090 &
curl -s http://localhost:9090/-/healthy
# Expected: Prometheus is Healthy

# Check Prometheus Targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'
# Expected: No output (all targets healthy)

# Grafana Health  
kubectl port-forward -n monitoring svc/grafana 3000:3000 &
curl -s http://localhost:3000/api/health
# Expected: {"commit":"...","database":"ok","version":"..."}

# AlertManager Health
kubectl port-forward -n monitoring svc/alertmanager 9093:9093 &
curl -s http://localhost:9093/-/healthy  
# Expected: OK
```

#### **Step 4: Application Health Verification**
```bash
# Backend Service Health
kubectl get endpoints backend-service -n sre-shop
# Expected: Shows healthy pod IPs

# Traffic Generator Status
kubectl get deployment traffic-generator -n sre-shop
# Expected: 1/1 READY

# Application Metrics Endpoint
kubectl port-forward -n sre-shop svc/backend-service 8080:8080 &
curl -s http://localhost:8080/metrics | head -10
# Expected: Prometheus metrics output

# Health Endpoints
curl -s http://localhost:8080/healthz
# Expected: HTTP 200 OK

curl -s http://localhost:8080/readyz  
# Expected: HTTP 200 OK
```

### **Weekly Maintenance Tasks (30 minutes)**

#### **Security Updates Check**
```bash
# Check for Kubernetes Updates
kubectl version --short
aws eks describe-cluster --name sre-training-cluster --query 'cluster.version'
# Compare with latest EKS version

# Node Security Updates
kubectl get nodes -o wide
# Check AMI versions, plan updates if >1 month old

# Container Image Updates
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}' --all-namespaces
# Check for outdated base images
```

#### **Performance Review**
```bash
# Resource Utilization Trends (Last 7 days)
# Check Grafana "Kubernetes Overview" dashboard
# Look for:
├── CPU trend: Should be stable, <70% average
├── Memory trend: Should be stable, no leaks
├── Pod restart frequency: Should be minimal
└── Request rate patterns: Understand normal vs peaks

# Capacity Planning Review
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=memory
kubectl top pods --all-namespaces --sort-by=cpu

# Storage Usage Check
kubectl get pv,pvc --all-namespaces
df -h  # On each node (if accessible)
```

---

## 🔄 **Backup and Disaster Recovery**

### **Backup Strategy**

#### **Kubernetes Configuration Backup**
```bash
# Daily Automated Backup Script
#!/bin/bash
BACKUP_DIR="/backup/k8s-$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Backup all Kubernetes resources
kubectl get all --all-namespaces -o yaml > $BACKUP_DIR/all-resources.yaml

# Backup specific critical resources
kubectl get configmaps --all-namespaces -o yaml > $BACKUP_DIR/configmaps.yaml
kubectl get secrets --all-namespaces -o yaml > $BACKUP_DIR/secrets.yaml
kubectl get persistentvolumes -o yaml > $BACKUP_DIR/persistentvolumes.yaml

# Backup Grafana dashboards
kubectl get configmap grafana-dashboards -n monitoring -o yaml > $BACKUP_DIR/grafana-dashboards.yaml

# Backup Prometheus configuration
kubectl get configmap prometheus-config -n monitoring -o yaml > $BACKUP_DIR/prometheus-config.yaml

# Upload to S3 (if configured)
aws s3 sync $BACKUP_DIR s3://your-backup-bucket/k8s-backups/$(date +%Y%m%d)/

# Cleanup old backups (keep 30 days)
find /backup -name "k8s-*" -type d -mtime +30 -exec rm -rf {} \;
```

#### **Prometheus Data Backup**
```bash
# Prometheus Data Snapshot
kubectl exec -n monitoring prometheus-xxx -- promtool tsdb create-blocks-from-snapshot /prometheus

# For production: Use Thanos or Cortex for long-term storage
# Configure S3 backup for Prometheus data
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-storage-config
data:
  thanos.yaml: |
    type: s3
    config:
      bucket: "prometheus-long-term-storage"
      endpoint: "s3.eu-central-1.amazonaws.com"
      region: "eu-central-1"
```

#### **Infrastructure State Backup**
```bash
# Terraform State Backup (Critical!)
# Automated backup script
#!/bin/bash
cd /path/to/terraform
terraform state pull > terraform-state-$(date +%Y%m%d-%H%M).json
aws s3 cp terraform-state-$(date +%Y%m%d-%H%M).json s3://terraform-state-backup/

# Keep 90 days of state backups
aws s3 ls s3://terraform-state-backup/ | awk '$1 < "'$(date -d '90 days ago' '+%Y-%m-%d')'"' | awk '{print $4}' | xargs -I {} aws s3 rm s3://terraform-state-backup/{}
```

### **Disaster Recovery Procedures**

#### **Complete Cluster Loss Recovery**
```bash
# Step 1: Assess Damage (5-10 minutes)
1. Check AWS Console for EKS cluster status
2. Verify VPC and networking infrastructure
3. Check if worker nodes are accessible
4. Determine if this is partial or complete failure

# Step 2: Infrastructure Recovery (15-30 minutes)
cd terraform/
terraform plan  # Check what needs to be recreated
terraform apply # Recreate missing infrastructure

# Step 3: Restore Kubernetes Resources (10-20 minutes)
# Restore from latest backup
kubectl apply -f /backup/k8s-latest/all-resources.yaml

# Or restore selectively:
kubectl apply -f /backup/k8s-latest/configmaps.yaml
kubectl apply -f /backup/k8s-latest/secrets.yaml

# Step 4: Verify Recovery (10-15 minutes)
# Follow daily health check procedure
# Verify all services are operational
# Check monitoring data collection

# Step 5: Post-Recovery Actions
# Update documentation with lessons learned
# Review and improve backup procedures
# Conduct post-mortem meeting
```

#### **Monitoring Stack Recovery**
```bash
# Prometheus Data Loss Recovery
1. Deploy new Prometheus instance
2. Restore configuration from backup
3. Import historical data if available
4. Reconfigure Grafana data sources

# Grafana Dashboard Recovery
kubectl apply -f /backup/k8s-latest/grafana-dashboards.yaml
kubectl rollout restart deployment grafana -n monitoring

# AlertManager Configuration Recovery
kubectl apply -f /backup/k8s-latest/alertmanager-config.yaml
kubectl rollout restart deployment alertmanager -n monitoring
```

---

## 🔒 **Security Hardening Procedures**

### **Regular Security Maintenance**

#### **Weekly Security Checklist**
```bash
# 1. Check for Security Updates
kubectl get nodes -o wide
# Review AMI versions and security patches

# 2. Review Access Logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller
# Look for unusual access patterns

# 3. Audit RBAC Permissions
kubectl get clusterrolebindings
kubectl get rolebindings --all-namespaces
# Verify principle of least privilege

# 4. Check for Privileged Containers
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.securityContext.privileged}{"\n"}{end}' | grep true
# Should return minimal or no results

# 5. Verify Network Policies (if implemented)
kubectl get networkpolicies --all-namespaces
# Ensure proper network segmentation
```

#### **Monthly Security Deep Dive**
```bash
# 1. Vulnerability Scanning
# Use tools like Trivy, Twistlock, or AWS Inspector
trivy image stefanprodan/podinfo:6.5.0
trivy k8s --report summary cluster

# 2. Certificate Expiration Check
kubectl get secrets --all-namespaces -o jsonpath='{range .items[?(@.type=="kubernetes.io/tls")]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.data.tls\.crt}{"\n"}{end}' | while read namespace name cert; do
  echo "$cert" | base64 -d | openssl x509 -noout -enddate
done

# 3. EKS Security Best Practices Audit
# Check EKS cluster configuration
aws eks describe-cluster --name sre-training-cluster
# Verify:
# - Private endpoint access enabled
# - Logging enabled for audit, api, authenticator
# - Latest Kubernetes version

# 4. IAM Role Review
aws iam list-attached-role-policies --role-name EKSNodeGroupRole
aws iam list-attached-role-policies --role-name EKSClusterRole
# Verify only necessary permissions attached
```

### **Incident Response Security Procedures**

#### **Security Incident Detection**
```bash
# Indicators of Compromise (IoCs)
1. Unusual resource consumption patterns
2. Unexpected network connections
3. Failed authentication attempts spike
4. Privileged container creation
5. Suspicious API calls in audit logs

# Immediate Response Steps
1. Isolate affected resources
   kubectl cordon <node>  # Prevent new pods
   kubectl drain <node>   # Move existing pods
   
2. Preserve evidence
   kubectl logs <suspicious-pod> > evidence-$(date +%Y%m%d-%H%M).log
   
3. Block malicious traffic
   # Update security groups/network policies
   
4. Rotate compromised credentials
   # Update secrets, service account tokens
```

---

## 📈 **Performance Optimization**

### **Regular Performance Tuning**

#### **Monthly Performance Review**
```bash
# 1. Resource Utilization Analysis
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=cpu
kubectl top pods --all-namespaces --sort-by=memory

# Identify optimization opportunities:
# - Over-provisioned pods (low utilization)
# - Under-provisioned pods (high utilization, throttling)
# - Uneven distribution across nodes

# 2. Prometheus Query Performance
# Check slow queries in Grafana
# Look at prometheus_rule_evaluation_duration_seconds
# Optimize expensive queries with recording rules

# 3. Network Performance Check
kubectl exec -it <pod> -- netstat -i
kubectl exec -it <pod> -- ss -tuln
# Monitor for network bottlenecks

# 4. Storage Performance Review
kubectl get pv -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage,ACCESS:.spec.accessModes,STORAGECLASS:.spec.storageClassName,STATUS:.status.phase
# Check IOPS usage, consider upgrading to gp3
```

#### **Application Performance Optimization**
```bash
# 1. JVM Tuning (if using Java apps)
# Add JVM metrics to Prometheus
-javaagent:jmx_prometheus_javaagent.jar=8080:config.yaml

# Monitor garbage collection
jvm_gc_collection_seconds_total
jvm_memory_bytes_used

# 2. Resource Limits Optimization
# Based on actual usage patterns:
resources:
  requests:
    cpu: "100m"      # 90th percentile of actual usage
    memory: "128Mi"   # 90th percentile + 20% buffer
  limits:
    cpu: "500m"      # 5x requests (burst capability)
    memory: "256Mi"   # 2x requests (prevent OOM)

# 3. Database Connection Optimization
# Monitor connection pool metrics
db_connections_active
db_connections_idle
db_connection_wait_time

# Tune connection pool:
max_connections: 20    # Based on CPU cores × 2
min_idle: 5           # Always keep some connections ready
connection_timeout: 30s # Don't wait too long
```

### **Scaling Optimization**

#### **Horizontal Pod Autoscaler Tuning**
```bash
# Current HPA analysis
kubectl describe hpa --all-namespaces

# Optimize based on patterns:
# - If scaling up too aggressively: Increase target utilization
# - If scaling too slowly: Decrease stabilization window
# - If oscillating: Increase stabilization window

# Updated HPA configuration
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70    # Tuned based on response time correlation
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60     # Faster response
      policies:
      - type: Percent
        value: 100                       # Double capacity quickly
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300    # Slower scale down
      policies:
      - type: Percent
        value: 25                        # Remove 25% at a time
        periodSeconds: 60
```

#### **Cluster Scaling Optimization**
```bash
# Node Group Scaling Review
aws eks describe-nodegroup --cluster-name sre-training-cluster --nodegroup-name sre-training-nodes

# Optimize based on usage:
# - If nodes often at high utilization: Increase max size
# - If many nodes idle: Decrease desired capacity
# - If frequent scaling events: Adjust scaling policies

# Cluster Autoscaler tuning
kubectl edit configmap cluster-autoscaler-status -n kube-system
# Key parameters:
scale-down-delay-after-add: 10m        # Wait before scaling down
scale-down-unneeded-time: 10m          # How long node can be unneeded
scale-down-utilization-threshold: 0.7   # Scale down if <70% utilized
```

---

## 🔧 **Troubleshooting Procedures**

### **Systematic Troubleshooting Framework**

#### **The 5-Layer Debugging Model**
```bash
# Layer 1: User/Application Layer
1. Check SLI dashboards for user impact
2. Review application logs for errors
3. Verify application configuration

# Layer 2: Kubernetes Orchestration Layer  
1. Check pod status and events
2. Review service discovery and endpoints
3. Verify RBAC and security contexts

# Layer 3: Container Runtime Layer
1. Examine container logs and metrics
2. Check resource constraints and limits
3. Verify image and configuration

# Layer 4: Node/OS Layer
1. Check node resources and health
2. Review system logs and kernel messages
3. Verify network connectivity

# Layer 5: Infrastructure Layer
1. Check AWS service status
2. Review VPC and networking configuration
3. Verify EKS cluster health
```

#### **Common Problem Patterns**

**Pattern 1: Intermittent 5xx Errors**
```bash
# Investigation Steps
1. Check error rate dashboard
   # Look for patterns: time-based, geographic, user-specific

2. Examine application logs
   kubectl logs -f deployment/backend -n sre-shop --tail=100
   # Look for stack traces, database errors, timeout messages

3. Check resource constraints
   kubectl describe pods -n sre-shop
   # Look for CPU throttling, memory pressure

4. Review recent changes
   kubectl rollout history deployment/backend -n sre-shop
   # Correlate with deployment timing

# Common Causes & Solutions
Database connection exhaustion:
├── Symptom: Connection timeout errors in logs
├── Solution: Increase connection pool size or add connection pooling
└── Prevention: Monitor db_connections_active metric

Memory leaks:
├── Symptom: Gradually increasing memory usage, OOMKilled events
├── Solution: Restart pods, investigate application code
└── Prevention: Memory usage alerting, heap dump analysis

Dependency failures:
├── Symptom: Timeout errors calling external services
├── Solution: Implement circuit breakers, fallback mechanisms
└── Prevention: Monitor external service SLAs
```

**Pattern 2: High Latency**
```bash
# Investigation Priority Order
1. Database performance (most common cause)
   # Check query execution time
   # Look for lock contention
   # Verify index usage

2. Network issues
   # Check pod-to-pod connectivity
   # Verify DNS resolution time
   # Look for packet loss

3. Resource saturation
   # CPU usage patterns
   # Memory allocation/garbage collection
   # I/O wait times

4. External dependencies
   # Third-party API response times
   # CDN performance
   # DNS resolution issues

# Debugging Commands
# Network debugging
kubectl exec -it <pod> -- nslookup backend-service.sre-shop.svc.cluster.local
kubectl exec -it <pod> -- ping backend-service.sre-shop.svc.cluster.local

# Application performance
kubectl exec -it <pod> -- top
kubectl exec -it <pod> -- ps aux
kubectl exec -it <pod> -- netstat -tulpn
```

**Pattern 3: Pod Startup Issues**
```bash
# Common Startup Problems
Image pull failures:
├── Check image name and tag
├── Verify registry credentials
├── Check node disk space

Configuration errors:
├── Verify ConfigMap/Secret values
├── Check environment variable formatting
├── Validate file permissions

Resource constraints:
├── Insufficient CPU/memory requests
├── Node resource exhaustion
├── Pod security policy restrictions

Health check misconfigurations:
├── Probe timing too aggressive
├── Wrong probe endpoint/port
├── Application startup time longer than initialDelaySeconds

# Debugging Commands
kubectl describe pod <pod-name> -n <namespace>
kubectl events --sort-by=.metadata.creationTimestamp -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous
```

### **Performance Troubleshooting**

#### **Database Performance Issues**
```bash
# PostgreSQL Performance Debugging (if using)
1. Check connection pool status
   # Monitor active vs idle connections
   # Look for connection pool exhaustion

2. Analyze slow queries
   # Enable slow query logging
   # Review query execution plans
   # Check for missing indexes

3. Monitor lock contention
   # Check for long-running transactions
   # Look for deadlock patterns
   # Review transaction isolation levels

# MongoDB Performance Debugging (if using)
1. Check collection scan ratios
   # Look for high COLLSCAN operations
   # Verify index usage patterns

2. Monitor WiredTiger cache
   # Check cache hit ratios
   # Monitor cache eviction rates

3. Review connection patterns
   # Check for connection leaks
   # Monitor connection churn
```

#### **Application Memory Issues**
```bash
# Memory Leak Detection
1. Monitor memory trends over time
   container_memory_usage_bytes
   container_memory_working_set_bytes

2. Analyze garbage collection patterns (JVM)
   jvm_gc_collection_seconds_total
   jvm_memory_bytes_used{area="heap"}

3. Check for memory fragmentation
   # Review memory allocation patterns
   # Look for large object allocations

# Memory Optimization Steps
1. Tune JVM heap sizes (Java applications)
   -Xms512m -Xmx1024m
   # Set initial and maximum heap sizes

2. Enable garbage collection logging
   -XX:+PrintGC -XX:+PrintGCDetails
   # Monitor GC frequency and duration

3. Use memory profiling tools
   # Java: JProfiler, YourKit, async-profiler
   # Go: pprof
   # Python: memory_profiler
```

---

## 📊 **Monitoring and Alerting Management**

### **Alert Management Procedures**

#### **Alert Lifecycle Management**
```bash
# Daily Alert Review (10 minutes)
1. Check AlertManager web UI
   http://your-alertmanager-url:9093

2. Review firing alerts
   # Categorize: actionable vs informational
   # Verify appropriate escalation

3. Analyze resolved alerts
   # Check resolution time (MTTR)
   # Look for recurring patterns

4. Update alert documentation
   # Add runbook links to new alerts
   # Improve unclear alert descriptions

# Weekly Alert Tuning (30 minutes)
1. False positive analysis
   # Calculate false positive rate per alert
   # Tune thresholds for alerts with >5% false positive rate

2. Alert fatigue assessment
   # Count alerts per week per team member
   # Target: <10 actionable alerts per person per week

3. Coverage gap analysis
   # Review incidents without preceding alerts
   # Add new alerts for discovered failure modes

# Monthly Alert Strategy Review
1. Business impact correlation
   # Which alerts correlate with customer issues?
   # Prioritize these alerts for fastest response

2. Alert hierarchy optimization
   # Ensure symptom-based alerts fire before cause-based
   # Implement alert dependencies to reduce noise
```

#### **Alert Configuration Examples**
```yaml
# High-Priority Alerts (Page immediately)
groups:
- name: slo_violations
  rules:
  - alert: HighErrorRate
    expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.01
    for: 5m
    labels:
      severity: critical
      service: backend
    annotations:
      summary: "High error rate detected"
      description: "Error rate is {{ $value | humanizePercentage }} for the last 5 minutes"
      runbook_url: "https://wiki.company.com/runbooks/high-error-rate"

  - alert: HighLatency
    expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 0.2
    for: 10m
    labels:
      severity: warning
      service: backend
    annotations:
      summary: "High latency detected"
      description: "95th percentile latency is {{ $value }}s"
      runbook_url: "https://wiki.company.com/runbooks/high-latency"

# Medium-Priority Alerts (Slack notification)
- name: resource_exhaustion
  rules:
  - alert: HighCPUUsage
    expr: avg(rate(container_cpu_usage_seconds_total[5m])) by (pod) > 0.8
    for: 15m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage on {{ $labels.pod }}"
      description: "CPU usage is {{ $value | humanizePercentage }}"

  - alert: HighMemoryUsage
    expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "High memory usage on {{ $labels.pod }}"
      description: "Memory usage is {{ $value | humanizePercentage }}"
```

### **Dashboard Management**

#### **Dashboard Lifecycle**
```bash
# Monthly Dashboard Review
1. Usage analytics
   # Check Grafana usage statistics
   # Identify unused or rarely used dashboards

2. Performance optimization
   # Review slow-loading panels
   # Optimize expensive queries with recording rules

3. Content relevance
   # Remove deprecated metrics
   # Add new metrics for recent service additions

4. User feedback incorporation
   # Survey team members on dashboard usefulness
   # Implement requested improvements

# Dashboard Version Control
1. Export dashboards as JSON
   # Use Grafana API or UI export function
   
2. Store in Git repository
   # Maintain version history
   # Enable peer review of changes

3. Automated deployment
   # Use GitOps to deploy dashboard changes
   # Test in staging before production
```

---

## 🎯 **Continuous Improvement**

### **Monthly Operational Review**

#### **SRE Metrics Review**
```bash
# Key SRE Metrics to Track
1. Service Level Indicators
   # Availability: 99.9% target
   # Error rate: <0.1% target
   # Latency: 95th percentile <200ms target

2. Operational Metrics
   # MTTR (Mean Time To Recovery): Target <30 minutes
   # MTBF (Mean Time Between Failures): Track trends
   # Change failure rate: Target <5%

3. Team Efficiency Metrics
   # Toil reduction: Automate repetitive tasks
   # Alert noise: Target <10 actionable alerts/week per person
   # On-call load: Target <2 hours per week per person

# Monthly Review Process
1. Data collection
   # Export metrics from monitoring systems
   # Gather incident reports and post-mortems

2. Trend analysis
   # Compare with previous months
   # Identify improving and degrading trends

3. Action planning
   # Prioritize improvement initiatives
   # Assign owners and deadlines
```

#### **Capacity Planning Review**
```bash
# Growth Projection Analysis
1. Traffic growth trends
   # Analyze request rate increases
   # Project future capacity needs

2. Resource utilization trends
   # CPU, memory, storage growth patterns
   # Identify components approaching limits

3. Cost optimization opportunities
   # Right-size over-provisioned resources
   # Identify reserved instance opportunities

# Quarterly Capacity Planning
1. 6-month growth projections
   # Based on business forecasts and historical trends
   
2. Infrastructure scaling plan
   # Node group scaling parameters
   # Database scaling strategy
   
3. Budget planning
   # Infrastructure cost projections
   # ROI analysis for optimization initiatives
```

### **Knowledge Management**

#### **Documentation Maintenance**
```bash
# Quarterly Documentation Review
1. Accuracy verification
   # Test all procedures against current environment
   # Update outdated screenshots and examples

2. Gap identification
   # Survey team for missing documentation
   # Prioritize high-impact knowledge gaps

3. Accessibility improvement
   # Simplify complex procedures
   # Add visual aids and flowcharts

# Knowledge Sharing Initiatives
1. Monthly tech talks
   # Team members present on new technologies
   # Share lessons learned from incidents

2. Runbook improvements
   # Add more decision trees
   # Include common troubleshooting scenarios

3. Cross-training programs
   # Ensure multiple people know critical procedures
   # Reduce single points of failure
```

---

## 🚨 **Emergency Procedures**

### **Disaster Recovery Activation**

#### **Critical Incident Response**
```bash
# Severity 1: Complete Service Outage
Immediate Actions (0-15 minutes):
1. Acknowledge incident in monitoring system
2. Post initial status update
3. Assemble incident response team
4. Begin impact assessment

Investigation Phase (15-60 minutes):
1. Check infrastructure status
   # AWS service status
   # EKS cluster health
   # Network connectivity

2. Review recent changes
   # Deployments in last 24 hours
   # Infrastructure modifications
   # Configuration changes

3. Implement immediate mitigation
   # Rollback recent deployments
   # Scale up resources if needed
   # Activate backup systems

Recovery Phase (1-4 hours):
1. Implement permanent fix
2. Verify service restoration
3. Monitor for stability
4. Communicate resolution

Post-Incident (24-48 hours):
1. Conduct blameless post-mortem
2. Document lessons learned
3. Implement preventive measures
4. Update runbooks and procedures
```

#### **Data Loss Prevention**
```bash
# Before Making Risky Changes
1. Create point-in-time snapshots
   # Database snapshots
   # EBS volume snapshots
   # Kubernetes resource backups

2. Verify backup integrity
   # Test restore procedures
   # Validate backup completeness

3. Communicate change window
   # Notify stakeholders
   # Update status page

# If Data Loss Occurs
1. Stop all write operations immediately
2. Assess scope of data loss
3. Begin recovery from most recent backup
4. Implement additional monitoring
5. Conduct thorough post-mortem
```

---

## 📋 **Checklists and Templates**

### **New Service Onboarding**
```bash
# Pre-Deployment Checklist
□ Service health endpoints implemented (/healthz, /readyz)
□ Prometheus metrics endpoint exposed (/metrics)
□ Resource requests and limits defined
□ Security context configured (non-root user)
□ ConfigMap/Secret dependencies created
□ Service monitor configured for Prometheus
□ Grafana dashboard created
□ Alerting rules defined
□ Runbook documentation created
□ Load testing completed
□ Disaster recovery plan documented

# Post-Deployment Verification
□ Pods start successfully
□ Health checks pass
□ Metrics are collected by Prometheus
□ Alerts are functional (test with threshold breach)
□ Dashboard shows expected data
□ Service discovery works correctly
□ Load balancer routing configured
□ Monitoring baseline established
□ Team trained on new service operations
```

### **Change Management Template**
```bash
# Change Request Template
Change ID: CR-YYYY-MM-DD-###
Requestor: [Name]
Implementation Date: [Date/Time]
Duration: [Expected downtime]
Rollback Plan: [Detailed steps]

# Pre-Change Checklist
□ Change tested in staging environment
□ Rollback plan tested and verified
□ Stakeholders notified of maintenance window
□ Backup of current state completed
□ Monitoring alerts configured for change validation
□ Team availability confirmed for duration + 2 hours

# Change Implementation Steps
1. [Detailed step-by-step procedure]
2. [Include verification commands]
3. [Note any expected temporary impacts]

# Post-Change Validation
□ All services operational
□ SLI metrics within normal ranges
□ No increase in error rates
□ Performance metrics stable
□ User acceptance testing passed
□ Monitoring baseline updated if needed

# Rollback Triggers
- Error rate increases >2x baseline
- Latency increases >50% from baseline  
- Any critical functionality unavailable
- User-reported issues increase significantly
```

This operational procedures guide provides the foundation for reliable day-to-day operations of your SRE Lab Infrastructure. Regular execution of these procedures will ensure high availability, security, and performance of your monitoring and application stack.

🎯 **Remember:** Operational excellence comes from consistent execution of well-defined procedures, continuous improvement, and learning from every incident and maintenance activity.