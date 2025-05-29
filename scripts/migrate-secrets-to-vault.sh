#!/bin/bash

# =============================================================================
# SECRET MIGRATION SCRIPT
# Migrate existing Kubernetes secrets to HashiCorp Vault
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VAULT_NAMESPACE="vault"
VAULT_SERVICE="vault.vault.svc.cluster.local:8200"
VAULT_ADDR="https://${VAULT_SERVICE}"

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is required but not installed"
        exit 1
    fi
    
    # Check vault CLI (optional, we'll use kubectl exec)
    if ! command -v vault &> /dev/null; then
        log_warning "vault CLI not found, will use kubectl exec to vault pod"
    fi
    
    # Check if vault namespace exists
    if ! kubectl get namespace "$VAULT_NAMESPACE" &> /dev/null; then
        log_error "Vault namespace '$VAULT_NAMESPACE' not found"
        log_info "Please deploy the external-secrets chart first"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Function to get vault pod name
get_vault_pod() {
    kubectl get pods -n "$VAULT_NAMESPACE" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || {
        log_error "Vault pod not found in namespace '$VAULT_NAMESPACE'"
        exit 1
    }
}

# Function to check if vault is unsealed
check_vault_status() {
    local vault_pod="$1"
    log_info "Checking Vault status..."
    
    if kubectl exec -n "$VAULT_NAMESPACE" "$vault_pod" -- vault status &> /dev/null; then
        log_success "Vault is unsealed and ready"
        return 0
    else
        log_error "Vault is sealed or not ready"
        log_info "Please unseal Vault first"
        return 1
    fi
}

# Function to extract secret from Kubernetes
extract_k8s_secret() {
    local namespace="$1"
    local secret_name="$2"
    local key="$3"
    
    kubectl get secret "$secret_name" -n "$namespace" -o jsonpath="{.data.$key}" 2>/dev/null | base64 -d 2>/dev/null || {
        log_error "Failed to extract secret '$secret_name.$key' from namespace '$namespace'"
        return 1
    }
}

# Function to store secret in Vault
store_vault_secret() {
    local vault_pod="$1"
    local vault_path="$2"
    local key="$3"
    local value="$4"
    
    log_info "Storing secret at path: $vault_path"
    
    # Store secret in Vault
    if kubectl exec -n "$VAULT_NAMESPACE" "$vault_pod" -- \
        vault kv put "$vault_path" "$key"="$value" &> /dev/null; then
        log_success "Secret stored at $vault_path"
        return 0
    else
        log_error "Failed to store secret at $vault_path"
        return 1
    fi
}

# Function to verify secret in Vault
verify_vault_secret() {
    local vault_pod="$1"
    local vault_path="$2"
    local key="$3"
    
    log_info "Verifying secret at path: $vault_path"
    
    if kubectl exec -n "$VAULT_NAMESPACE" "$vault_pod" -- \
        vault kv get -field="$key" "$vault_path" &> /dev/null; then
        log_success "Secret verified at $vault_path"
        return 0
    else
        log_error "Failed to verify secret at $vault_path"
        return 1
    fi
}

# Function to migrate MySQL secrets
migrate_mysql_secrets() {
    local vault_pod="$1"
    
    log_info "Migrating MySQL secrets..."
    
    # Extract MySQL root password
    local mysql_root_password
    if mysql_root_password=$(extract_k8s_secret "mysql" "mysql-secret" "mysql-root-password"); then
        log_success "Extracted MySQL root password"
        
        # Store in Vault
        store_vault_secret "$vault_pod" "secret/wauhost/mysql/root-password" "password" "$mysql_root_password"
        verify_vault_secret "$vault_pod" "secret/wauhost/mysql/root-password" "password"
        
        # Also store as user password (vausiim user password)
        store_vault_secret "$vault_pod" "secret/wauhost/mysql/user-password" "password" "$mysql_root_password"
        verify_vault_secret "$vault_pod" "secret/wauhost/mysql/user-password" "password"
        
        # Store as Ghost database password
        store_vault_secret "$vault_pod" "secret/wauhost/ghost/db-password" "password" "$mysql_root_password"
        verify_vault_secret "$vault_pod" "secret/wauhost/ghost/db-password" "password"
        
        # Store as WordPress database password
        store_vault_secret "$vault_pod" "secret/wauhost/wordpress/db-password" "password" "$mysql_root_password"
        verify_vault_secret "$vault_pod" "secret/wauhost/wordpress/db-password" "password"
        
    else
        log_error "Failed to extract MySQL root password"
        return 1
    fi
}

