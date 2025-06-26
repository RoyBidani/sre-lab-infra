#!/bin/bash

# Rolling Update Script - Zero Downtime Deployment
# Handles application updates, configuration changes, and infrastructure updates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
NAMESPACE="sre-shop"
MONITORING_NAMESPACE="monitoring"
ROLLBACK_TIMEOUT="300s"
HEALTH_CHECK_RETRIES=10
HEALTH_CHECK_DELAY=30

print_header() {
    echo -e "\n${BLUE}==== $1 ====${NC}"
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_progress() {
    echo -e "${CYAN}[PROGRESS]${NC} $1"
}

show_usage() {
    cat << EOF
🚀 Rolling Update Script - Zero Downtime Deployment

Usage: $0 [COMPONENT] [OPTIONS]

COMPONENTS:
    app                 Update SRE Shop application
    monitoring          Update monitoring stack (Prometheus/Grafana)
    sre-practices       Update SLO monitoring, alerting, chaos testing
    infrastructure      Update Terraform infrastructure
    all                 Update all components

OPTIONS:
    --image-tag TAG     Specify new image tag for application updates
    --dry-run          Show what would be updated without making changes
    --force            Skip confirmation prompts
    --rollback         Rollback to previous version
    --check-only       Only check health, don't deploy

EXAMPLES:
    $0 app --image-tag v2.1.0
    $0 monitoring --dry-run
    $0 sre-practices --force
    $0 infrastructure
    $0 all --check-only

FEATURES:
    ✅ Zero downtime deployments
    ✅ Automatic health checks
    ✅ Rollback on failure
    ✅ Pre-deployment validation
    ✅ Traffic monitoring during updates
    ✅ SLO compliance checking

EOF
}

check_prerequisites() {
    print_header "Prerequisites Check"
    
    # Check kubectl connectivity
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        print_error "Run: aws eks update-kubeconfig --region eu-central-1 --name sre-lab-eks"
        exit 1
    fi
    
    # Check if namespaces exist
    if ! kubectl get namespace $NAMESPACE &> /dev/null; then
        print_error "Namespace '$NAMESPACE' not found"
        exit 1
    fi
    
    if ! kubectl get namespace $MONITORING_NAMESPACE &> /dev/null; then
        print_error "Namespace '$MONITORING_NAMESPACE' not found"
        exit 1
    fi
    
    print_status "✅ All prerequisites met"
}

get_current_versions() {
    print_header "Current Deployment Status"
    
    echo "📊 Application Status:"
    kubectl get deployments -n $NAMESPACE -o custom-columns="NAME:.metadata.name,REPLICAS:.spec.replicas,READY:.status.readyReplicas,IMAGE:.spec.template.spec.containers[0].image"
    
    echo -e "\n📊 Monitoring Status:"
    kubectl get deployments -n $MONITORING_NAMESPACE -o custom-columns="NAME:.metadata.name,REPLICAS:.spec.replicas,READY:.status.readyReplicas,IMAGE:.spec.template.spec.containers[0].image"
    
    echo -e "\n🔗 Service Status:"
    kubectl get services -n $NAMESPACE -o custom-columns="NAME:.metadata.name,TYPE:.spec.type,EXTERNAL-IP:.status.loadBalancer.ingress[0].hostname"
}

validate_health() {
    local component=$1
    local namespace=$2
    
    print_progress "Checking health for $component in namespace $namespace..."
    
    # Check pod readiness
    local ready_pods=$(kubectl get pods -n $namespace -l app=$component --field-selector=status.phase=Running -o jsonpath='{.items[?(@.status.conditions[?(@.type=="Ready")].status=="True")].metadata.name}' | wc -w)
    local total_pods=$(kubectl get pods -n $namespace -l app=$component --field-selector=status.phase=Running --no-headers | wc -l)
    
    if [ "$ready_pods" -eq "$total_pods" ] && [ "$total_pods" -gt 0 ]; then
        print_status "✅ $component: $ready_pods/$total_pods pods ready"
        return 0
    else
        print_warning "⚠️  $component: $ready_pods/$total_pods pods ready"
        return 1
    fi
}

check_slo_compliance() {
    print_progress "Checking SLO compliance during update..."
    
    # Get Prometheus service URL
    local prometheus_ip=$(kubectl get service prometheus-service -n $MONITORING_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ -n "$prometheus_ip" ]; then
        # Check availability SLI
        local availability=$(curl -s "http://$prometheus_ip:9090/api/v1/query?query=sre_shop:availability_sli:rate5m" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
        
        if (( $(echo "$availability > 0.999" | bc -l) )); then
            print_status "✅ Availability SLO met: $(echo "$availability * 100" | bc -l | cut -d. -f1)%"
        else
            print_warning "⚠️  Availability SLO at risk: $(echo "$availability * 100" | bc -l | cut -d. -f1)%"
        fi
    else
        print_warning "⚠️  Cannot check SLO - Prometheus not accessible"
    fi
}

update_application() {
    local image_tag=$1
    local dry_run=$2
    
    print_header "Rolling Update: SRE Shop Application"
    
    if [ -n "$image_tag" ]; then
        print_status "Updating to image tag: $image_tag"
    fi
    
    # Update backend
    print_progress "Updating backend deployment..."
    if [ "$dry_run" = "true" ]; then
        print_status "DRY RUN: Would update backend deployment"
    else
        if [ -n "$image_tag" ]; then
            kubectl set image deployment/backend-api backend=hashicorp/http-echo:$image_tag -n $NAMESPACE
        else
            kubectl apply -f k8s-manifests/app/backend.yaml
        fi
        
        # Wait for rollout
        print_progress "Waiting for backend rollout to complete..."
        kubectl rollout status deployment/backend-api -n $NAMESPACE --timeout=$ROLLBACK_TIMEOUT
        
        # Health check
        for i in $(seq 1 $HEALTH_CHECK_RETRIES); do
            if validate_health "backend-api" $NAMESPACE; then
                break
            fi
            if [ $i -eq $HEALTH_CHECK_RETRIES ]; then
                print_error "Backend health check failed after $HEALTH_CHECK_RETRIES attempts"
                print_error "Rolling back backend deployment..."
                kubectl rollout undo deployment/backend-api -n $NAMESPACE
                exit 1
            fi
            sleep $HEALTH_CHECK_DELAY
        done
    fi
    
    # Update frontend
    print_progress "Updating frontend deployment..."
    if [ "$dry_run" = "true" ]; then
        print_status "DRY RUN: Would update frontend deployment"
    else
        if [ -n "$image_tag" ]; then
            kubectl set image deployment/frontend frontend=nginx:$image_tag -n $NAMESPACE
        else
            kubectl apply -f k8s-manifests/app/frontend.yaml
        fi
        
        # Wait for rollout
        print_progress "Waiting for frontend rollout to complete..."
        kubectl rollout status deployment/frontend -n $NAMESPACE --timeout=$ROLLBACK_TIMEOUT
        
        # Health check
        for i in $(seq 1 $HEALTH_CHECK_RETRIES); do
            if validate_health "frontend" $NAMESPACE; then
                break
            fi
            if [ $i -eq $HEALTH_CHECK_RETRIES ]; then
                print_error "Frontend health check failed after $HEALTH_CHECK_RETRIES attempts"
                print_error "Rolling back frontend deployment..."
                kubectl rollout undo deployment/frontend -n $NAMESPACE
                exit 1
            fi
            sleep $HEALTH_CHECK_DELAY
        done
    fi
    
    # Update Redis (if needed)
    print_progress "Checking Redis deployment..."
    if [ "$dry_run" = "true" ]; then
        print_status "DRY RUN: Would check Redis deployment"
    else
        kubectl apply -f k8s-manifests/app/redis.yaml
        kubectl rollout status deployment/redis -n $NAMESPACE --timeout=$ROLLBACK_TIMEOUT
    fi
    
    print_status "✅ Application update completed successfully"
}

update_monitoring() {
    local dry_run=$1
    
    print_header "Rolling Update: Monitoring Stack"
    
    # Update Prometheus
    print_progress "Updating Prometheus deployment..."
    if [ "$dry_run" = "true" ]; then
        print_status "DRY RUN: Would update Prometheus"
    else
        kubectl apply -f k8s-manifests/monitoring/prometheus-configmap.yaml
        kubectl apply -f k8s-manifests/monitoring/prometheus-deployment.yaml
        
        print_progress "Waiting for Prometheus rollout..."
        kubectl rollout status deployment/prometheus -n $MONITORING_NAMESPACE --timeout=$ROLLBACK_TIMEOUT
        
        # Health check
        for i in $(seq 1 $HEALTH_CHECK_RETRIES); do
            if validate_health "prometheus" $MONITORING_NAMESPACE; then
                break
            fi
            if [ $i -eq $HEALTH_CHECK_RETRIES ]; then
                print_error "Prometheus health check failed"
                kubectl rollout undo deployment/prometheus -n $MONITORING_NAMESPACE
                exit 1
            fi
            sleep $HEALTH_CHECK_DELAY
        done
    fi
    
    # Update Grafana
    print_progress "Updating Grafana deployment..."
    if [ "$dry_run" = "true" ]; then
        print_status "DRY RUN: Would update Grafana"
    else
        kubectl apply -f k8s-manifests/monitoring/grafana-configmap.yaml
        kubectl apply -f k8s-manifests/monitoring/grafana-deployment.yaml
        
        print_progress "Waiting for Grafana rollout..."
        kubectl rollout status deployment/grafana -n $MONITORING_NAMESPACE --timeout=$ROLLBACK_TIMEOUT
        
        # Health check
        for i in $(seq 1 $HEALTH_CHECK_RETRIES); do
            if validate_health "grafana" $MONITORING_NAMESPACE; then
                break
            fi
            if [ $i -eq $HEALTH_CHECK_RETRIES ]; then
                print_error "Grafana health check failed"
                kubectl rollout undo deployment/grafana -n $MONITORING_NAMESPACE
                exit 1
            fi
            sleep $HEALTH_CHECK_DELAY
        done
    fi
    
    print_status "✅ Monitoring stack update completed successfully"
}

update_sre_practices() {
    local dry_run=$1
    
    print_header "Rolling Update: SRE Practices"
    
    if [ "$dry_run" = "true" ]; then
        print_status "DRY RUN: Would update SRE practices"
        return 0
    fi
    
    # Update SLO monitoring
    print_progress "Updating SLO definitions..."
    kubectl apply -f k8s-manifests/sre-practices/slo-monitoring/
    
    # Update alerting
    print_progress "Updating alerting configuration..."
    kubectl apply -f k8s-manifests/sre-practices/alerting/
    
    # Restart AlertManager if config changed
    print_progress "Restarting AlertManager to load new config..."
    kubectl rollout restart deployment/alertmanager -n $MONITORING_NAMESPACE
    kubectl rollout status deployment/alertmanager -n $MONITORING_NAMESPACE --timeout=$ROLLBACK_TIMEOUT
    
    # Update chaos testing
    print_progress "Updating chaos testing..."
    kubectl apply -f k8s-manifests/sre-practices/chaos-testing/
    
    # Restart Prometheus to load new rules
    print_progress "Restarting Prometheus to load new SLO rules..."
    kubectl rollout restart deployment/prometheus -n $MONITORING_NAMESPACE
    kubectl rollout status deployment/prometheus -n $MONITORING_NAMESPACE --timeout=$ROLLBACK_TIMEOUT
    
    print_status "✅ SRE practices update completed successfully"
}

update_infrastructure() {
    local dry_run=$1
    
    print_header "Rolling Update: Infrastructure"
    
    print_warning "Infrastructure updates require careful planning!"
    print_warning "This will run 'terraform plan' and 'terraform apply'"
    
    if [ "$dry_run" = "true" ]; then
        print_status "DRY RUN: Would run terraform plan"
        return 0
    fi
    
    cd terraform
    
    print_progress "Running terraform plan..."
    if ! terraform plan; then
        print_error "Terraform plan failed"
        exit 1
    fi
    
    print_warning "Review the plan above. Continue with terraform apply? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_status "Infrastructure update cancelled"
        cd ..
        return 0
    fi
    
    print_progress "Running terraform apply..."
    if ! terraform apply -auto-approve; then
        print_error "Terraform apply failed"
        exit 1
    fi
    
    cd ..
    print_status "✅ Infrastructure update completed successfully"
}

rollback_deployment() {
    local component=$1
    local namespace=$2
    
    print_header "Rolling Back: $component"
    
    print_progress "Rolling back $component deployment..."
    kubectl rollout undo deployment/$component -n $namespace
    
    print_progress "Waiting for rollback to complete..."
    kubectl rollout status deployment/$component -n $namespace --timeout=$ROLLBACK_TIMEOUT
    
    # Health check after rollback
    for i in $(seq 1 $HEALTH_CHECK_RETRIES); do
        if validate_health "$component" "$namespace"; then
            print_status "✅ Rollback completed successfully"
            return 0
        fi
        if [ $i -eq $HEALTH_CHECK_RETRIES ]; then
            print_error "Health check failed after rollback"
            exit 1
        fi
        sleep $HEALTH_CHECK_DELAY
    done
}

monitor_traffic_during_update() {
    print_header "Traffic Monitoring"
    
    # Get frontend service URL
    local frontend_ip=$(kubectl get service frontend-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ -n "$frontend_ip" ]; then
        print_status "Monitoring traffic to: http://$frontend_ip"
        
        # Monitor for 60 seconds
        for i in {1..12}; do
            local status_code=$(curl -s -o /dev/null -w "%{http_code}" "http://$frontend_ip" || echo "000")
            if [ "$status_code" = "200" ]; then
                echo -ne "\r${GREEN}✅${NC} Response: $status_code ($(date '+%H:%M:%S'))"
            else
                echo -ne "\r${RED}❌${NC} Response: $status_code ($(date '+%H:%M:%S'))"
            fi
            sleep 5
        done
        echo
    else
        print_warning "Frontend service not accessible for traffic monitoring"
    fi
}

# Parse command line arguments
COMPONENT=""
IMAGE_TAG=""
DRY_RUN=false
FORCE=false
ROLLBACK=false
CHECK_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        app|monitoring|sre-practices|infrastructure|all)
            COMPONENT="$1"
            shift
            ;;
        --image-tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --rollback)
            ROLLBACK=true
            shift
            ;;
        --check-only)
            CHECK_ONLY=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
