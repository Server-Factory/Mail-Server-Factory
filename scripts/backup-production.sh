#!/bin/bash

# Mail Server Factory Production Backup Script
# Creates comprehensive backups of database, configuration, and logs

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_ROOT}/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="mailfactory_backup_${TIMESTAMP}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Create backup directory
create_backup_directory() {
    log_info "Creating backup directory..."

    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}"
    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/database"
    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/config"
    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/logs"
    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/ssl"

    log_success "Backup directory created: ${BACKUP_DIR}/${BACKUP_NAME}"
}

# Backup PostgreSQL database
backup_database() {
    log_info "Backing up PostgreSQL database..."

    if ! docker ps | grep -q mailfactory-postgres; then
        log_error "PostgreSQL container is not running"
        return 1
    fi

    # Load environment variables
    if [ -f "${PROJECT_ROOT}/.env.prod" ]; then
        export $(grep -v '^#' "${PROJECT_ROOT}/.env.prod" | xargs)
    fi

    # Create database dump
    docker exec mailfactory-postgres pg_dump \
        -U "${POSTGRES_USER}" \
        -d "${POSTGRES_DB}" \
        --no-password \
        --format=custom \
        --compress=9 \
        --file="/tmp/${BACKUP_NAME}.backup"

    # Copy dump from container
    docker cp "mailfactory-postgres:/tmp/${BACKUP_NAME}.backup" "${BACKUP_DIR}/${BACKUP_NAME}/database/"

    # Clean up container
    docker exec mailfactory-postgres rm "/tmp/${BACKUP_NAME}.backup"

    log_success "Database backup completed"
}

# Backup Redis data
backup_redis() {
    log_info "Backing up Redis data..."

    if ! docker ps | grep -q mailfactory-redis; then
        log_warning "Redis container is not running, skipping Redis backup"
        return 0
    fi

    # Create Redis dump
    docker exec mailfactory-redis redis-cli SAVE

    # Copy dump from container
    docker cp "mailfactory-redis:/data/dump.rdb" "${BACKUP_DIR}/${BACKUP_NAME}/redis-dump.rdb"

    log_success "Redis backup completed"
}

# Backup configuration files
backup_configuration() {
    log_info "Backing up configuration files..."

    # Copy config directory
    if [ -d "${PROJECT_ROOT}/config" ]; then
        cp -r "${PROJECT_ROOT}/config" "${BACKUP_DIR}/${BACKUP_NAME}/"
        log_success "Configuration files backed up"
    else
        log_warning "Config directory not found"
    fi

    # Copy environment files (excluding sensitive data)
    if [ -f "${PROJECT_ROOT}/.env.prod" ]; then
        # Create sanitized version for backup
        grep -v "PASSWORD\|SECRET\|KEY" "${PROJECT_ROOT}/.env.prod" > "${BACKUP_DIR}/${BACKUP_NAME}/.env.prod.sanitized"
        log_success "Environment configuration backed up (sanitized)"
    fi
}

# Backup SSL certificates
backup_ssl() {
    log_info "Backing up SSL certificates..."

    if [ -d "${PROJECT_ROOT}/ssl" ]; then
        cp -r "${PROJECT_ROOT}/ssl" "${BACKUP_DIR}/${BACKUP_NAME}/"
        log_success "SSL certificates backed up"
    else
        log_warning "SSL directory not found"
    fi
}

# Backup application logs
backup_logs() {
    log_info "Backing up application logs..."

    if [ -d "${PROJECT_ROOT}/logs" ]; then
        # Compress logs to save space
        tar -czf "${BACKUP_DIR}/${BACKUP_NAME}/logs.tar.gz" -C "${PROJECT_ROOT}" logs/
        log_success "Application logs backed up"
    else
        log_warning "Logs directory not found"
    fi
}

# Backup Docker volumes
backup_volumes() {
    log_info "Backing up Docker volumes..."

    volumes=("mailfactory_postgres_data" "mailfactory_redis_data" "mailfactory_grafana_data" "mailfactory_prometheus_data")

    for volume in "${volumes[@]}"; do
        if docker volume ls | grep -q "$volume"; then
            log_info "Backing up volume: $volume"
            # Note: This requires docker-volume-backup or similar tool
            # For now, we'll document that volume backups need to be handled separately
            echo "Volume $volume requires separate backup strategy" >> "${BACKUP_DIR}/${BACKUP_NAME}/volumes.txt"
        fi
    done

    log_success "Volume information documented"
}