# Function to migrate Mailgun secrets
migrate_mailgun_secrets() {
    local vault_pod="$1"
    
    log_info "Migrating Mailgun secrets..."
    
    # Extract mail user
    local mail_user
    if mail_user=$(extract_k8s_secret "vausiim" "mailgun-secret" "mail_user"); then
        log_success "Extracted mail user: $mail_user"
        
        # Store mail user info (not secret, but useful)
        store_vault_secret "$vault_pod" "secret/wauhost/ghost/mail-user" "user" "$mail_user"
        verify_vault_secret "$vault_pod" "secret/wauhost/ghost/mail-user" "user"
    fi
    
    # Extract mail password
    local mail_password
    if mail_password=$(extract_k8s_secret "vausiim" "mailgun-secret" "mail_pass"); then
        log_success "Extracted mail password"
        
        # Store in Vault
        store_vault_secret "$vault_pod" "secret/wauhost/ghost/mail-password" "password" "$mail_password"
        verify_vault_secret "$vault_pod" "secret/wauhost/ghost/mail-password" "password"
        
    else
        log_error "Failed to extract Mailgun password"
        return 1
    fi
}

# Function to create additional production secrets
create_additional_secrets() {
    local vault_pod="$1"
    
    log_info "Creating additional production-ready secrets..."
    
    # Generate MySQL replication password
    local repl_password
    repl_password="repl-$(openssl rand -hex 16)"
    store_vault_secret "$vault_pod" "secret/wauhost/mysql/replication-password" "password" "$repl_password"
    verify_vault_secret "$vault_pod" "secret/wauhost/mysql/replication-password" "password"
    
    # Create MinIO secrets (generate new ones)
    local minio_user="minioadmin"
    local minio_password
    minio_password="minio-$(openssl rand -hex 16)"
    
    store_vault_secret "$vault_pod" "secret/wauhost/minio/root-user" "user" "$minio_user"
    verify_vault_secret "$vault_pod" "secret/wauhost/minio/root-user" "user"
    
    store_vault_secret "$vault_pod" "secret/wauhost/minio/root-password" "password" "$minio_password"
    verify_vault_secret "$vault_pod" "secret/wauhost/minio/root-password" "password"
    
    # Create backup access keys
    local backup_access_key
    local backup_secret_key
    backup_access_key="backup-$(openssl rand -hex 8)"
    backup_secret_key="backup-$(openssl rand -hex 16)"
    
    store_vault_secret "$vault_pod" "secret/wauhost/minio/backup-access-key" "key" "$backup_access_key"
    verify_vault_secret "$vault_pod" "secret/wauhost/minio/backup-access-key" "key"
    
    store_vault_secret "$vault_pod" "secret/wauhost/minio/backup-secret-key" "key" "$backup_secret_key"
    verify_vault_secret "$vault_pod" "secret/wauhost/minio/backup-secret-key" "key"
    
    # Create Longhorn backup secrets (using MinIO keys)
    store_vault_secret "$vault_pod" "secret/wauhost/longhorn/backup-access-key" "key" "$backup_access_key"
    verify_vault_secret "$vault_pod" "secret/wauhost/longhorn/backup-access-key" "key"
    
    store_vault_secret "$vault_pod" "secret/wauhost/longhorn/backup-secret-key" "key" "$backup_secret_key"
    verify_vault_secret "$vault_pod" "secret/wauhost/longhorn/backup-secret-key" "key"
    
    # Create Longhorn UI auth (admin/admin for now - change later)
    local longhorn_auth
    longhorn_auth=$(htpasswd -nb admin admin 2>/dev/null || echo "admin:\$2y\$10\$0123456789abcdef")
    store_vault_secret "$vault_pod" "secret/wauhost/longhorn/ui-auth" "auth" "$longhorn_auth"
    verify_vault_secret "$vault_pod" "secret/wauhost/longhorn/ui-auth" "auth"
    
    # Create cert-manager email
    local cert_email="admin@waushop.ee"
    store_vault_secret "$vault_pod" "secret/wauhost/cert-manager/email" "email" "$cert_email"
    verify_vault_secret "$vault_pod" "secret/wauhost/cert-manager/email" "email"
    
    # Create monitoring webhook URL (placeholder)
    local webhook_url="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
    store_vault_secret "$vault_pod" "secret/wauhost/monitoring/webhook-url" "url" "$webhook_url"
    verify_vault_secret "$vault_pod" "secret/wauhost/monitoring/webhook-url" "url"
}

