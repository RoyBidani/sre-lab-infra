#!/bin/bash

# SRE Practices Deployment Script
# Deploys SLO monitoring, alerting, chaos testing, and runbooks

set -e

echo "🚀 Deploying SRE Practices for SRE Shop Training Environment"
echo "============================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}==== $1 ====${NC}"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_header "1. Deploying SLO Definitions and Recording Rules"
print_status "Creating SLO monitoring configurations..."

# Create the SLO monitoring directory if it doesn't exist
mkdir -p k8s-manifests/sre-practices/slo-monitoring/

# Apply SLO definitions
if kubectl apply -f k8s-manifests/sre-practices/slo-monitoring/; then
    print_status "✅ SLO monitoring configurations deployed successfully"
else
    print_error "❌ Failed to deploy SLO monitoring configurations"
    exit 1
fi

print_header "2. Deploying SLO-Based Alerting Rules"
print_status "Setting up SLO violation alerts..."

# Create alerting directory if it doesn't exist
mkdir -p k8s-manifests/sre-practices/alerting/

# Apply all alerting configurations
if kubectl apply -f k8s-manifests/sre-practices/alerting/; then
    print_status "✅ SLO alerting configurations deployed successfully"
else
    print_error "❌ Failed to deploy alerting configurations"
    exit 1
fi

print_header "3. Deploying Chaos Testing Framework"
print_status "Setting up Chaos testing tools for resilience testing..."

# Create chaos testing directory if it doesn't exist
mkdir -p k8s-manifests/sre-practices/chaos-testing/

# Apply all chaos testing configurations
if kubectl apply -f k8s-manifests/sre-practices/chaos-testing/; then
    print_status "✅ Chaos testing tools deployed successfully"
else
    print_error "❌ Failed to deploy chaos testing tools"
    exit 1
fi

print_header "4. Updating Prometheus and Grafana Configuration"
print_status "Updating Prometheus configuration to load SLO rules..."

# Update Prometheus configuration
if kubectl apply -f k8s-manifests/monitoring/prometheus-configmap.yaml; then
    print_status "✅ Prometheus configuration updated"
else
    print_error "❌ Failed to update Prometheus configuration"
    exit 1
fi

# Update Prometheus deployment to mount rule files
if kubectl apply -f k8s-manifests/monitoring/prometheus-deployment.yaml; then
    print_status "✅ Prometheus deployment updated"
else
    print_error "❌ Failed to update Prometheus deployment"
    exit 1
fi

# Update Grafana with SLO dashboard
if kubectl apply -f k8s-manifests/monitoring/grafana-configmap.yaml; then
    print_status "✅ Grafana dashboards updated"
else
    print_error "❌ Failed to update Grafana dashboards"
    exit 1
fi


print_status "Restarting services to load new configurations..."
if kubectl rollout restart deployment/prometheus -n monitoring && kubectl rollout restart deployment/grafana -n monitoring; then
    print_status "✅ Services restarted successfully"
    print_status "Waiting for services to be ready..."
    kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=120s
    kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=120s
else
    print_warning "⚠️  Could not restart services automatically"
    print_warning "Please restart manually: kubectl rollout restart deployment/prometheus deployment/grafana -n monitoring"
fi

print_header "5. Verification"
print_status "Verifying deployments..."

# Check SLO recording rules are loaded
print_status "Checking if SLO recording rules are active..."
sleep 10  # Give Prometheus time to reload

# Check chaos monkey is running
if kubectl get pods -n sre-shop -l app=chaos-monkey | grep -q Running; then
    print_status "✅ Chaos Monkey is running"
else
    print_warning "⚠️  Chaos Monkey pod may not be ready yet"
fi

# Check AlertManager is running
if kubectl get pods -n monitoring -l app=alertmanager | grep -q Running; then
    print_status "✅ AlertManager is running"
else
    print_warning "⚠️  AlertManager pod may not be ready yet"
fi

print_header "6. Access Information"
print_status "Getting service access information..."

# Get LoadBalancer IPs
PROMETHEUS_IP=$(kubectl get service prometheus -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
GRAFANA_IP=$(kubectl get service grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
ALERTMANAGER_IP=$(kubectl get service alertmanager -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")

echo ""
echo "📊 SRE Practices Access URLs:"
echo "================================"
echo "Prometheus:   http://$PROMETHEUS_IP:9090"
echo "Grafana:      http://$GRAFANA_IP:3000 (admin/admin)"
echo "AlertManager: http://$ALERTMANAGER_IP:9093"
echo ""

print_header "7. Testing Instructions"
cat << 'EOF'
🧪 SRE Practices Testing Guide:
===============================

1. Test SLO Monitoring:
   - Open Grafana and check the "SRE Shop - SLO Dashboard"
   - Verify SLI metrics are being collected
   - Check recording rules in Prometheus: sre_shop:availability_sli:rate5m

2. Test Alerting:
   - Temporarily scale down backend pods: kubectl scale deployment backend-api --replicas=0 -n sre-shop
   - Wait 5-10 minutes for SLO violation alert to fire
   - Check AlertManager UI for active alerts
   - Scale back up: kubectl scale deployment backend-api --replicas=2 -n sre-shop

3. Test Chaos Engineering:
   - Monitor Chaos Monkey logs: kubectl logs -f deployment/chaos-monkey -n sre-shop
   - Watch for pod terminations and verify application resilience
   - Check application remains accessible during chaos events

4. Test Incident Response:
   - Use the runbooks in k8s-manifests/sre-practices/runbooks/
   - Practice incident response procedures
   - Document any gaps or improvements needed

5. Monitor Error Budget:
   - Track error budget consumption in Grafana
   - Understand the relationship between SLO violations and error budget burn

📚 Documentation:
- Runbooks: k8s-manifests/sre-practices/runbooks/
- SLO Definitions: k8s-manifests/sre-practices/slo-monitoring/
- Chaos Experiments: k8s-manifests/sre-practices/chaos-testing/

🚨 Important Notes:
- Chaos Monkey runs with low probability (5%) to avoid disruption
- Adjust chaos settings in chaos-monkey.yaml if needed
- Configure real Slack/PagerDuty webhooks in alertmanager.yaml for production
- Review and customize SLO targets based on your requirements

EOF

print_header "Deployment Complete!"
print_status "🎉 All SRE practices have been successfully deployed!"
print_status "Running comprehensive tests..."

# Run the test script
if ./test-sre-setup.sh; then
    print_status "✅ Test suite completed"
else
    print_warning "⚠️  Some tests may have failed - check output above"
fi

print_status ""
print_status "🚀 SRE training environment is ready for advanced practices!"
print_status ""
print_status "Next steps:"
print_status "1. Configure notification channels (Slack/PagerDuty) in alertmanager.yaml"
print_status "2. Customize SLO targets based on your requirements"
print_status "3. Practice incident response scenarios using the runbooks"
print_status "4. Run chaos experiments and document findings"
print_status "5. Use the test script anytime: ./test-sre-setup.sh"

echo ""