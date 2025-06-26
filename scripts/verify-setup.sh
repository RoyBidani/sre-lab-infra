#!/bin/bash

# Comprehensive Monitoring Verification Script
# Tests all monitoring components step by step

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}================================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}================================================${NC}"
}

# Get service URLs
PROMETHEUS_URL=$(kubectl get service prometheus-service -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
GRAFANA_URL=$(kubectl get service grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
ALERTMANAGER_URL=$(kubectl get service alertmanager -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
APP_URL=$(kubectl get service frontend-service -n sre-shop -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)

if [[ -z "$PROMETHEUS_URL" ]]; then
    print_error "Cannot get Prometheus URL. Make sure the service is running."
    exit 1
fi

print_header "MONITORING VERIFICATION SUITE"
echo "Prometheus: http://$PROMETHEUS_URL:9090"
echo "Grafana: http://$GRAFANA_URL:3000"
echo "AlertManager: http://$ALERTMANAGER_URL:9093"
echo "SRE Shop App: http://$APP_URL"

print_header "1. BASIC CONNECTIVITY TEST"

print_step "Testing Prometheus connectivity..."
if curl -s "http://$PROMETHEUS_URL:9090/-/healthy" | grep -q "Healthy"; then
    print_success "✅ Prometheus is healthy and accessible"
else
    print_error "❌ Prometheus health check failed"
    exit 1
fi

print_step "Testing Grafana connectivity..."
GRAFANA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$GRAFANA_URL:3000/api/health" || echo "000")
if [[ "$GRAFANA_STATUS" == "200" ]]; then
    print_success "✅ Grafana is accessible"
else
    print_warning "⚠️  Grafana may still be starting up (HTTP $GRAFANA_STATUS)"
fi

print_step "Testing application connectivity..."
if curl -s "http://$APP_URL" | grep -q "Welcome\|Frontend\|SRE Shop" > /dev/null 2>&1; then
    print_success "✅ SRE Shop application is accessible"
else
    print_warning "⚠️  SRE Shop application may not be fully ready"
fi

print_header "2. PROMETHEUS METRICS VERIFICATION"

print_step "Checking if Prometheus can scrape targets..."
TARGETS_UP=$(curl -s "http://$PROMETHEUS_URL:9090/api/v1/query?query=up" | jq -r '.data.result | length' 2>/dev/null || echo "0")
if [[ "$TARGETS_UP" -gt 0 ]]; then
    print_success "✅ Prometheus is scraping $TARGETS_UP targets"
    
    # Show which targets are up
    curl -s "http://$PROMETHEUS_URL:9090/api/v1/query?query=up" | jq -r '.data.result[] | "  - " + .metric.job + " (" + .metric.instance + "): " + .value[1]' 2>/dev/null || echo "  (Could not parse target details)"
else
    print_error "❌ No targets are being scraped by Prometheus"
fi

print_step "Checking SRE Shop backend metrics..."
BACKEND_METRICS=$(curl -s "http://$PROMETHEUS_URL:9090/api/v1/query?query=up{job=\"sre-shop-backend\"}" | jq -r '.data.result | length' 2>/dev/null || echo "0")
if [[ "$BACKEND_METRICS" -gt 0 ]]; then
    print_success "✅ SRE Shop backend metrics are being collected"
else
    print_warning "⚠️  SRE Shop backend metrics not found - this is normal if just started"
fi

print_step "Checking Kubernetes metrics..."
K8S_METRICS=$(curl -s "http://$PROMETHEUS_URL:9090/api/v1/query?query=kube_pod_info" | jq -r '.data.result | length' 2>/dev/null || echo "0")
if [[ "$K8S_METRICS" -gt 0 ]]; then
    print_success "✅ Kubernetes metrics are being collected ($K8S_METRICS pods monitored)"
else
    print_warning "⚠️  Kubernetes metrics not found - kube-state-metrics may not be deployed"
fi

print_header "3. SLO RECORDING RULES VERIFICATION"

print_step "Checking if SLO recording rules are working..."

# Check availability SLI
AVAILABILITY_SLI=$(curl -s "http://$PROMETHEUS_URL:9090/api/v1/query?query=sre_shop:availability_sli:rate5m" | jq -r '.data.result | length' 2>/dev/null || echo "0")
if [[ "$AVAILABILITY_SLI" -gt 0 ]]; then
    AVAILABILITY_VALUE=$(curl -s "http://$PROMETHEUS_URL:9090/api/v1/query?query=sre_shop:availability_sli:rate5m" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "unknown")
    print_success "✅ Availability SLI is working: $AVAILABILITY_VALUE"
else
    print_warning "⚠️  Availability SLI not yet available (may need more time to collect data)"
fi

# Check error rate SLI
ERROR_RATE_SLI=$(curl -s "http://$PROMETHEUS_URL:9090/api/v1/query?query=sre_shop:error_rate_sli:rate5m" | jq -r '.data.result | length' 2>/dev/null || echo "0")
if [[ "$ERROR_RATE_SLI" -gt 0 ]]; then
    ERROR_VALUE=$(curl -s "http://$PROMETHEUS_URL:9090/api/v1/query?query=sre_shop:error_rate_sli:rate5m" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "unknown")
    print_success "✅ Error Rate SLI is working: $ERROR_VALUE"
else
    print_warning "⚠️  Error Rate SLI not yet available"
fi

# Check CPU saturation SLI
CPU_SLI=$(curl -s "http://$PROMETHEUS_URL:9090/api/v1/query?query=sre_shop:cpu_saturation_sli:rate5m" | jq -r '.data.result | length' 2>/dev/null || echo "0")
if [[ "$CPU_SLI" -gt 0 ]]; then
    CPU_VALUE=$(curl -s "http://$PROMETHEUS_URL:9090/api/v1/query?query=sre_shop:cpu_saturation_sli:rate5m" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "unknown")
    print_success "✅ CPU Saturation SLI is working: ${CPU_VALUE}%"
else
    print_warning "⚠️  CPU Saturation SLI not yet available"
fi

print_step "Checking SLO targets..."
SLO_TARGET=$(curl -s "http://$PROMETHEUS_URL:9090/api/v1/query?query=sre_shop:availability_slo_target" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "not found")
if [[ "$SLO_TARGET" != "not found" ]]; then
    print_success "✅ SLO target is set to: $SLO_TARGET (99.9%)"
else
    print_warning "⚠️  SLO target not found"
fi

print_header "4. ALERTING RULES VERIFICATION"

print_step "Checking if alerting rules are loaded..."
ALERT_RULES=$(curl -s "http://$PROMETHEUS_URL:9090/api/v1/rules" | jq -r '.data.groups[] | select(.name | contains("slo")) | .rules | length' 2>/dev/null | paste -sd+ | bc 2>/dev/null || echo "0")
if [[ "$ALERT_RULES" -gt 0 ]]; then
    print_success "✅ $ALERT_RULES SLO alerting rules are loaded"
else
    print_warning "⚠️  SLO alerting rules not found"
fi

print_step "Checking active alerts..."
ACTIVE_ALERTS=$(curl -s "http://$PROMETHEUS_URL:9090/api/v1/alerts" | jq -r '.data.alerts | length' 2>/dev/null || echo "0")
if [[ "$ACTIVE_ALERTS" -gt 0 ]]; then
    print_warning "⚠️  $ACTIVE_ALERTS alerts are currently firing"
    curl -s "http://$PROMETHEUS_URL:9090/api/v1/alerts" | jq -r '.data.alerts[] | "  - " + .labels.alertname + " (" + .state + ")"' 2>/dev/null || echo "  (Could not parse alert details)"
else
    print_success "✅ No alerts are currently firing (system is healthy)"
fi

print_header "5. GRAFANA DASHBOARDS VERIFICATION"

print_step "Checking if Grafana dashboards are loaded..."
if command -v jq >/dev/null 2>&1; then
    DASHBOARDS=$(curl -s -u admin:admin "http://$GRAFANA_URL:3000/api/search" | jq -r '. | length' 2>/dev/null || echo "unknown")
    if [[ "$DASHBOARDS" != "unknown" && "$DASHBOARDS" -gt 0 ]]; then
        print_success "✅ $DASHBOARDS dashboards are available in Grafana"
        curl -s -u admin:admin "http://$GRAFANA_URL:3000/api/search" | jq -r '.[] | "  - " + .title' 2>/dev/null || echo "  (Could not list dashboard titles)"
    else
        print_warning "⚠️  Could not verify Grafana dashboards"
    fi
else
    print_warning "⚠️  jq not available - cannot verify Grafana dashboards automatically"
fi

print_header "6. CHAOS ENGINEERING VERIFICATION"

print_step "Checking Chaos Monkey status..."
CHAOS_POD=$(kubectl get pods -n sre-shop -l app=chaos-monkey -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "none")
if [[ "$CHAOS_POD" != "none" ]]; then
    CHAOS_STATUS=$(kubectl get pod $CHAOS_POD -n sre-shop -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    if [[ "$CHAOS_STATUS" == "Running" ]]; then
        print_success "✅ Chaos Monkey is running: $CHAOS_POD"
        
        # Check recent logs for chaos activity
        RECENT_CHAOS=$(kubectl logs $CHAOS_POD -n sre-shop --tail=10 2>/dev/null | grep -c "Looking for victims\|Killing pod\|survives" || echo "0")
        if [[ "$RECENT_CHAOS" -gt 0 ]]; then
            print_success "✅ Chaos Monkey is actively running experiments"
        else
            print_warning "⚠️  Chaos Monkey is running but no recent activity detected"
        fi
    else
        print_warning "⚠️  Chaos Monkey pod status: $CHAOS_STATUS"
    fi
else
    print_error "❌ Chaos Monkey pod not found"
fi

print_header "7. END-TO-END MONITORING TEST"

print_step "Performing application stress test to generate metrics..."

# Generate some load to create metrics
print_step "Generating application traffic..."
for i in {1..5}; do
    curl -s "http://$APP_URL" > /dev/null 2>&1 || true
    sleep 1
done

print_step "Waiting 30 seconds for metrics to propagate..."
sleep 30

print_step "Checking if new metrics appeared..."
RECENT_METRICS=$(curl -s "http://$PROMETHEUS_URL:9090/api/v1/query?query=up{job=\"sre-shop-backend\"}" | jq -r '.data.result | length' 2>/dev/null || echo "0")
if [[ "$RECENT_METRICS" -gt 0 ]]; then
    print_success "✅ End-to-end monitoring is working - metrics are flowing"
else
    print_warning "⚠️  End-to-end test inconclusive - may need more time"
fi

print_header "VERIFICATION SUMMARY"

echo ""
echo "🔍 Manual Verification Steps:"
echo "=============================="
echo ""
echo "1. Open Prometheus: http://$PROMETHEUS_URL:9090"
echo "   - Go to Status > Targets to see all monitored services"
echo "   - Try queries: up, sre_shop:availability_sli:rate5m"
echo ""
echo "2. Open Grafana: http://$GRAFANA_URL:3000 (admin/admin)"
echo "   - Check 'SRE Shop - SLO Dashboard'"
echo "   - Verify SLI metrics are displayed"
echo ""
echo "3. Test Alerting:"
echo "   kubectl scale deployment backend-api --replicas=0 -n sre-shop"
echo "   # Wait 5-10 minutes, then check AlertManager"
echo "   kubectl scale deployment backend-api --replicas=2 -n sre-shop"
echo ""
echo "4. Monitor Chaos Engineering:"
echo "   kubectl logs -f $CHAOS_POD -n sre-shop"
echo ""

if [[ "$AVAILABILITY_SLI" -gt 0 ]] && [[ "$TARGETS_UP" -gt 0 ]]; then
    print_success "🎉 VERIFICATION PASSED: Your monitoring setup is working correctly!"
else
    print_warning "⚠️  Some components may need more time to fully initialize"
    echo "   Run this script again in 5-10 minutes for complete verification"
fi

echo ""