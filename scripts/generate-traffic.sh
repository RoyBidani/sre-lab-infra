#!/bin/bash

# Traffic Generation Script for SRE Shop Application
# Generates realistic traffic patterns to populate monitoring metrics

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[TRAFFIC]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Get application URLs
FRONTEND_URL=$(kubectl get service frontend-service -n sre-shop -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
BACKEND_URL=$(kubectl get service backend-service -n sre-shop -o jsonpath='{.spec.clusterIP}' 2>/dev/null)

if [[ -z "$FRONTEND_URL" ]]; then
    echo "❌ Could not get frontend URL. Make sure the service is running."
    exit 1
fi

print_info "🌐 Application URLs:"
print_info "   Frontend: http://$FRONTEND_URL"
print_info "   Backend (internal): http://$BACKEND_URL:8080"

echo ""
echo "🚀 Generating Traffic to SRE Shop Application"
echo "=============================================="

# Function to make a request and show status
make_request() {
    local url="$1"
    local label="$2"
    
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    if [[ "$STATUS" == "200" ]]; then
        print_status "✅ $label - HTTP $STATUS"
    else
        print_status "⚠️  $label - HTTP $STATUS"
    fi
}

# Function to generate continuous traffic
generate_continuous_traffic() {
    local duration="$1"
    local interval="$2"
    
    print_info "🔄 Generating continuous traffic for $duration seconds (every $interval seconds)"
    
    local end_time=$(($(date +%s) + duration))
    local count=1
    
    while [[ $(date +%s) -lt $end_time ]]; do
        make_request "http://$FRONTEND_URL" "Request #$count"
        
        # Also test backend API through port-forward (optional)
        # kubectl port-forward service/backend-service 8080:8080 -n sre-shop &
        # PF_PID=$!
        # sleep 2
        # make_request "http://localhost:8080" "Backend #$count"
        # kill $PF_PID 2>/dev/null || true
        
        count=$((count + 1))
        sleep "$interval"
    done
}

# Function to generate burst traffic
generate_burst_traffic() {
    local requests="$1"
    
    print_info "💥 Generating burst traffic ($requests requests)"
    
    for i in $(seq 1 "$requests"); do
        make_request "http://$FRONTEND_URL" "Burst #$i"
        # Small delay to avoid overwhelming
        sleep 0.1
    done
}

# Show menu
echo ""
echo "📋 Traffic Generation Options:"
echo "1. Light traffic (1 request every 5 seconds for 2 minutes)"
echo "2. Moderate traffic (1 request every 2 seconds for 5 minutes)" 
echo "3. Heavy traffic (1 request every 1 second for 3 minutes)"
echo "4. Burst test (50 requests quickly)"
echo "5. Continuous monitoring traffic (1 request every 10 seconds, runs until stopped)"
echo "6. Custom traffic pattern"
echo ""

read -p "Choose option (1-6): " choice

case $choice in
    1)
        print_info "🟢 Starting light traffic..."
        generate_continuous_traffic 120 5
        ;;
    2)
        print_info "🟡 Starting moderate traffic..."
        generate_continuous_traffic 300 2
        ;;
    3)
        print_info "🔴 Starting heavy traffic..."
        generate_continuous_traffic 180 1
        ;;
    4)
        print_info "💥 Starting burst test..."
        generate_burst_traffic 50
        ;;
    5)
        print_info "♻️  Starting continuous monitoring traffic (Ctrl+C to stop)..."
        trap 'print_info "🛑 Traffic generation stopped"; exit 0' INT
        while true; do
            make_request "http://$FRONTEND_URL" "Monitor"
            sleep 10
        done
        ;;
    6)
        read -p "Enter duration (seconds): " duration
        read -p "Enter interval between requests (seconds): " interval
        print_info "🎛️  Starting custom traffic..."
        generate_continuous_traffic "$duration" "$interval"
        ;;
    *)
        echo "Invalid option. Running default light traffic..."
        generate_continuous_traffic 120 5
        ;;
esac

echo ""
print_info "✅ Traffic generation completed!"
print_info ""
print_info "📊 Check your monitoring:"
print_info "   Grafana: Open SRE Shop - SLO Dashboard"
print_info "   Prometheus: Query 'up{job=\"sre-shop-backend\"}'"
print_info ""
print_info "💡 Tip: Wait 5-10 minutes for metrics to appear in dashboards"