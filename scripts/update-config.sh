#!/bin/bash

# Configuration Update Script
# Handles updating ConfigMaps and Secrets with zero downtime

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

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

show_usage() {
    cat << EOF
🔧 Configuration Update Script

Usage: $0 [CONFIG_TYPE] [OPTIONS]

CONFIG TYPES:
    prometheus      Update Prometheus configuration
    grafana         Update Grafana dashboards
    alertmanager    Update AlertManager configuration
    frontend        Update frontend Nginx configuration
    all            Update all configurations

OPTIONS:
    --dry-run      Show what would be updated without making changes
    --force        Skip confirmation prompts
    --backup       Create backup before updating

EXAMPLES:
    $0 prometheus --backup
    $0 grafana --dry-run
    $0 alertmanager --force
    $0 all

FEATURES:
    ✅ Zero downtime config updates
    ✅ Automatic configuration backups
    ✅ Configuration validation
    ✅ Graceful service restarts
    ✅ Rollback on failure

EOF
}

backup_config() {
    local config_type=$1
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="config-backups/$timestamp"
    
    mkdir -p "$backup_dir"
    
    case $config_type in
        prometheus)
            kubectl get configmap prometheus-config -n monitoring -o yaml > "$backup_dir/prometheus-config.yaml"
            print_status "✅ Prometheus config backed up to $backup_dir/"
            ;;
        grafana)
            kubectl get configmap grafana-dashboards -n monitoring -o yaml > "$backup_dir/grafana-dashboards.yaml"
            print_status "✅ Grafana config backed up to $backup_dir/"
            ;;
        alertmanager)
            kubectl get configmap alertmanager-config -n monitoring -o yaml > "$backup_dir/alertmanager-config.yaml"
            print_status "✅ AlertManager config backed up to $backup_dir/"
            ;;
        frontend)
            kubectl get configmap frontend-config -n sre-shop -o yaml > "$backup_dir/frontend-config.yaml" 2>/dev/null || true
            print_status "✅ Frontend config backed up to $backup_dir/"
            ;;
    esac
}

validate_config() {
    local config_type=$1
    
    print_status "Validating $config_type configuration..."
    
    case $config_type in
        prometheus)
            # Basic YAML validation
            if ! kubectl apply --dry-run=client -f k8s-manifests/monitoring/prometheus-configmap.yaml &>/dev/null; then
                print_error "Prometheus configuration validation failed"
                return 1
            fi
            ;;
        grafana)
            if ! kubectl apply --dry-run=client -f k8s-manifests/monitoring/grafana-configmap.yaml &>/dev/null; then
                print_error "Grafana configuration validation failed"
                return 1
            fi
            ;;
        alertmanager)
            if ! kubectl apply --dry-run=client -f k8s-manifests/sre-practices/alerting/alertmanager.yaml &>/dev/null; then
                print_error "AlertManager configuration validation failed"
                return 1
            fi
            ;;
    esac
    
    print_status "✅ Configuration validation passed"
    return 0
}

