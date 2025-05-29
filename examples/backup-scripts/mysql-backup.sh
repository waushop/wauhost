#!/bin/bash
# MySQL Backup Script for Kubernetes
# This script backs up MySQL databases to MinIO object storage

set -euo pipefail

# Configuration
MYSQL_HOST="${MYSQL_HOST:-mysql.mysql.svc.cluster.local}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD}"
MYSQL_DATABASE="${MYSQL_DATABASE:-}"  # Empty means all databases

# MinIO Configuration
MINIO_ENDPOINT="${MINIO_ENDPOINT:-minio.minio-system.svc.cluster.local:9000}"
MINIO_BUCKET="${MINIO_BUCKET:-mysql-backups}"
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY}"

# Backup Configuration
BACKUP_PREFIX="${BACKUP_PREFIX:-mysql}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $*" >&2
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $*"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check required tools
    for cmd in mysqldump gzip mc; do
        if ! command -v $cmd &> /dev/null; then
            error "$cmd is not installed"
            exit 1
        fi
    done
    
    # Check environment variables
    if [[ -z "$MYSQL_PASSWORD" ]]; then
        error "MYSQL_PASSWORD is not set"
        exit 1
    fi
    
    if [[ -z "$MINIO_ACCESS_KEY" ]] || [[ -z "$MINIO_SECRET_KEY" ]]; then
        error "MinIO credentials are not set"
        exit 1
    fi
    
    log "Prerequisites check passed"
}

# Configure MinIO client
configure_minio() {
    log "Configuring MinIO client..."
    
    # Set up MinIO client
    mc alias set backup "http://${MINIO_ENDPOINT}" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" --api S3v4
    
    # Check if bucket exists
    if ! mc ls backup/"$MINIO_BUCKET" &> /dev/null; then
        log "Creating bucket: $MINIO_BUCKET"
        mc mb backup/"$MINIO_BUCKET"
    fi
    
    log "MinIO configured successfully"
}

# Perform MySQL backup
backup_mysql() {
    local database="${1:-}"
    local backup_file=""
    
    if [[ -n "$database" ]]; then
        backup_file="${BACKUP_PREFIX}-${database}-${TIMESTAMP}.sql.gz"
        log "Backing up database: $database"
    else
        backup_file="${BACKUP_PREFIX}-all-databases-${TIMESTAMP}.sql.gz"
        log "Backing up all databases"
        database="--all-databases"
    fi
    
    local temp_file="/tmp/${backup_file}"
    
    # Create backup
    log "Creating backup..."
    if mysqldump \
        -h "$MYSQL_HOST" \
        -P "$MYSQL_PORT" \
        -u "$MYSQL_USER" \
        -p"$MYSQL_PASSWORD" \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        $database | gzip > "$temp_file"; then
        
        local size=$(ls -lh "$temp_file" | awk '{print $5}')
        log "Backup created successfully: $backup_file ($size)"
    else
        error "Failed to create backup"
        rm -f "$temp_file"
        return 1
    fi
    
    # Upload to MinIO
    log "Uploading backup to MinIO..."
    if mc cp "$temp_file" "backup/${MINIO_BUCKET}/${backup_file}"; then
        log "Backup uploaded successfully"
        
        # Verify upload
        if mc stat "backup/${MINIO_BUCKET}/${backup_file}" &> /dev/null; then
            log "Backup verified in MinIO"
        else
            error "Failed to verify backup in MinIO"
            rm -f "$temp_file"
            return 1
        fi
    else
        error "Failed to upload backup to MinIO"
        rm -f "$temp_file"
        return 1
    fi
    
    # Clean up temp file
    rm -f "$temp_file"
    
    # Add metadata
    mc tag set "backup/${MINIO_BUCKET}/${backup_file}" "backup-type=mysql" "timestamp=${TIMESTAMP}"
    
    return 0
}

