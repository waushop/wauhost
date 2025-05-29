#!/bin/bash
# Health Check Script
# Checks the health of all deployed wauhost components

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Components to check
declare -A COMPONENTS=(
    ["external-secrets"]="external-secrets-system"
    ["cert-manager"]="cert-manager"
    ["longhorn"]="longhorn-system"
    ["minio"]="minio-system"
    ["mysql"]="mysql"
    ["wordpress"]="wordpress"
    ["ghost"]="ghost"
    ["monitoring"]="monitoring"
)

# Health check results
declare -A HEALTH_STATUS
declare -A HEALTH_DETAILS
OVERALL_HEALTH="healthy"

echo "🏥 Wauhost Infrastructure Health Check"
echo "====================================="
echo "Timestamp: $(date)"
echo ""

# Function to check pod health
check_pods() {
    local namespace="$1"
    local component="$2"
    
    echo -e "📦 Checking ${BLUE}$component${NC} in namespace ${BLUE}$namespace${NC}..."
    
    # Check if namespace exists
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        echo -e "  ${RED}❌ Namespace does not exist${NC}"
        HEALTH_STATUS[$component]="missing"
        HEALTH_DETAILS[$component]="Namespace $namespace not found"
        OVERALL_HEALTH="unhealthy"
        return 1
    fi
    
    # Get pod status
    local pod_info=$(kubectl get pods -n "$namespace" -o json 2>/dev/null)
    
    if [[ -z "$pod_info" ]] || [[ $(echo "$pod_info" | jq '.items | length') -eq 0 ]]; then
        echo -e "  ${YELLOW}⚠️  No pods found${NC}"
        HEALTH_STATUS[$component]="warning"
        HEALTH_DETAILS[$component]="No pods in namespace"
        return 0
    fi
    
    # Check each pod
    local total_pods=$(echo "$pod_info" | jq '.items | length')
    local ready_pods=0
    local not_ready_pods=()
    local restart_counts=()
    
    for i in $(seq 0 $((total_pods - 1))); do
        local pod_name=$(echo "$pod_info" | jq -r ".items[$i].metadata.name")
        local ready=$(echo "$pod_info" | jq -r ".items[$i].status.conditions[] | select(.type==\"Ready\") | .status")
        local phase=$(echo "$pod_info" | jq -r ".items[$i].status.phase")
        local restarts=$(echo "$pod_info" | jq -r "[.items[$i].status.containerStatuses[]?.restartCount // 0] | add")
        
        if [[ "$ready" == "True" ]] && [[ "$phase" == "Running" ]]; then
            ((ready_pods++))
        else
            not_ready_pods+=("$pod_name (Phase: $phase)")
        fi
        
        if [[ "$restarts" -gt 5 ]]; then
            restart_counts+=("$pod_name: $restarts restarts")
        fi
    done
    
    echo -e "  Pods: ${ready_pods}/${total_pods} ready"
    
    # Determine health status
    if [[ $ready_pods -eq $total_pods ]]; then
        echo -e "  ${GREEN}✓ All pods are healthy${NC}"
        HEALTH_STATUS[$component]="healthy"
        HEALTH_DETAILS[$component]="All $total_pods pods running"
    else
        echo -e "  ${YELLOW}⚠️  Some pods are not ready${NC}"
        for pod in "${not_ready_pods[@]}"; do
            echo -e "    - $pod"
        done
        HEALTH_STATUS[$component]="degraded"
        HEALTH_DETAILS[$component]="${ready_pods}/${total_pods} pods ready"
        OVERALL_HEALTH="degraded"
    fi
    
    # Check for high restart counts
    if [[ ${#restart_counts[@]} -gt 0 ]]; then
        echo -e "  ${YELLOW}⚠️  High restart counts detected:${NC}"
        for restart in "${restart_counts[@]}"; do
            echo -e "    - $restart"
        done
        OVERALL_HEALTH="degraded"
    fi
    
    return 0
}

# Function to check storage
check_storage() {
    echo -e "\n💾 Checking Storage Health..."
    
    # Check Longhorn volumes
    if kubectl get volumes.longhorn.io -n longhorn-system &> /dev/null; then
        local volume_count=$(kubectl get volumes.longhorn.io -n longhorn-system -o json | jq '.items | length')
        local healthy_volumes=$(kubectl get volumes.longhorn.io -n longhorn-system -o json | jq '[.items[] | select(.status.state=="attached" or .status.state=="detached")] | length')
        
        echo -e "  Longhorn Volumes: ${healthy_volumes}/${volume_count} healthy"
        
        if [[ $healthy_volumes -lt $volume_count ]]; then
            echo -e "  ${YELLOW}⚠️  Some volumes are not healthy${NC}"
            kubectl get volumes.longhorn.io -n longhorn-system -o json | jq -r '.items[] | select(.status.state!="attached" and .status.state!="detached") | "    - \(.metadata.name): \(.status.state)"'
            OVERALL_HEALTH="degraded"
        fi
    else
        echo -e "  ${YELLOW}⚠️  Cannot check Longhorn volumes${NC}"
    fi
    
    # Check PVCs
    local pvc_info=$(kubectl get pvc -A -o json)
    local total_pvcs=$(echo "$pvc_info" | jq '.items | length')
    local bound_pvcs=$(echo "$pvc_info" | jq '[.items[] | select(.status.phase=="Bound")] | length')
    
    echo -e "  PVCs: ${bound_pvcs}/${total_pvcs} bound"
    
    if [[ $bound_pvcs -lt $total_pvcs ]]; then
        echo -e "  ${YELLOW}⚠️  Some PVCs are not bound${NC}"
        echo "$pvc_info" | jq -r '.items[] | select(.status.phase!="Bound") | "    - \(.metadata.namespace)/\(.metadata.name): \(.status.phase)"'
        OVERALL_HEALTH="degraded"
    fi
}

# Function to check certificates
check_certificates() {
    echo -e "\n🔐 Checking Certificates..."
    
    if ! kubectl get certificates -A &> /dev/null; then
        echo -e "  ${YELLOW}⚠️  cert-manager CRDs not found${NC}"
        return
    fi
    
    local cert_info=$(kubectl get certificates -A -o json)
    local total_certs=$(echo "$cert_info" | jq '.items | length')
    
    if [[ $total_certs -eq 0 ]]; then
        echo -e "  No certificates configured"
        return
    fi
    
    local ready_certs=$(echo "$cert_info" | jq '[.items[] | select(.status.conditions[]? | select(.type=="Ready" and .status=="True"))] | length')
    
    echo -e "  Certificates: ${ready_certs}/${total_certs} ready"
    
    # Check for expiring certificates
    local expiring_soon=()
    for i in $(seq 0 $((total_certs - 1))); do
        local cert_name=$(echo "$cert_info" | jq -r ".items[$i].metadata.name")
        local cert_ns=$(echo "$cert_info" | jq -r ".items[$i].metadata.namespace")
        local not_after=$(echo "$cert_info" | jq -r ".items[$i].status.notAfter // empty")
        
        if [[ -n "$not_after" ]]; then
            local expiry_epoch=$(date -d "$not_after" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$not_after" +%s 2>/dev/null)
            local current_epoch=$(date +%s)
            local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
            
            if [[ $days_until_expiry -lt 30 ]]; then
                expiring_soon+=("$cert_ns/$cert_name: expires in $days_until_expiry days")
            fi
        fi
    done
    
    if [[ ${#expiring_soon[@]} -gt 0 ]]; then
        echo -e "  ${YELLOW}⚠️  Certificates expiring soon:${NC}"
        for cert in "${expiring_soon[@]}"; do
            echo -e "    - $cert"
        done
        OVERALL_HEALTH="degraded"
    fi
}

# Function to check services
check_services() {
    echo -e "\n🌐 Checking Service Endpoints..."
    
    # Check MinIO
    if kubectl get svc -n minio-system minio &> /dev/null; then
        echo -e "  MinIO API: checking..."
        if kubectl exec -n minio-system deployment/minio -- curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/minio/health/live | grep -q "200"; then
            echo -e "  ${GREEN}✓ MinIO API is responsive${NC}"
        else
            echo -e "  ${RED}❌ MinIO API is not responding${NC}"
            OVERALL_HEALTH="unhealthy"
        fi
    fi
    
    # Check MySQL
    if kubectl get svc -n mysql mysql &> /dev/null; then
        echo -e "  MySQL: checking..."
        if kubectl exec -n mysql deployment/mysql -- mysqladmin ping &> /dev/null; then
            echo -e "  ${GREEN}✓ MySQL is responsive${NC}"
        else
            echo -e "  ${RED}❌ MySQL is not responding${NC}"
            OVERALL_HEALTH="unhealthy"
        fi
    fi
}

# Function to check backups
check_backups() {
    echo -e "\n💾 Checking Backup Status..."
    
    # Check CronJobs
    local cronjob_info=$(kubectl get cronjobs -A -o json | jq '.items[] | select(.metadata.name | contains("backup"))')
    
    if [[ -n "$cronjob_info" ]]; then
        echo "$cronjob_info" | jq -r '"  - \(.metadata.namespace)/\(.metadata.name): Last run \(.status.lastScheduleTime // "never")"'
    else
        echo -e "  No backup cronjobs found"
    fi
}

# Main health check
echo "🔍 Starting health checks..."
echo ""

# Check each component
for component in "${!COMPONENTS[@]}"; do
    check_pods "${COMPONENTS[$component]}" "$component"
    echo ""
done

# Additional checks
check_storage
check_certificates
check_services
check_backups

# Summary
echo -e "\n=============================="
echo "📊 Health Check Summary"
echo "=============================="

# Component status summary
echo -e "\n📦 Component Status:"
for component in "${!HEALTH_STATUS[@]}"; do
    local status="${HEALTH_STATUS[$component]}"
    local details="${HEALTH_DETAILS[$component]}"
    
    case $status in
        "healthy")
            echo -e "  ${GREEN}✓${NC} $component: $details"
            ;;
        "degraded")
            echo -e "  ${YELLOW}⚠️${NC}  $component: $details"
            ;;
        "unhealthy"|"missing")
            echo -e "  ${RED}❌${NC} $component: $details"
            ;;
        *)
            echo -e "  ${YELLOW}?${NC} $component: Unknown status"
            ;;
    esac
done

# Overall health
echo -e "\n🏥 Overall Health Status:"
case $OVERALL_HEALTH in
    "healthy")
        echo -e "  ${GREEN}✅ HEALTHY - All systems operational${NC}"
        exit 0
        ;;
    "degraded")
        echo -e "  ${YELLOW}⚠️  DEGRADED - Some issues detected${NC}"
        exit 1
        ;;
    "unhealthy")
        echo -e "  ${RED}❌ UNHEALTHY - Critical issues detected${NC}"
        exit 2
        ;;
esac

echo -e "\n✨ Health check complete!"