print_header "SRE Lab Rolling Update - Zero Downtime Deployment"

if [ -z "$COMPONENT" ]; then
    show_usage
    exit 1
fi

check_prerequisites

if [ "$CHECK_ONLY" = "true" ]; then
    get_current_versions
    check_slo_compliance
    exit 0
fi

if [ "$ROLLBACK" = "true" ]; then
    case $COMPONENT in
        app)
            rollback_deployment "backend-api" $NAMESPACE
            rollback_deployment "frontend" $NAMESPACE
            ;;
        monitoring)
            rollback_deployment "prometheus" $MONITORING_NAMESPACE
            rollback_deployment "grafana" $MONITORING_NAMESPACE
            ;;
        *)
            print_error "Rollback not supported for component: $COMPONENT"
            exit 1
            ;;
    esac
    exit 0
fi

get_current_versions

if [ "$FORCE" != "true" ] && [ "$DRY_RUN" != "true" ]; then
    print_warning "This will perform a rolling update of: $COMPONENT"
    print_warning "Continue? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_status "Update cancelled"
        exit 0
    fi
fi

# Start traffic monitoring in background
if [ "$COMPONENT" = "app" ] || [ "$COMPONENT" = "all" ]; then
    monitor_traffic_during_update &
    MONITOR_PID=$!