# Function to display migration summary
display_summary() {
    local vault_pod="$1"
    
    log_info "Migration Summary:"
    echo ""
    echo "🔐 Secrets successfully migrated to Vault:"
    echo ""
    echo "   MySQL Secrets:"
    echo "   - secret/wauhost/mysql/root-password"
    echo "   - secret/wauhost/mysql/user-password"
    echo "   - secret/wauhost/mysql/replication-password"
    echo ""
    echo "   Ghost Secrets:"
    echo "   - secret/wauhost/ghost/db-password"
    echo "   - secret/wauhost/ghost/mail-password"
    echo "   - secret/wauhost/ghost/mail-user"
    echo ""
    echo "   WordPress Secrets:"
    echo "   - secret/wauhost/wordpress/db-password"
    echo ""
    echo "   MinIO Secrets:"
    echo "   - secret/wauhost/minio/root-user"
    echo "   - secret/wauhost/minio/root-password"
    echo "   - secret/wauhost/minio/backup-access-key"
    echo "   - secret/wauhost/minio/backup-secret-key"
    echo ""
    echo "   Longhorn Secrets:"
    echo "   - secret/wauhost/longhorn/backup-access-key"
    echo "   - secret/wauhost/longhorn/backup-secret-key"
    echo "   - secret/wauhost/longhorn/ui-auth"
    echo ""
    echo "   Other Secrets:"
    echo "   - secret/wauhost/cert-manager/email"
    echo "   - secret/wauhost/monitoring/webhook-url"
    echo ""
    
    # Test listing secrets
    log_info "Testing Vault secret access..."
    if kubectl exec -n "$VAULT_NAMESPACE" "$vault_pod" -- \
        vault kv list secret/wauhost/ &> /dev/null; then
        echo "✅ Vault secrets are accessible"
        echo ""
        echo "📝 Next steps:"
        echo "   1. Deploy external-secrets chart to set up External Secrets Operator"
        echo "   2. Deploy your applications - they will automatically get secrets from Vault"
        echo "   3. Update webhook URL in: secret/wauhost/monitoring/webhook-url"
        echo "   4. Update Longhorn UI password in: secret/wauhost/longhorn/ui-auth"
        echo ""
    else
        log_warning "Unable to list Vault secrets - check Vault permissions"
    fi
}

# Main function
main() {
    echo "🔐 Kubernetes to Vault Secret Migration"
    echo "======================================"
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Get vault pod
    local vault_pod
    vault_pod=$(get_vault_pod)
    log_success "Found Vault pod: $vault_pod"
    
    # Check vault status
    if ! check_vault_status "$vault_pod"; then
        exit 1
    fi
    
    # Migrate secrets
    log_info "Starting secret migration..."
    echo ""
    
    migrate_mysql_secrets "$vault_pod"
    echo ""
    
    migrate_mailgun_secrets "$vault_pod"
    echo ""
    
    create_additional_secrets "$vault_pod"
    echo ""
    
    # Display summary
    display_summary "$vault_pod"
    
    log_success "Secret migration completed successfully! 🎉"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--dry-run]"
        echo ""
        echo "Migrate existing Kubernetes secrets to HashiCorp Vault"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --dry-run      Show what would be migrated without making changes"
        echo ""
        exit 0
        ;;
    --dry-run)
        log_info "DRY RUN MODE - No changes will be made"
        # TODO: Implement dry-run functionality
        log_warning "Dry-run mode not yet implemented"
        exit 0
        ;;
    "")
        # Run normally
        main
        ;;
    *)
        log_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
