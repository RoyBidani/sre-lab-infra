# 🏗️ SRE Lab Technology Deep Dive

This guide explains **why** we chose each technology and **how** they work together to create a production-grade SRE training environment.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Infrastructure Layer](#infrastructure-layer)
- [Container Orchestration](#container-orchestration)
- [Monitoring Stack](#monitoring-stack)
- [SRE Practices](#sre-practices)
- [Security & Networking](#security--networking)
- [Cost Optimization](#cost-optimization)

## 🎯 Architecture Overview

### Design Principles

Our architecture follows these SRE principles:

1. **Observability First**: Every component produces telemetry data
2. **Fault Tolerance**: System continues functioning despite component failures
3. **Scalability**: Can handle increased load without redesign
4. **Security**: Defense in depth with least privilege access
5. **Cost Efficiency**: Balanced performance vs. operational costs

### Technology Stack Decision Matrix

| Component | Choice | Alternatives | Why We Chose It |
|-----------|--------|-------------|-----------------|
| **Cloud Provider** | AWS | GCP, Azure | Largest market share, extensive EKS support |
| **Container Orchestration** | Kubernetes (EKS) | Docker Swarm, Nomad | Industry standard, rich ecosystem |
| **Infrastructure as Code** | Terraform | CloudFormation, Pulumi | Cloud-agnostic, mature, great AWS support |
| **Monitoring** | Prometheus | DataDog, New Relic | Open source, Kubernetes-native, PromQL |
| **Visualization** | Grafana | Kibana, Tableau | Best-in-class dashboards, Prometheus integration |
| **Alerting** | AlertManager | PagerDuty, OpsGenie | Native Prometheus integration, flexible routing |
| **Chaos Testing** | Custom Chaos Monkey | Chaos Toolkit, Litmus | Educational value, simple implementation |

## 🏢 Infrastructure Layer

### AWS EKS (Elastic Kubernetes Service)

**Why EKS over self-managed Kubernetes?**

1. **Managed Control Plane**: AWS handles etcd, API server, scheduler
2. **High Availability**: Multi-AZ control plane by default
3. **Security**: AWS manages security patches and upgrades
4. **Integration**: Native AWS service integration (IAM, VPC, LoadBalancers)

**Trade-offs:**
- ✅ **Pros**: Reduced operational overhead, better security, automatic updates
- ❌ **Cons**: Higher cost ($0.10/hour), less control over control plane, AWS lock-in

### VPC Architecture

```
Internet Gateway (IGW)
       │
   ┌───▼───┐                    ┌─────────┐
   │Public │                    │ Private │
   │Subnet │                    │ Subnet  │
   │10.0.1.0/24 ◄──────────────► 10.0.2.0/24
   │       │                    │         │
   │ALB    │                    │EKS Nodes│
   │NAT GW │                    │         │
   └───────┘                    └─────────┘
       │                            │
   ┌───▼───┐                    ┌─────────┐
   │Public │                    │ Private │
   │Subnet │                    │ Subnet  │
   │10.0.3.0/24 ◄──────────────► 10.0.4.0/24
   │       │                    │         │
   │ALB    │                    │EKS Nodes│
   │NAT GW │                    │         │
   └───────┘                    └─────────┘
```

**Why this network design?**

1. **Security**: Worker nodes have no direct internet access
2. **High Availability**: Resources span 2 Availability Zones
3. **Scalability**: /16 CIDR provides 65,536 IP addresses
4. **Best Practice**: Follows AWS Well-Architected Framework

**Component Breakdown:**

- **Internet Gateway**: Enables internet access for public subnets
- **NAT Gateways**: Allow private subnet outbound internet access
- **Public Subnets**: Host load balancers and NAT gateways
- **Private Subnets**: Host application workloads and databases

### EC2 Instance Selection

**t3.medium (2 vCPU, 4GB RAM)**

**Why t3.medium?**

1. **Burstable Performance**: Good for variable workloads
2. **Cost Effective**: Balance between performance and cost
3. **Right-sized**: Sufficient for demo applications and monitoring
4. **EBS Optimized**: Better storage performance

**Performance Characteristics:**
- **Baseline CPU**: 20% of vCPU
- **CPU Credits**: Burst to 100% when needed
- **Network**: Up to 5 Gbps
- **Memory**: 4 GB (sufficient for typical containers)

## ⚙️ Container Orchestration

### Kubernetes Components

#### Why Kubernetes?

1. **Industry Standard**: Used by 90% of container-orchestrated workloads
2. **Ecosystem**: Vast ecosystem of tools and integrations
3. **Declarative**: Desired state configuration
4. **Self-healing**: Automatic restart, replacement, and rescheduling
5. **Horizontal Scaling**: Built-in autoscaling capabilities

#### Key Kubernetes Concepts

**Namespaces**: Logical Isolation
```yaml
# Provides multi-tenancy within single cluster
apiVersion: v1
kind: Namespace
metadata:
  name: sre-shop
```

**Deployments**: Application Management
```yaml
# Manages pod replicas, rolling updates, rollbacks
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

**Services**: Network Abstraction
```yaml
# Provides stable networking for ephemeral pods
apiVersion: v1
kind: Service
spec:
  type: LoadBalancer  # Creates AWS Application Load Balancer
  selector:
    app: backend-api
```

#### Resource Management

**Resource Requests vs Limits**
```yaml
resources:
  requests:     # Guaranteed resources (scheduling)
    memory: "64Mi"
    cpu: "50m"
  limits:       # Maximum allowed (throttling)
    memory: "128Mi"
    cpu: "100m"
```

**Why this matters:**
- **Requests**: Kubernetes uses for scheduling decisions
- **Limits**: Prevents resource exhaustion and noisy neighbor issues
- **Quality of Service**: Determines pod eviction priority

## 📊 Monitoring Stack

### Prometheus Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Targets   │    │ Prometheus  │    │   Grafana   │
│ (Services)  │───►│   Server    │───►│ Dashboards │
│             │    │             │    │             │
└─────────────┘    └─────────────┘    └─────────────┘
                           │
                           ▼
                   ┌─────────────┐
                   │AlertManager │
                   │   Rules     │
                   └─────────────┘
```

#### Why Prometheus?

1. **Pull-based Model**: Simplifies service discovery and reduces coupling
2. **Time Series Database**: Optimized for time-stamped data
3. **PromQL**: Powerful query language for aggregations and calculations
4. **Kubernetes Native**: Built-in service discovery for Kubernetes
5. **Dimensionality**: Labels provide flexible data organization

**Pull vs Push Models:**

| Aspect | Pull (Prometheus) | Push (StatsD) |
|--------|------------------|---------------|
| **Service Discovery** | Automatic | Manual configuration |
| **Network** | Prometheus connects to targets | Targets connect to collector |
| **Reliability** | Missing scrapes are detectable | Fire-and-forget (data loss possible) |
| **Security** | Targets expose metrics endpoint | Requires network access to collector |

#### Prometheus Configuration

**Service Discovery**
```yaml
kubernetes_sd_configs:
- role: pod
  namespaces:
    names:
    - sre-shop
relabel_configs:
- source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
  action: keep
  regex: true
```

**Recording Rules** (SLO Calculations)
```yaml
- record: sre_shop:availability_sli:rate5m
  expr: |
    (
      sum(rate(up{job="sre-shop-backend"}[5m])) /
      count(up{job="sre-shop-backend"})
    )
```

### Grafana Dashboards

#### Why Grafana?

1. **Visualization**: Rich charting capabilities
2. **Templating**: Dynamic dashboards with variables
3. **Alerting**: Visual alert management
4. **Plugins**: Extensive plugin ecosystem
5. **Multi-datasource**: Can query multiple data sources

#### Dashboard Design Principles

1. **Golden Signals**: Focus on latency, traffic, errors, saturation
2. **Hierarchy**: High-level overview → detailed views
3. **Correlation**: Show related metrics together
4. **Actionability**: Every chart should inform decisions

## 🎯 SRE Practices

### Service Level Objectives (SLOs)

#### SLO Mathematics

**Error Budget Calculation**
```
Error Budget = (1 - SLO) × Time Window
Example: 99.9% SLO = 0.1% × 30 days = 43.2 minutes/month
```

**Burn Rate**
```
Burn Rate = Error Rate / Error Budget Rate
Fast Burn: >14.4× (exhaust budget in 2 hours)
Slow Burn: >1× (exhaust budget by month end)
```

#### Implementation Strategy

**1. Availability SLO (99.9%)**
```promql
# SLI: Successful HTTP requests / Total HTTP requests
sre_shop:availability_sli:rate5m = (
  sum(rate(up{job="sre-shop-backend"}[5m])) /
  count(up{job="sre-shop-backend"})
)

# Alert when SLO is violated
- alert: AvailabilitySLOViolation
  expr: sre_shop:availability_sli:rate5m < 0.999
  for: 5m
```

**2. Error Rate SLO (<0.1%)**
```promql
# SLI: Non-error responses / Total responses
sre_shop:error_rate_sli:rate5m = (
  1 - (
    sum(rate(http_requests_total{status=~"5.."}[5m])) /
    sum(rate(http_requests_total[5m]))
  )
)
```

**3. Latency SLO (<500ms P95)**
```promql
# SLI: 95th percentile response time
sre_shop:latency_sli:p95_5m = 
  histogram_quantile(0.95, rate(response_time_bucket[5m]))
```

### Chaos Engineering

#### Why Chaos Engineering?

1. **Proactive**: Find failures before users do
2. **Confidence**: Verify system resilience
3. **Learning**: Understand system behavior under stress
4. **Preparedness**: Practice incident response

#### Chaos Monkey Implementation

```bash
# Pod Termination (5% probability every 5 minutes)
while true; do
  RANDOM_NUM=$((RANDOM % 100))
  if [ $RANDOM_NUM -lt 5 ]; then
    kubectl delete pod -l app=backend-api -n sre-shop --force
    echo "🐒 Chaos Monkey killed a backend pod!"
  fi
  sleep 300
done
```

**Why 5% probability?**
- **Low Impact**: Doesn't overwhelm system
- **Regular Testing**: Frequent enough to matter
- **Realistic**: Similar to real-world failure rates

## 🔐 Security & Networking

### Defense in Depth

```
┌─────────────┐
│   Internet  │
└──────┬──────┘
       │ HTTPS/TLS
┌──────▼──────┐
│     ALB     │ ◄── Web Application Firewall
└──────┬──────┘
       │ Internal Network
┌──────▼──────┐
│  Frontend   │ ◄── Network Policies
└──────┬──────┘
       │ Service Mesh (future)
┌──────▼──────┐
│   Backend   │ ◄── RBAC, Pod Security
└──────┬──────┘
       │ Encrypted Transit
┌──────▼──────┐
│  Database   │ ◄── Encryption at Rest
└─────────────┘
```

#### Security Layers

1. **Network Security**
   - Private subnets for worker nodes
   - Security groups with least privilege
   - Network policies for pod-to-pod communication

2. **Identity & Access Management**
   - IAM roles for service accounts
   - RBAC for Kubernetes permissions
   - Pod security standards

3. **Data Protection**
   - TLS for data in transit
   - EBS encryption for data at rest
   - Secrets management with Kubernetes secrets

### IAM Integration

**EKS Access Entry Pattern**
```json
{
  "principalArn": "arn:aws:iam::123456789012:user/admin",
  "type": "STANDARD",
  "accessPolicy": {
    "type": "AmazonEKSClusterAdminPolicy"
  }
}
```

**Why Access Entries vs ConfigMap?**
- ✅ **Auditable**: AWS CloudTrail logging
- ✅ **Secure**: No direct cluster access needed
- ✅ **Scalable**: Programmatic management
- ✅ **Integrated**: Native AWS IAM integration

## 💰 Cost Optimization

### Cost Breakdown (Monthly Estimates)

| Component | Cost | Optimization Strategy |
|-----------|------|----------------------|
| **EKS Control Plane** | $72 | Can't optimize (fixed AWS cost) |
| **EC2 Instances** | $60 | Use Spot instances (-70%) |
| **Load Balancers** | $36 | Consolidate services |
| **NAT Gateways** | $90 | Use NAT instances for dev |
| **EBS Storage** | $10 | Use gp3 instead of gp2 |
| **Data Transfer** | $15 | Minimize cross-AZ traffic |
| **Total** | **$283** | **Optimized: ~$140** |

### Optimization Strategies

**1. Spot Instances**
```terraform
eks_managed_node_groups = {
  spot = {
    capacity_type  = "SPOT"
    instance_types = ["t3.medium", "t3.large", "t2.medium"]
    desired_size   = 2
    max_size       = 4
    min_size       = 1
  }
}
```

**2. Resource Right-sizing**
```yaml
resources:
  requests:
    memory: "64Mi"   # Start small
    cpu: "50m"       # 0.05 CPU cores
  limits:
    memory: "128Mi"  # Prevent OOM
    cpu: "100m"      # Allow burst
```

**3. Horizontal Pod Autoscaling**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  minReplicas: 1    # Scale down when idle
  maxReplicas: 10   # Scale up under load
  targetCPUUtilizationPercentage: 70
```

## 🚀 Scalability Considerations

### Vertical vs Horizontal Scaling

| Approach | When to Use | Benefits | Limitations |
|----------|-------------|----------|-------------|
| **Vertical** | Stateful services, databases | Simple, no architecture changes | Single point of failure, limited by instance size |
| **Horizontal** | Stateless services, APIs | Better fault tolerance, unlimited scale | Complexity, state management challenges |

### Auto-scaling Architecture

```
Load Increase
     │
     ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│    HPA      │───►│   Nodes     │───►│   Cluster   │
│ (Pods: 2→5) │    │ (EC2: 2→4)  │    │ (Add nodes) │
└─────────────┘    └─────────────┘    └─────────────┘
     │                      │                  │
     ▼                      ▼                  ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Pod Metrics │    │Node Metrics │    │   Limits    │
│ CPU > 70%   │    │CPU > 80%    │    │ Max: 10 AZs │
└─────────────┘    └─────────────┘    └─────────────┘
```

## 🔧 Troubleshooting Decision Tree

```
Problem Detected
       │
       ▼
┌─────────────┐
│ Check Pods  │ ── Pending? ─── Resource Constraints
│ kubectl get │                 └─ Scale up nodes
│ pods -A     │
└─────┬───────┘
      │ Running
      ▼
┌─────────────┐
│Check Service│ ── No Endpoints ─── Label Mismatch
│ kubectl get │                     └─ Fix selectors
│ endpoints   │
└─────┬───────┘
      │ Has Endpoints
      ▼
┌─────────────┐
│Check Metrics│ ── No Data ─────── Scrape Config
│Prometheus UI│                   └─ Fix annotations
└─────┬───────┘
      │ Has Data
      ▼
┌─────────────┐
│ Application │ ── 5xx Errors ──── App Logs
│   Level     │                   └─ Debug code
└─────────────┘
```

## 📈 Monitoring Best Practices

### The Four Golden Signals

1. **Latency**: Time to process requests
   ```promql
   histogram_quantile(0.95, 
     rate(http_request_duration_seconds_bucket[5m])
   )
   ```

2. **Traffic**: Demand on your system
   ```promql
   sum(rate(http_requests_total[5m]))
   ```

3. **Errors**: Rate of failed requests
   ```promql
   sum(rate(http_requests_total{status=~"5.."}[5m])) /
   sum(rate(http_requests_total[5m]))
   ```

4. **Saturation**: How "full" your service is
   ```promql
   avg(cpu_usage_percent) > 80
   ```

### Alert Design Philosophy

**Alert Fatigue Prevention:**
1. **Only alert on user-impacting issues**
2. **Make alerts actionable**
3. **Use appropriate severity levels**
4. **Implement alert suppression during maintenance**

**Alert Hierarchy:**
```
Critical (Page immediately)
    ├─ Service Down (SLO violation)
    ├─ Error Budget Exhausted
    └─ Security Incident

Warning (Review during business hours)
    ├─ High Latency (approaching SLO)
    ├─ Resource Utilization (>80%)
    └─ Failed Deployments

Info (Logging/metrics only)
    ├─ Successful Deployments
    ├─ Routine Maintenance
    └─ Normal Scaling Events
```

---

## 🎓 Conclusion

This technology stack provides:

1. **Production Readiness**: Enterprise-grade components used by major tech companies
2. **Learning Value**: Hands-on experience with industry-standard tools
3. **Scalability**: Can grow from demo to production workloads
4. **Cost Effectiveness**: Balanced price/performance for learning environment
5. **Career Relevance**: Skills directly applicable to SRE roles

The architecture demonstrates real-world SRE practices while remaining accessible for learning and experimentation. Each technology choice was made to balance educational value, practical utility, and operational simplicity.

**Next Steps:**
- Deploy the environment using the setup guides
- Experiment with configuration changes
- Practice incident response scenarios
- Explore advanced features and integrations

Happy learning! 🚀