fi

# Execute updates based on component
case $COMPONENT in
    app)
        update_application "$IMAGE_TAG" "$DRY_RUN"
        ;;
    monitoring)
        update_monitoring "$DRY_RUN"
        ;;
    sre-practices)
        update_sre_practices "$DRY_RUN"
        ;;
    infrastructure)
        update_infrastructure "$DRY_RUN"
        ;;
    all)
        update_application "$IMAGE_TAG" "$DRY_RUN"
        update_monitoring "$DRY_RUN"
        update_sre_practices "$DRY_RUN"
        ;;
    *)
        print_error "Unknown component: $COMPONENT"
        exit 1
        ;;
esac

# Stop traffic monitoring
if [ -n "$MONITOR_PID" ]; then
    kill $MONITOR_PID 2>/dev/null || true
fi

# Final health check
print_header "Post-Update Verification"
check_slo_compliance

print_header "Update Summary"
print_status "🎉 Rolling update completed successfully!"
print_status "📊 Run './scripts/test-sre-setup.sh' to verify everything is working"
print_status "📈 Check Grafana dashboards for SLO compliance"
print_status "🔍 Monitor application logs for any issues"

if [ "$DRY_RUN" = "true" ]; then
    print_warning "This was a DRY RUN - no actual changes were made"
fi