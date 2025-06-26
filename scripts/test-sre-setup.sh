#!/bin/bash

# SRE Practices Testing Script
# Tests that all components are working correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[TEST]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}==== $1 ====${NC}"
}

print_header "SRE Practices Testing Suite"

# Get service IPs
PROMETHEUS_IP=$(kubectl get service prometheus-service -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
GRAFANA_IP=$(kubectl get service grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
ALERTMANAGER_IP=$(kubectl get service alertmanager -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
FRONTEND_IP=$(kubectl get service frontend-service -n sre-shop -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")

print_header "1. Service Accessibility Test"

if [[ "$PROMETHEUS_IP" != "pending" ]]; then
    print_status "✅ Prometheus accessible at: http://$PROMETHEUS_IP:9090"
else
    print_warning "⚠️  Prometheus LoadBalancer IP pending"
fi

if [[ "$GRAFANA_IP" != "pending" ]]; then
    print_status "✅ Grafana accessible at: http://$GRAFANA_IP:3000 (admin/admin)"
else
    print_warning "⚠️  Grafana LoadBalancer IP pending"
fi

if [[ "$ALERTMANAGER_IP" != "pending" ]]; then
    print_status "✅ AlertManager accessible at: http://$ALERTMANAGER_IP:9093"
else
    print_warning "⚠️  AlertManager LoadBalancer IP pending"
fi

if [[ "$FRONTEND_IP" != "pending" ]]; then
    print_status "✅ SRE Shop App accessible at: http://$FRONTEND_IP"
else
    print_warning "⚠️  SRE Shop App LoadBalancer IP pending"
fi

print_header "2. Pod Status Test"

# Check monitoring pods
PROMETHEUS_READY=$(kubectl get pods -n monitoring -l app=prometheus -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
GRAFANA_READY=$(kubectl get pods -n monitoring -l app=grafana -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
ALERTMANAGER_READY=$(kubectl get pods -n monitoring -l app=alertmanager -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")

if [[ "$PROMETHEUS_READY" == "True" ]]; then
    print_status "✅ Prometheus pod is ready"
else
    print_error "❌ Prometheus pod is not ready"
fi

if [[ "$GRAFANA_READY" == "True" ]]; then
    print_status "✅ Grafana pod is ready"
else
    print_error "❌ Grafana pod is not ready"
fi

if [[ "$ALERTMANAGER_READY" == "True" ]]; then
    print_status "✅ AlertManager pod is ready"
else
    print_error "❌ AlertManager pod is not ready"
fi

# Check application pods
BACKEND_COUNT=$(kubectl get pods -n sre-shop -l app=backend-api --field-selector=status.phase=Running --no-headers | wc -l)
FRONTEND_COUNT=$(kubectl get pods -n sre-shop -l app=frontend --field-selector=status.phase=Running --no-headers | wc -l)
REDIS_COUNT=$(kubectl get pods -n sre-shop -l app=redis --field-selector=status.phase=Running --no-headers | wc -l)

print_status "✅ Backend pods running: $BACKEND_COUNT/2"
print_status "✅ Frontend pods running: $FRONTEND_COUNT/3"
print_status "✅ Redis pods running: $REDIS_COUNT/1"

print_header "3. SLO Rules Test"

if [[ "$PROMETHEUS_IP" != "pending" ]]; then
    print_status "Testing if SLO recording rules are loaded..."
    
    # Test if we can query SLO metrics (this may take a few minutes to have data)
    echo "Query test commands:"
    echo "curl -s \"http://$PROMETHEUS_IP:9090/api/v1/query?query=sre_shop:availability_sli:rate5m\""
    echo "curl -s \"http://$PROMETHEUS_IP:9090/api/v1/query?query=up{job=\\\"sre-shop-backend\\\"}\""
    
    # Check if the rules are loaded in Prometheus
    RULES_LOADED=$(curl -s "http://$PROMETHEUS_IP:9090/api/v1/rules" 2>/dev/null | grep -c "sre_shop:" || echo "0")
    if [[ "$RULES_LOADED" -gt "0" ]]; then
        print_status "✅ SLO recording rules are loaded in Prometheus"
    else
        print_warning "⚠️  SLO rules may still be loading or not configured correctly"
    fi
else
    print_warning "⚠️  Cannot test SLO rules - Prometheus IP pending"
fi

print_header "4. Alerting Test"

if [[ "$ALERTMANAGER_IP" != "pending" ]]; then
    print_status "Testing AlertManager configuration..."
    
    # Check if AlertManager is healthy
    AM_HEALTHY=$(curl -s "http://$ALERTMANAGER_IP:9093/-/healthy" 2>/dev/null || echo "unhealthy")
    if [[ "$AM_HEALTHY" == "Healthy" ]]; then
        print_status "✅ AlertManager is healthy"
    else
        print_warning "⚠️  AlertManager health check failed"
    fi
    
    echo "AlertManager UI: http://$ALERTMANAGER_IP:9093"
else
    print_warning "⚠️  Cannot test AlertManager - IP pending"
fi

print_header "5. Chaos Engineering Test"

CHAOS_POD=$(kubectl get pods -n sre-shop -l app=chaos-monkey -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "none")
if [[ "$CHAOS_POD" != "none" ]]; then
    CHAOS_STATUS=$(kubectl get pod $CHAOS_POD -n sre-shop -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    if [[ "$CHAOS_STATUS" == "Running" ]]; then
        print_status "✅ Chaos Monkey is running"
        print_status "Monitor chaos events with: kubectl logs -f $CHAOS_POD -n sre-shop"
    else
        print_warning "⚠️  Chaos Monkey pod status: $CHAOS_STATUS"
        print_status "Check logs with: kubectl logs $CHAOS_POD -n sre-shop"
    fi
else
    print_error "❌ Chaos Monkey pod not found"
fi

print_header "6. Dashboard Test"

if [[ "$GRAFANA_IP" != "pending" ]]; then
    print_status "✅ Access Grafana dashboards at: http://$GRAFANA_IP:3000"
    print_status "   - Username: admin"
    print_status "   - Password: admin"
    print_status "   - Available dashboards:"
    print_status "     • Kubernetes Overview"
    print_status "     • SRE Shop Application"
    print_status "     • SRE Shop - SLO Dashboard"
else
    print_warning "⚠️  Cannot access Grafana - IP pending"
fi

print_header "Test Summary"

echo ""
echo "📊 Service URLs:"
echo "================================"
echo "Prometheus:   http://$PROMETHEUS_IP:9090"
echo "Grafana:      http://$GRAFANA_IP:3000 (admin/admin)"
echo "AlertManager: http://$ALERTMANAGER_IP:9093"
echo "SRE Shop App: http://$FRONTEND_IP"
echo ""

print_header "Next Steps for Testing"

cat << 'EOF'
🧪 Manual Testing Procedures:

1. Test SLO Monitoring:
   - Open Prometheus and verify these queries work:
     * sre_shop:availability_sli:rate5m
     * up{job="sre-shop-backend"}
   - Open Grafana and check the "SRE Shop - SLO Dashboard"

2. Test SLO Alerts:
   - Scale down backend: kubectl scale deployment backend-api --replicas=0 -n sre-shop
   - Wait 5-10 minutes for alerts to fire
   - Check AlertManager UI for active alerts
   - Scale back up: kubectl scale deployment backend-api --replicas=2 -n sre-shop

3. Test Chaos Engineering:
   - Monitor: kubectl logs -f deployment/chaos-monkey -n sre-shop
   - Watch for pod terminations every 5 minutes (5% probability)
   - Verify application remains accessible during chaos events

4. Test Incident Response:
   - Follow runbooks in k8s-manifests/sre-practices/runbooks/
   - Practice investigation procedures
   - Document any findings

🚀 Your SRE training environment is ready!
EOF

echo ""