# Clean up old backups
cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days..."
    
    local cutoff_date=$(date -d "$RETENTION_DAYS days ago" +%Y%m%d 2>/dev/null || date -v -${RETENTION_DAYS}d +%Y%m%d)
    local deleted_count=0
    
    # List all backups and filter old ones
    mc ls "backup/${MINIO_BUCKET}/" | grep "${BACKUP_PREFIX}-" | while read -r line; do
        local file=$(echo "$line" | awk '{print $NF}')
        local file_date=$(echo "$file" | grep -oE '[0-9]{8}' | head -1)
        
        if [[ -n "$file_date" ]] && [[ "$file_date" -lt "$cutoff_date" ]]; then
            log "Deleting old backup: $file"
            mc rm "backup/${MINIO_BUCKET}/${file}"
            ((deleted_count++))
        fi
    done
    
    log "Cleanup completed. Deleted $deleted_count old backups"
}

# Generate backup report
generate_report() {
    log "Generating backup report..."
    
    local total_size=$(mc du "backup/${MINIO_BUCKET}/" | grep Total | awk '{print $1}')
    local backup_count=$(mc ls "backup/${MINIO_BUCKET}/" | grep -c "${BACKUP_PREFIX}-" || echo 0)
    
    cat << EOF

====================================
📊 MySQL Backup Report
====================================
Timestamp: $(date)
Host: $MYSQL_HOST
Database: ${MYSQL_DATABASE:-"All databases"}
Backup Location: $MINIO_BUCKET
Total Backups: $backup_count
Total Size: ${total_size:-"0B"}
Retention: $RETENTION_DAYS days
====================================

Recent Backups:
$(mc ls "backup/${MINIO_BUCKET}/" | grep "${BACKUP_PREFIX}-" | tail -5)

EOF
}

# Main execution
main() {
    log "Starting MySQL backup process..."
    
    # Check prerequisites
    check_prerequisites
    
    # Configure MinIO
    configure_minio
    
    # Perform backup
    if [[ -n "$MYSQL_DATABASE" ]]; then
        # Backup specific database
        if backup_mysql "$MYSQL_DATABASE"; then
            log "Database backup completed successfully"
        else
            error "Database backup failed"
            exit 1
        fi
    else
        # Backup all databases
        if backup_mysql; then
            log "All databases backup completed successfully"
        else
            error "All databases backup failed"
            exit 1
        fi
    fi
    
    # Clean up old backups
    cleanup_old_backups
    
    # Generate report
    generate_report
    
    log "✅ Backup process completed successfully"
}

# Restore function (optional)
restore_backup() {
    local backup_file="$1"
    local target_database="${2:-}"
    
    log "Restoring backup: $backup_file"
    
    # Download from MinIO
    local temp_file="/tmp/restore-${TIMESTAMP}.sql.gz"
    if ! mc cp "backup/${MINIO_BUCKET}/${backup_file}" "$temp_file"; then
        error "Failed to download backup from MinIO"
        return 1
    fi
    
    # Restore to MySQL
    log "Restoring to MySQL..."
    if [[ -n "$target_database" ]]; then
        # Restore to specific database
        gunzip < "$temp_file" | mysql \
            -h "$MYSQL_HOST" \
            -P "$MYSQL_PORT" \
            -u "$MYSQL_USER" \
            -p"$MYSQL_PASSWORD" \
            "$target_database"
    else
        # Restore all databases
        gunzip < "$temp_file" | mysql \
            -h "$MYSQL_HOST" \
            -P "$MYSQL_PORT" \
            -u "$MYSQL_USER" \
            -p"$MYSQL_PASSWORD"
    fi
    
    rm -f "$temp_file"
    log "Restore completed successfully"
}

# Handle script arguments
case "${1:-backup}" in
    backup)
        main
        ;;
    restore)
        if [[ -z "${2:-}" ]]; then
            error "Usage: $0 restore <backup-file> [target-database]"
            exit 1
        fi
        check_prerequisites
        configure_minio
        restore_backup "$2" "${3:-}"
        ;;
    list)
        configure_minio
        mc ls "backup/${MINIO_BUCKET}/" | grep "${BACKUP_PREFIX}-"
        ;;
    *)
        echo "Usage: $0 {backup|restore|list}"
        exit 1
        ;;
esac