# Create backup manifest
create_manifest() {
    log_info "Creating backup manifest..."

    manifest_file="${BACKUP_DIR}/${BACKUP_NAME}/MANIFEST.txt"

    {
        echo "Mail Server Factory Backup Manifest"
        echo "===================================="
        echo ""
        echo "Backup Name: $BACKUP_NAME"
        echo "Created: $(date)"
        echo "Version: $(cat ${PROJECT_ROOT}/version.txt 2>/dev/null || echo 'Unknown')"
        echo ""
        echo "Included Components:"
        echo "- Database: PostgreSQL"
        echo "- Cache: Redis"
        echo "- Configuration: Application config"
        echo "- SSL: Certificates and keys"
        echo "- Logs: Application logs"
        echo ""
        echo "Backup Sizes:"
        du -sh "${BACKUP_DIR}/${BACKUP_NAME}"/*
        echo ""
        echo "Restore Instructions:"
        echo "1. Stop all services: docker-compose -f docker-compose.prod.yml down"
        echo "2. Restore database: pg_restore -U <user> -d <db> <backup_file>"
        echo "3. Restore configuration: cp -r config/* /app/config/"
        echo "4. Start services: docker-compose -f docker-compose.prod.yml up -d"
        echo ""
        echo "Note: Docker volumes require separate backup strategy"
    } > "$manifest_file"

    log_success "Backup manifest created"
}

# Compress backup
compress_backup() {
    log_info "Compressing backup..."

    cd "$BACKUP_DIR"
    tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"

    # Calculate sizes
    original_size=$(du -sh "$BACKUP_NAME" | cut -f1)
    compressed_size=$(du -sh "${BACKUP_NAME}.tar.gz" | cut -f1)

    log_success "Backup compressed: ${original_size} -> ${compressed_size}"

    # Remove uncompressed directory
    rm -rf "$BACKUP_NAME"
}

# Cleanup old backups
cleanup_old_backups() {
    log_info "Cleaning up old backups..."

    # Keep only last 30 days of backups
    find "$BACKUP_DIR" -name "mailfactory_backup_*.tar.gz" -mtime +30 -delete

    log_success "Old backups cleaned up"
}

# Upload to remote storage (optional)
upload_to_remote() {
    if [ -n "${BACKUP_S3_BUCKET:-}" ]; then
        log_info "Uploading backup to S3..."

        if command -v aws &> /dev/null; then
            aws s3 cp "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" "s3://${BACKUP_S3_BUCKET}/backups/"
            log_success "Backup uploaded to S3"
        else
            log_warning "AWS CLI not found, skipping S3 upload"
        fi
    fi
}

# Send notification
send_notification() {
    log_info "Sending backup notification..."

    # This could be extended to send email/Slack notifications
    log_success "Backup completed successfully: ${BACKUP_NAME}.tar.gz"
}

# Main backup function
main() {
    log_info "Starting Mail Server Factory Production Backup"

    create_backup_directory
    backup_database
    backup_redis
    backup_configuration
    backup_ssl
    backup_logs
    backup_volumes
    create_manifest
    compress_backup
    cleanup_old_backups
    upload_to_remote
    send_notification

    log_success "🎉 Production backup completed successfully!"
    log_info "Backup location: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
    log_info "Backup size: $(du -sh "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)"
}

# Handle command line arguments
case "${1:-}" in
    "list")
        log_info "Available backups:"
        ls -la "${BACKUP_DIR}"/mailfactory_backup_*.tar.gz
        ;;
    "restore")
        backup_file="${2:-}"
        if [ -z "$backup_file" ]; then
            log_error "Please specify backup file to restore"
            exit 1
        fi
        log_info "Restoring from backup: $backup_file"
        # Add restore logic here
        log_warning "Restore functionality not yet implemented"
        ;;
    "verify")
        backup_file="${2:-}"
        if [ -z "$backup_file" ]; then
            log_error "Please specify backup file to verify"
            exit 1
        fi
        log_info "Verifying backup: $backup_file"
        # Add verification logic here
        log_warning "Verification functionality not yet implemented"
        ;;
    *)
        main
        ;;
esac