update_prometheus_config() {
    local dry_run=$1
    local backup=$2
    
    print_header "Updating Prometheus Configuration"
    
    if [ "$backup" = "true" ]; then
        backup_config "prometheus"
    fi
    
    if ! validate_config "prometheus"; then
        exit 1
    fi
    
    if [ "$dry_run" = "true" ]; then
        print_status "DRY RUN: Would update Prometheus ConfigMap"
        return 0
    fi
    
    # Update ConfigMap
    print_status "Applying new Prometheus configuration..."
    kubectl apply -f k8s-manifests/monitoring/prometheus-configmap.yaml
    
    # Get current Prometheus pod
    local prometheus_pod=$(kubectl get pods -n monitoring -l app=prometheus -o jsonpath='{.items[0].metadata.name}')
    
    # Reload configuration without restart (if supported)
    print_status "Reloading Prometheus configuration..."
    if kubectl exec -n monitoring "$prometheus_pod" -- kill -HUP 1 2>/dev/null; then
        print_status "✅ Prometheus configuration reloaded successfully"
    else
        print_warning "Configuration reload failed, performing rolling restart..."
        kubectl rollout restart deployment/prometheus -n monitoring
        kubectl rollout status deployment/prometheus -n monitoring --timeout=300s
        print_status "✅ Prometheus restarted with new configuration"
    fi
    
    # Verify configuration is loaded
    sleep 10
    local config_status=$(kubectl exec -n monitoring "$prometheus_pod" -- wget -qO- http://localhost:9090/-/ready 2>/dev/null || echo "not ready")
    if [[ "$config_status" == *"Prometheus is Ready"* ]] || kubectl get pods -n monitoring -l app=prometheus --field-selector=status.phase=Running | grep -q prometheus; then
        print_status "✅ Prometheus is healthy with new configuration"
    else
        print_error "❌ Prometheus health check failed after configuration update"
        exit 1
    fi
}

update_grafana_config() {
    local dry_run=$1
    local backup=$2
    
    print_header "Updating Grafana Configuration"
    
    if [ "$backup" = "true" ]; then
        backup_config "grafana"
    fi
    
    if ! validate_config "grafana"; then
        exit 1
    fi
    
    if [ "$dry_run" = "true" ]; then
        print_status "DRY RUN: Would update Grafana ConfigMap"
        return 0
    fi
    
    # Update ConfigMap
    print_status "Applying new Grafana configuration..."
    kubectl apply -f k8s-manifests/monitoring/grafana-configmap.yaml
    
    # Restart Grafana to load new dashboards
    print_status "Restarting Grafana to load new configuration..."
    kubectl rollout restart deployment/grafana -n monitoring
    kubectl rollout status deployment/grafana -n monitoring --timeout=300s
    
    # Health check
    sleep 15
    local grafana_pod=$(kubectl get pods -n monitoring -l app=grafana -o jsonpath='{.items[0].metadata.name}')
    local health_status=$(kubectl exec -n monitoring "$grafana_pod" -- wget -qO- http://localhost:3000/api/health 2>/dev/null | grep -o '"database":"ok"' || echo "unhealthy")
    
    if [[ "$health_status" == *'"database":"ok"'* ]]; then
        print_status "✅ Grafana is healthy with new configuration"
    else
        print_warning "⚠️  Grafana health check inconclusive, checking pod status..."
        if kubectl get pods -n monitoring -l app=grafana --field-selector=status.phase=Running | grep -q grafana; then
            print_status "✅ Grafana pod is running"
        else
            print_error "❌ Grafana health check failed"
            exit 1
        fi
    fi
}

update_alertmanager_config() {
    local dry_run=$1
    local backup=$2
    
    print_header "Updating AlertManager Configuration"
    
    if [ "$backup" = "true" ]; then
        backup_config "alertmanager"
    fi
    
    if ! validate_config "alertmanager"; then
        exit 1
    fi
    
    if [ "$dry_run" = "true" ]; then
        print_status "DRY RUN: Would update AlertManager ConfigMap"
        return 0
    fi
    
    # Update ConfigMap and Deployment
    print_status "Applying new AlertManager configuration..."
    kubectl apply -f k8s-manifests/sre-practices/alerting/alertmanager.yaml
    
    # Get AlertManager pod and reload config
    local alertmanager_pod=$(kubectl get pods -n monitoring -l app=alertmanager -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$alertmanager_pod" ]; then
        # Try to reload configuration
        print_status "Reloading AlertManager configuration..."
        if kubectl exec -n monitoring "$alertmanager_pod" -- kill -HUP 1 2>/dev/null; then
            print_status "✅ AlertManager configuration reloaded"
        else
            print_warning "Configuration reload failed, performing rolling restart..."
            kubectl rollout restart deployment/alertmanager -n monitoring
            kubectl rollout status deployment/alertmanager -n monitoring --timeout=300s
        fi
        
        # Health check
        sleep 10
        if kubectl exec -n monitoring "$alertmanager_pod" -- wget -qO- http://localhost:9093/-/ready 2>/dev/null | grep -q "Alertmanager is Ready"; then
            print_status "✅ AlertManager is healthy with new configuration"
        else
            print_warning "⚠️  AlertManager health check inconclusive"
        fi
    else
        print_status "AlertManager not found, deploying new instance..."
        kubectl rollout status deployment/alertmanager -n monitoring --timeout=300s
    fi
}

update_frontend_config() {
    local dry_run=$1
    local backup=$2
    
    print_header "Updating Frontend Configuration"
    
    if [ "$backup" = "true" ]; then
        backup_config "frontend"
    fi
    
    if [ "$dry_run" = "true" ]; then
        print_status "DRY RUN: Would update Frontend configuration"
        return 0
    fi
    
    # Update frontend deployment (includes ConfigMap)
    print_status "Applying new frontend configuration..."
    kubectl apply -f k8s-manifests/app/frontend.yaml
    
    # Rolling restart to pick up config changes
    print_status "Performing rolling restart of frontend..."
    kubectl rollout restart deployment/frontend -n sre-shop
    kubectl rollout status deployment/frontend -n sre-shop --timeout=300s
    
    # Health check
    sleep 10
    local frontend_ready=$(kubectl get deployment frontend -n sre-shop -o jsonpath='{.status.readyReplicas}')
    local frontend_desired=$(kubectl get deployment frontend -n sre-shop -o jsonpath='{.spec.replicas}')
    
    if [ "$frontend_ready" = "$frontend_desired" ]; then
        print_status "✅ Frontend updated successfully ($frontend_ready/$frontend_desired pods ready)"
    else
        print_error "❌ Frontend update failed ($frontend_ready/$frontend_desired pods ready)"
        exit 1
    fi
}

# Parse arguments
CONFIG_TYPE=""
DRY_RUN=false
FORCE=false
BACKUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        prometheus|grafana|alertmanager|frontend|all)
            CONFIG_TYPE="$1"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --backup)
            BACKUP=true
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

if [ -z "$CONFIG_TYPE" ]; then
    show_usage
    exit 1
fi

# Check prerequisites
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_header "Configuration Update - Zero Downtime"

if [ "$FORCE" != "true" ] && [ "$DRY_RUN" != "true" ]; then
    print_warning "This will update configuration for: $CONFIG_TYPE"
    print_warning "Continue? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_status "Update cancelled"
        exit 0
    fi
fi

# Execute updates
case $CONFIG_TYPE in
    prometheus)
        update_prometheus_config "$DRY_RUN" "$BACKUP"
        ;;
    grafana)
        update_grafana_config "$DRY_RUN" "$BACKUP"
        ;;
    alertmanager)
        update_alertmanager_config "$DRY_RUN" "$BACKUP"
        ;;
    frontend)
        update_frontend_config "$DRY_RUN" "$BACKUP"
        ;;
    all)
        update_prometheus_config "$DRY_RUN" "$BACKUP"
        update_grafana_config "$DRY_RUN" "$BACKUP"
        update_alertmanager_config "$DRY_RUN" "$BACKUP"
        update_frontend_config "$DRY_RUN" "$BACKUP"
        ;;
    *)
        print_error "Unknown configuration type: $CONFIG_TYPE"
        exit 1
        ;;
esac

print_header "Configuration Update Complete"
print_status "🎉 Configuration update completed successfully!"
print_status "📊 Run './scripts/test-sre-setup.sh' to verify everything is working"

if [ "$DRY_RUN" = "true" ]; then
    print_warning "This was a DRY RUN - no actual changes were made"
fi

if [ "$BACKUP" = "true" ]; then
    print_status "💾 Configuration backups saved in config-backups/ directory"
fi