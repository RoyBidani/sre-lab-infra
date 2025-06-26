# 🚀 Complete SRE Training Environment

A comprehensive, hands-on Site Reliability Engineering (SRE) training platform built on AWS EKS with Kubernetes, featuring real-world SRE practices including SLO monitoring, alerting, chaos engineering, and incident response.

## 📋 Table of Contents

- [Overview](#overview)
- [What You'll Build](#what-youll-build)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Step-by-Step Setup](#step-by-step-setup)
- [Understanding Your Environment](#understanding-your-environment)
- [Testing and Verification](#testing-and-verification)
- [Learning Exercises](#learning-exercises)
- [Troubleshooting](#troubleshooting)
- [Advanced Topics](#advanced-topics)
- [Cleanup](#cleanup)

## 🎯 Overview

This project creates a production-grade SRE training environment where you'll learn:

- **Infrastructure as Code** with Terraform
- **Container orchestration** with Kubernetes (EKS)
- **Observability** with Prometheus and Grafana
- **SLO/SLI monitoring** and error budget management
- **Incident response** and chaos engineering
- **Real-world SRE practices** used by tech giants

### Why This Architecture?

We chose this specific technology stack because:

1. **AWS EKS**: Managed Kubernetes reduces operational overhead while teaching K8s concepts
2. **Terraform**: Industry-standard IaC tool with extensive AWS support
3. **Prometheus**: De facto standard for Kubernetes monitoring with powerful query language
4. **Grafana**: Best-in-class visualization with extensive community dashboards
5. **Chaos Engineering**: Essential for building resilient systems

## 🏗️ What You'll Build

### Infrastructure Components

- **AWS VPC** with public/private subnets across 2 AZs
- **EKS Cluster** with managed node groups (2 t3.medium instances)
- **Application Load Balancers** for external access
- **NAT Gateways** for private subnet internet access
- **Security Groups** and IAM roles for least privilege access

### Application Stack

- **3-tier SRE Shop application** (Frontend, Backend, Database)
- **Nginx frontend** with custom SRE interface
- **HTTP Echo backend** with health endpoints
- **Redis database** for session storage

### Monitoring & SRE Stack

- **Prometheus** for metrics collection and alerting rules
- **Grafana** with custom SLO dashboards
- **AlertManager** for intelligent alert routing
- **Chaos Monkey** for automated resilience testing
- **SLO monitoring** with error budget tracking
- **Incident response runbooks** for common scenarios

## ✅ Prerequisites

### Required Tools

```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### AWS Account Setup

1. **AWS Account** with administrative privileges
2. **AWS CLI configured** with access keys
3. **Sufficient limits** for:
   - 2 t3.medium EC2 instances
   - 2 Application Load Balancers
   - 2 NAT Gateways
   - 2 Elastic IPs

### Verify Prerequisites

```bash
# Test AWS access
aws sts get-caller-identity

# Test Terraform
terraform version

# Test kubectl
kubectl version --client
```

## 🏛️ Architecture

### Network Architecture

```
Internet Gateway
       |
   Public Subnets (10.0.1.0/24, 10.0.3.0/24)
       |
   Load Balancers & NAT Gateways
       |
   Private Subnets (10.0.2.0/24, 10.0.4.0/24)
       |
   EKS Worker Nodes
```

### Application Architecture

```
Internet → ALB → Frontend (Nginx) → Backend (HTTP Echo) → Redis
                     ↓
                Prometheus ← Metrics
                     ↓
                 Grafana ← Visualization
                     ↓
               AlertManager ← Notifications
```

### Why This Architecture?

1. **Security**: Worker nodes in private subnets with no direct internet access
2. **High Availability**: Resources spread across multiple AZs
3. **Scalability**: Managed node groups can auto-scale based on demand
4. **Observability**: Comprehensive monitoring from infrastructure to application
5. **Resilience**: Chaos engineering tests failure scenarios

## 📖 Step-by-Step Setup

### Phase 1: Infrastructure Deployment

#### Step 1: Clone and Prepare

```bash
git clone <your-repo-url>
cd sre-lab-infra
```

#### Step 2: Configure Terraform Variables

The infrastructure uses sensible defaults, but you can customize:

```bash
# terraform/variables.tf contains:
# - aws_region = "eu-central-1"
# - vpc_cidr = "10.0.0.0/16" 
# - public_subnets = ["10.0.1.0/24", "10.0.3.0/24"]
# - private_subnets = ["10.0.2.0/24", "10.0.4.0/24"]
# - cluster_name = "sre-lab-eks"
```

**Why these defaults?**

- **eu-central-1**: Cost-effective region with good availability
- **10.0.0.0/16**: Provides 65,536 IPs for future expansion
- **Separate AZs**: Ensures high availability
- **Public/Private split**: Security best practice

#### Step 3: Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

**What happens here:**

1. **VPC Creation**: Isolated network environment
2. **Subnet Creation**: Public for load balancers, private for applications
3. **Gateway Setup**: Internet and NAT gateways for connectivity
4. **EKS Cluster**: Managed Kubernetes control plane
5. **Node Groups**: EC2 instances joined to the cluster

**This takes 10-15 minutes** because:

- EKS control plane provisioning: ~10 minutes
- Node group creation: ~5 minutes
- DNS propagation: ~2 minutes

#### Step 4: Configure kubectl

```bash
aws eks update-kubeconfig --region eu-central-1 --name sre-lab-eks
kubectl get nodes
```

**Troubleshooting Access Issues:**
If you get authentication errors:

1. **Check IAM permissions**: User needs `AmazonEKSClusterAdminPolicy`
2. **Add to EKS access**: Go to AWS Console → EKS → Cluster → Access → Add IAM user
3. **Verify AWS CLI**: `aws sts get-caller-identity`

### Phase 2: Application Deployment

#### Step 5: Deploy the SRE Shop Application

```bash
# Deploy application components
kubectl apply -f k8s-manifests/app/namespace.yaml
kubectl apply -f k8s-manifests/app/redis.yaml
kubectl apply -f k8s-manifests/app/backend.yaml
kubectl apply -f k8s-manifests/app/frontend.yaml
```

**Understanding the Application:**

1. **Namespace**: Logical isolation within the cluster
   
   ```yaml
   apiVersion: v1
   kind: Namespace
   metadata:
     name: sre-shop
   ```

2. **Redis Database**: Key-value store for session data
   
   - **Why Redis?** Fast, reliable, commonly used in microservices
   - **Configuration**: Single instance with persistent volume
   - **Monitoring**: Health checks and resource limits

3. **Backend API**: HTTP echo service
   
   - **Why HTTP Echo?** Simple, predictable responses for testing
   - **Features**: Health endpoints, JSON responses, environment info
   - **Scaling**: 2 replicas for redundancy

4. **Frontend**: Nginx reverse proxy
   
   - **Why Nginx?** Industry standard, efficient, configurable
   - **Role**: Serves static content and proxies API calls
   - **Configuration**: Custom HTML with SRE interface

#### Step 6: Verify Application Deployment

```bash
# Check pod status
kubectl get pods -n sre-shop

# Expected output:
# NAME                           READY   STATUS    RESTARTS   AGE
# backend-api-xxx                1/1     Running   0          2m
# frontend-xxx                   1/1     Running   0          2m
# redis-xxx                      1/1     Running   0          2m

# Get application URL
kubectl get services -n sre-shop
```

### Phase 3: Monitoring Stack

#### Step 7: Deploy Monitoring Infrastructure

```bash
# Deploy monitoring namespace and RBAC
kubectl apply -f k8s-manifests/monitoring/namespace.yaml
kubectl apply -f k8s-manifests/monitoring/prometheus-rbac.yaml

# Deploy Prometheus
kubectl apply -f k8s-manifests/monitoring/prometheus-configmap.yaml
kubectl apply -f k8s-manifests/monitoring/prometheus-deployment.yaml

# Deploy Grafana
kubectl apply -f k8s-manifests/monitoring/grafana-configmap.yaml
kubectl apply -f k8s-manifests/monitoring/grafana-deployment.yaml
```

**Understanding Prometheus Configuration:**

1. **Service Discovery**: Automatically finds Kubernetes services
   
   ```yaml
   kubernetes_sd_configs:
   - role: pod
   ```

2. **Scrape Configs**: Defines what metrics to collect
   
   ```yaml
   - job_name: 'sre-shop-backend'
     kubernetes_sd_configs:
     - role: pod
   ```

3. **Alerting Rules**: Conditions that trigger alerts
   
   ```yaml
   - alert: HighErrorRate
     expr: rate(errors[5m]) > 0.1
   ```

**Why This Monitoring Stack?**

- **Prometheus**: Pull-based metrics, powerful query language (PromQL)
- **Grafana**: Rich visualizations, templating, alerting
- **Integration**: Purpose-built for Kubernetes environments

### Phase 4: SRE Practices Implementation

#### Step 8: Deploy SLO Monitoring

```bash
./scripts/deploy-sre-practices.sh
```

This comprehensive script:

1. **Deploys SLO definitions** and recording rules
2. **Sets up alerting** based on SLO violations
3. **Installs chaos engineering** tools
4. **Configures dashboards** for SLO visualization

**Understanding SLOs (Service Level Objectives):**

SLOs define reliability targets for your service:

1. **Availability SLO**: 99.9% uptime
   
   ```promql
   sre_shop:availability_sli:rate5m = (
     sum(rate(up{job="sre-shop-backend"}[5m])) /
     count(up{job="sre-shop-backend"})
   )
   ```

2. **Error Rate SLO**: < 0.1% error rate
   
   ```promql
   sre_shop:error_rate_sli:rate5m = (
     1 - rate(http_requests_total{status=~"5.."}[5m]) /
     rate(http_requests_total[5m])
   )
   ```

3. **Latency SLO**: < 500ms P95 response time
   
   ```promql
   sre_shop:latency_sli:p95_5m = 
     histogram_quantile(0.95, rate(response_time_bucket[5m]))
   ```

**Error Budget Calculation:**

- **Error Budget** = (1 - SLO) × Time Window
- **Example**: 99.9% SLO = 0.1% error budget = 43.2 minutes/month downtime

## 🔍 Understanding Your Environment

### What Runs Where?

#### **EKS Control Plane** (AWS Managed)

- **Location**: AWS-managed, multi-AZ
- **Purpose**: Kubernetes API server, etcd, scheduler
- **Access**: Via kubectl and AWS console
- **Cost**: $0.10/hour for cluster management

#### **Worker Nodes** (Your EC2 Instances)

- **Instance Type**: t3.medium (2 vCPU, 4GB RAM)
- **Count**: 2 instances across different AZs
- **Location**: Private subnets (10.0.2.0/24, 10.0.4.0/24)
- **Purpose**: Run your application pods

#### **Load Balancers** (AWS Managed)

- **Type**: Application Load Balancer (ALB)
- **Purpose**: Distribute traffic to application services
- **Location**: Public subnets
- **DNS**: Auto-generated AWS hostnames

### Kubernetes Components Explained

#### **Namespaces**: Logical Separation

```bash
kubectl get namespaces

# sre-shop: Your application
# monitoring: Prometheus, Grafana
# kube-system: Kubernetes core components
# default: Default namespace (unused)
```

#### **Pods**: Smallest Deployable Units

```bash
kubectl get pods -n sre-shop

# Each pod contains one or more containers
# Pods are ephemeral - they come and go
# Pod IP addresses change when recreated
```

#### **Services**: Stable Network Endpoints

```bash
kubectl get services -n sre-shop

# ClusterIP: Internal cluster communication
# LoadBalancer: External internet access
# Services provide stable IPs and DNS names
```

#### **Deployments**: Manage Pod Replicas

```bash
kubectl get deployments -n sre-shop

# Deployment manages ReplicaSets
# ReplicaSets manage Pods
# Provides rolling updates and rollbacks
```

### How to Identify and Check Components

#### **Check Cluster Health**

```bash
# Overall cluster status
kubectl cluster-info

# Node health and capacity
kubectl describe nodes

# Resource usage
kubectl top nodes
kubectl top pods -n sre-shop
```

#### **Identify Node Roles**

```bash
# List nodes with labels
kubectl get nodes --show-labels

# Each node will show:
# - kubernetes.io/arch=amd64
# - kubernetes.io/instance-type=t3.medium
# - topology.kubernetes.io/zone=eu-central-1a
```

#### **Monitor Application Health**

```bash
# Pod status and restarts
kubectl get pods -n sre-shop -o wide

# Pod logs
kubectl logs <pod-name> -n sre-shop

# Pod events
kubectl describe pod <pod-name> -n sre-shop
```

#### **Check SLO Metrics**

```bash
# Port forward to Prometheus
kubectl port-forward -n monitoring service/prometheus-service 9090:9090

# In browser: http://localhost:9090
# Query: sre_shop:availability_sli:rate5m
```

#### **Monitor Chaos Engineering**

```bash
# Check Chaos Monkey status
kubectl get pods -n sre-shop -l app=chaos-monkey

# Watch chaos events
kubectl logs -f deployment/chaos-monkey -n sre-shop
```

### Understanding SLI/SLO in Practice

#### **Service Level Indicators (SLIs)**

Quantitative measures of service behavior:

1. **Availability SLI**
   
   - **Definition**: Percentage of successful requests
   - **Measurement**: HTTP 200 responses / Total HTTP requests
   - **Why Important**: Directly impacts user experience

2. **Latency SLI**
   
   - **Definition**: Time to respond to requests
   - **Measurement**: 95th percentile response time
   - **Why 95th**: Balances user experience with extreme outliers

3. **Saturation SLI**
   
   - **Definition**: Resource utilization levels
   - **Measurement**: CPU/Memory/Storage usage percentage
   - **Why Important**: Predicts capacity issues

#### **Service Level Objectives (SLOs)**

Targets for SLI performance:

1. **Setting SLOs**
   
   - **Too strict**: Expensive to maintain, limits innovation
   - **Too loose**: Poor user experience
   - **Best practice**: Start conservative, adjust based on data

2. **Error Budget**
   
   - **Concept**: Amount of failures allowed while meeting SLO
   - **Usage**: Balance between reliability and feature velocity
   - **Policy**: When error budget is exhausted, focus on stability

## 🧪 Testing and Verification

### Phase 1: Infrastructure Verification

```bash
# Run comprehensive verification
./scripts/verify-setup.sh

# Expected output:
# ✅ All pods running
# ✅ Services accessible
# ✅ Monitoring operational
```

### Phase 2: Generate Application Traffic

```bash
# Interactive traffic generation
./scripts/generate-traffic.sh

# Options available:
# 1. Light traffic (baseline monitoring)
# 2. Moderate traffic (realistic load)
# 3. Heavy traffic (stress testing)
# 4. Burst traffic (spike testing)
```

### Phase 3: Observe Monitoring Data

#### **Access Grafana Dashboards**

1. Get Grafana URL: `kubectl get service grafana -n monitoring`
2. Login: admin/admin
3. Navigate to "SRE Shop - SLO Dashboard"
4. Observe metrics populating (takes 5-10 minutes)

#### **Check Prometheus Metrics**

1. Get Prometheus URL: `kubectl get service prometheus-service -n monitoring`

2. Open Prometheus UI

3. Try these queries:
   
   ```promql
   # Service availability
   up{job="sre-shop-backend"}
   
   # SLO metrics
   sre_shop:availability_sli:rate5m
   
   # Error budget consumption
   (1 - avg_over_time(sre_shop:availability_sli:rate5m[7d])) / (1 - 0.999)
   ```

### Phase 4: Test Alerting

#### **Trigger SLO Violation**

```bash
# Scale down backend to trigger availability alert
kubectl scale deployment backend-api --replicas=0 -n sre-shop

# Continue generating traffic to trigger alerts
# Wait 5-10 minutes for alerts to fire

# Check AlertManager
kubectl get service alertmanager -n monitoring
# Open AlertManager UI to see active alerts

# Restore service
kubectl scale deployment backend-api --replicas=2 -n sre-shop
```

### Phase 5: Chaos Engineering

#### **Monitor Chaos Monkey**

```bash
# Watch chaos events in real-time
kubectl logs -f deployment/chaos-monkey -n sre-shop

# Expected output every 5 minutes:
# 🐒 Chaos Monkey Pod Killer started
# 🔍 Looking for victims...
# 🎲 Pod backend-api-xxx: random=94, threshold=5
# 🍀 Pod backend-api-xxx survives this round
```

#### **Verify Application Resilience**

During chaos events:

1. **Application remains accessible** (frontend still serves traffic)
2. **Kubernetes recreates killed pods** automatically
3. **Load balancer routes around failed instances**
4. **Monitoring captures service degradation**

## 📚 Learning Exercises

### Exercise 1: Understanding Kubernetes Fundamentals

#### **Pod Lifecycle**

```bash
# Create a test pod
kubectl run test-pod --image=nginx -n sre-shop

# Watch pod creation
kubectl get pods -n sre-shop -w

# Examine pod details
kubectl describe pod test-pod -n sre-shop

# Delete pod and observe recreation (if part of deployment)
kubectl delete pod test-pod -n sre-shop
```

#### **Service Discovery**

```bash
# Connect to a running pod
kubectl exec -it <backend-pod-name> -n sre-shop -- /bin/sh

# Test internal DNS resolution
nslookup redis-service.sre-shop.svc.cluster.local
nslookup backend-service.sre-shop.svc.cluster.local

# Test connectivity
wget -O- redis-service:6379
```

### Exercise 2: SLO Management

#### **Adjust SLO Targets**

1. Edit `k8s-manifests/sre-practices/slo-monitoring/slo-definitions.yaml`
2. Change availability target from 99.9% to 99.5%
3. Apply changes: `kubectl apply -f ...`
4. Observe different alert thresholds

#### **Create Custom SLI**

Add a new SLI for frontend response time:

```yaml
- record: sre_shop:frontend_latency_sli:p99_5m
  expr: histogram_quantile(0.99, rate(nginx_http_request_duration_seconds_bucket[5m]))
```

### Exercise 3: Incident Response

#### **Simulate Common Incidents**

1. **Database Failure**
   
   ```bash
   kubectl scale deployment redis --replicas=0 -n sre-shop
   # Follow runbook: docs/runbooks/database-failure.md
   ```

2. **High Memory Usage**
   
   ```bash
   # Patch deployment to use more memory
   kubectl patch deployment backend-api -n sre-shop -p '{"spec":{"template":{"spec":{"containers":[{"name":"backend","resources":{"limits":{"memory":"32Mi"}}}]}}}}'
   ```

3. **Network Partition**
   
   ```bash
   # Create network policy to isolate components
   kubectl apply -f examples/network-partition.yaml
   ```

### Exercise 4: Chaos Engineering Experiments

#### **Design Custom Chaos**

1. **Modify chaos probability** in chaos-monkey.yaml
2. **Add new failure types** (network latency, disk full)
3. **Create chaos schedules** (business hours vs off-hours)
4. **Measure blast radius** (how far failures propagate)

#### **Chaos Experiment Process**

1. **Hypothesis**: "Application survives 50% pod failures"
2. **Blast Radius**: Limit to one service initially
3. **Monitoring**: Watch SLO metrics during experiment
4. **Analysis**: Document weaknesses discovered
5. **Improvements**: Fix issues and repeat

## 🔧 Troubleshooting

### Common Infrastructure Issues

#### **Terraform Errors**

**Error**: "Insufficient capacity"

```bash
# Solution: Try different instance types or regions
# Edit terraform/variables.tf:
# instance_types = ["t3.small", "t3.medium", "t2.medium"]
```

**Error**: "VPC limit exceeded"

```bash
# Solution: Delete unused VPCs or request limit increase
aws ec2 describe-vpcs
aws support create-case ...
```

#### **EKS Access Issues**

**Error**: "User is not authorized"

```bash
# Solution 1: Add user to EKS cluster
aws eks update-kubeconfig --region eu-central-1 --name sre-lab-eks

# Solution 2: Check IAM permissions
aws sts get-caller-identity
# User needs AmazonEKSClusterAdminPolicy

# Solution 3: Add via AWS Console
# EKS → Cluster → Access → Add IAM user
```

**Error**: "No nodes found"

```bash
# Check node group status
aws eks describe-nodegroup --cluster-name sre-lab-eks --nodegroup-name default

# If failed, recreate:
terraform destroy -target=module.eks.eks_managed_node_groups
terraform apply
```

### Common Kubernetes Issues

#### **Pods Stuck in Pending**

```bash
# Check node resources
kubectl describe nodes

# Check events
kubectl get events -n sre-shop --sort-by='.lastTimestamp'

# Common causes:
# - Insufficient CPU/memory
# - Image pull failures
# - Volume mount issues
```

#### **Services Not Accessible**

```bash
# Check service endpoints
kubectl get endpoints -n sre-shop

# Check pod labels match service selector
kubectl get pods -n sre-shop --show-labels
kubectl describe service frontend-service -n sre-shop

# Test internal connectivity
kubectl run debug --image=nicolaka/netshoot -it --rm -- nslookup frontend-service.sre-shop.svc.cluster.local
```

#### **LoadBalancer Pending**

```bash
# Check AWS load balancer controller
kubectl get pods -n kube-system | grep aws-load-balancer

# Verify subnet tags
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>"
# Should have kubernetes.io/role/elb=1 for public subnets
```

### Monitoring Issues

#### **No Metrics in Prometheus**

```bash
# Check Prometheus targets
kubectl port-forward -n monitoring service/prometheus-service 9090:9090
# Open http://localhost:9090/targets

# Check service discovery
kubectl logs deployment/prometheus -n monitoring | grep discovery

# Verify annotations on pods
kubectl get pods -n sre-shop -o yaml | grep -A5 annotations
```

#### **Grafana Dashboard Empty**

```bash
# Check data source connection
kubectl port-forward -n monitoring service/grafana 3000:3000
# Login admin/admin → Configuration → Data Sources

# Verify Prometheus URL: http://prometheus-service:9090

# Check time range (set to last 1 hour)
# Wait 10-15 minutes for data accumulation
```

#### **Alerts Not Firing**

```bash
# Check alerting rules syntax
kubectl logs deployment/prometheus -n monitoring | grep -i alert

# Verify AlertManager configuration
kubectl get configmap alertmanager-config -n monitoring -o yaml

# Test alert conditions manually in Prometheus
# Query: ALERTS{alertstate="firing"}
```

### Application Issues

#### **Frontend Shows 502 Error**

```bash
# Check backend pod health
kubectl get pods -n sre-shop
kubectl logs deployment/backend-api -n sre-shop

# Verify service configuration
kubectl describe service backend-service -n sre-shop

# Test backend directly
kubectl port-forward service/backend-service 8080:8080 -n sre-shop
curl http://localhost:8080
```

#### **Database Connection Failures**

```bash
# Check Redis pod
kubectl logs deployment/redis -n sre-shop

# Test Redis connectivity
kubectl exec -it deployment/backend-api -n sre-shop -- wget -qO- redis-service:6379

# Check network policies
kubectl get networkpolicies -n sre-shop
```

## 🎓 Advanced Topics

### Scaling Considerations

#### **Horizontal Pod Autoscaling**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
  namespace: sre-shop
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend-api
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

#### **Cluster Autoscaling**

```bash
# Enable cluster autoscaler
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --set autoDiscovery.clusterName=sre-lab-eks
```

### Security Hardening

#### **Network Policies**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: sre-shop-network-policy
  namespace: sre-shop
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: sre-shop
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: monitoring
```

#### **Pod Security Standards**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: sre-shop
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Cost Optimization

#### **Resource Requests vs Limits**

```yaml
resources:
  requests:    # Guaranteed resources
    memory: "64Mi"
    cpu: "50m"
  limits:      # Maximum allowed
    memory: "128Mi"
    cpu: "100m"
```

#### **Spot Instances**

```terraform
# In terraform/eks.tf
eks_managed_node_groups = {
  spot = {
    capacity_type  = "SPOT"
    instance_types = ["t3.medium", "t3.large"]
    desired_size   = 2
    max_size       = 4
    min_size       = 1
  }
}
```

## 🧹 Cleanup

### Full Environment Cleanup

```bash
# Delete Kubernetes resources
kubectl delete namespace sre-shop
kubectl delete namespace monitoring

# Destroy infrastructure
cd terraform
terraform destroy
```

### Partial Cleanup

```bash
# Remove only applications (keep cluster)
kubectl delete -f k8s-manifests/app/
kubectl delete -f k8s-manifests/monitoring/
kubectl delete -f k8s-manifests/sre-practices/

# Remove only SRE practices (keep apps)
kubectl delete -f k8s-manifests/sre-practices/
```

### Cost Monitoring

```bash
# Check current costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

**Expected Monthly Costs:**

- **EKS Cluster**: $72 (cluster management)
- **EC2 Instances**: $60 (2 x t3.medium)
- **Load Balancers**: $36 (2 x ALB)
- **NAT Gateways**: $90 (2 x NAT + data transfer)
- **Total**: ~$260/month

## 📖 Further Reading

### Essential SRE Resources

- [Google SRE Book](https://sre.google/sre-book/table-of-contents/) - Foundational concepts
- [Site Reliability Workbook](https://sre.google/workbook/table-of-contents/) - Practical implementation
- [Prometheus Documentation](https://prometheus.io/docs/) - Monitoring best practices
- [Kubernetes Documentation](https://kubernetes.io/docs/) - Container orchestration

### Advanced Topics

- [Chaos Engineering Principles](https://principlesofchaos.org/) - Failure testing methodology
- [OpenTelemetry](https://opentelemetry.io/) - Observability standards
- [GitOps with ArgoCD](https://argo-cd.readthedocs.io/) - Continuous deployment
- [Service Mesh with Istio](https://istio.io/) - Advanced networking and security

# 

---

**🎯 You now have a complete, production-grade SRE training environment!**

This setup mirrors what you'd find at companies like Google, Netflix, and Spotify. Use it to practice SRE skills, experiment with new technologies, and build confidence with real-world reliability engineering.

**Next Steps:**

1. **Follow the step-by-step setup** to build your environment
2. **Complete the learning exercises** to understand each component
3. **Experiment with configurations** to see how changes affect behavior
4. **Practice incident response** using the provided runbooks
5. **Read the deep-dive documentation** to understand why we made each choice

Happy learning! 🚀