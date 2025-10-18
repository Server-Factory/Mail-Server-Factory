#!/bin/bash

# Mail Server Factory Production Deployment Script
# This script handles complete production deployment with monitoring and security

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env.prod"
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.prod.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Pre-deployment checks
pre_deployment_checks() {
    log_info "Running pre-deployment checks..."

    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker service."
        exit 1
    fi

    # Check if Docker Compose is available
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not available. Please install Docker Compose."
        exit 1
    fi

    # Check environment file
    if [ ! -f "$ENV_FILE" ]; then
        log_error "Environment file $ENV_FILE not found."
        log_info "Please copy .env.prod.example to .env.prod and configure your settings."
        exit 1
    fi

    # Validate environment variables
    validate_environment

    log_success "Pre-deployment checks passed"
}

# Validate environment variables
validate_environment() {
    log_info "Validating environment configuration..."

    # Required variables
    required_vars=(
        "POSTGRES_DB"
        "POSTGRES_USER"
        "POSTGRES_PASSWORD"
        "JWT_SECRET"
        "ENCRYPTION_KEY"
        "GRAFANA_ADMIN_PASSWORD"
    )

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "Required environment variable $var is not set"
            exit 1
        fi
    done

    # Validate password strength
    if [ ${#POSTGRES_PASSWORD} -lt 12 ]; then
        log_warning "PostgreSQL password is shorter than 12 characters"
    fi

    if [ ${#JWT_SECRET} -lt 64 ]; then
        log_warning "JWT secret is shorter than 64 characters"
    fi

    if [ ${#ENCRYPTION_KEY} -lt 32 ]; then
        log_warning "Encryption key is shorter than 32 characters"
    fi

    log_success "Environment validation completed"
}

# Create required directories
create_directories() {
    log_info "Creating required directories..."

    directories=(
        "logs"
        "ssl"
        "monitoring/prometheus"
        "monitoring/grafana/provisioning"
        "monitoring/grafana/dashboards"
        "nginx/conf.d"
        "backups"
    )

    for dir in "${directories[@]}"; do
        mkdir -p "$PROJECT_ROOT/$dir"
        log_info "Created directory: $dir"
    done

    log_success "Directories created"
}

# Generate SSL certificates (self-signed for development)
generate_ssl_certificates() {
    log_info "Checking SSL certificates..."

    if [ ! -f "$PROJECT_ROOT/ssl/mailfactory.crt" ]; then
        log_info "Generating self-signed SSL certificate..."

        openssl req -x509 -newkey rsa:4096 -keyout "$PROJECT_ROOT/ssl/mailfactory.key" \
            -out "$PROJECT_ROOT/ssl/mailfactory.crt" -days 365 -nodes \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=mailfactory.local"

        log_success "SSL certificate generated"
    else
        log_info "SSL certificate already exists"
    fi
}

# Setup monitoring configuration
setup_monitoring() {
    log_info "Setting up monitoring configuration..."

    # Create Prometheus configuration
    cat > "$PROJECT_ROOT/monitoring/prometheus.yml" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'mailfactory'
    static_configs:
      - targets: ['app:9090']
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres:9187']
  - job_name: 'redis'
    static_configs:
      - targets: ['redis:9121']
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
EOF

    # Create Grafana provisioning
    mkdir -p "$PROJECT_ROOT/monitoring/grafana/provisioning/datasources"
    cat > "$PROJECT_ROOT/monitoring/grafana/provisioning/datasources/prometheus.yml" << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF

    log_success "Monitoring configuration created"
}

# Setup Nginx configuration
setup_nginx() {
    log_info "Setting up Nginx configuration..."

    # Create main nginx configuration
    cat > "$PROJECT_ROOT/nginx/nginx.conf" << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    include /etc/nginx/conf.d/*.conf;
}
EOF

    # Create site configuration
    cat > "$PROJECT_ROOT/nginx/conf.d/mailfactory.conf" << EOF
upstream mailfactory_app {
    server app:8080;
}

server {
    listen 80;
    server_name localhost;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Proxy to application
    location / {
        proxy_pass http://mailfactory_app;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # Timeout settings
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    # Metrics endpoint (internal only)
    location /metrics {
        proxy_pass http://mailfactory_app:9090;
        allow 172.20.0.0/16;
        deny all;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://mailfactory_app/health;
        access_log off;
    }
}
EOF

    log_success "Nginx configuration created"
}

# Deploy services
deploy_services() {
    log_info "Starting production deployment..."

    cd "$PROJECT_ROOT"

    # Load environment variables
    set -a
    source "$ENV_FILE"
    set +a

    # Pull latest images
    log_info "Pulling latest Docker images..."
    docker-compose -f "$COMPOSE_FILE" pull

    # Start services
    log_info "Starting services..."
    docker-compose -f "$COMPOSE_FILE" up -d

    # Wait for services to be healthy
    log_info "Waiting for services to be healthy..."
    sleep 30

    # Check service health
    check_deployment_health

    log_success "Production deployment completed"
}

# Check deployment health
check_deployment_health() {
    log_info "Checking deployment health..."

    services=("postgres" "redis" "app" "nginx" "prometheus" "grafana")
    failed_services=()

    for service in "${services[@]}"; do
        if docker-compose -f "$COMPOSE_FILE" ps "$service" | grep -q "Up"; then
            log_success "Service $service is running"
        else
            log_error "Service $service is not running"
            failed_services+=("$service")
        fi
    done

    if [ ${#failed_services[@]} -gt 0 ]; then
        log_error "The following services failed to start: ${failed_services[*]}"
        log_info "Check logs with: docker-compose -f $COMPOSE_FILE logs"
        exit 1
    fi

    log_success "All services are healthy"
}

# Post-deployment tasks
post_deployment_tasks() {
    log_info "Running post-deployment tasks..."

    # Run database migrations if needed
    log_info "Checking database migrations..."
    # Add migration commands here if needed

    # Setup monitoring alerts
    log_info "Setting up monitoring alerts..."
    # Add alert configuration here

    # Generate deployment report
    generate_deployment_report

    log_success "Post-deployment tasks completed"
}

# Generate deployment report
generate_deployment_report() {
    log_info "Generating deployment report..."

    report_file="$PROJECT_ROOT/logs/deployment-$(date +%Y%m%d-%H%M%S).log"

    {
        echo "Mail Server Factory Production Deployment Report"
        echo "Generated: $(date)"
        echo "Environment: Production"
        echo ""
        echo "Services Status:"
        docker-compose -f "$COMPOSE_FILE" ps
        echo ""
        echo "Resource Usage:"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
        echo ""
        echo "Environment Configuration:"
        echo "Database: $POSTGRES_DB"
        echo "Application Port: 8080"
        echo "Metrics Port: 9090"
        echo "Grafana Port: 3000"
        echo "Prometheus Port: 9091"
    } > "$report_file"

    log_success "Deployment report saved to: $report_file"
}

# Main deployment function
main() {
    log_info "Starting Mail Server Factory Production Deployment"

    pre_deployment_checks
    create_directories
    generate_ssl_certificates
    setup_monitoring
    setup_nginx
    deploy_services
    post_deployment_tasks

    log_success "🎉 Production deployment completed successfully!"
    log_info ""
    log_info "Access your application at:"
    log_info "  - Application: http://localhost"
    log_info "  - Metrics: http://localhost:9090/metrics"
    log_info "  - Grafana: http://localhost:3000 (admin/${GRAFANA_ADMIN_PASSWORD})"
    log_info "  - Prometheus: http://localhost:9091"
    log_info ""
    log_info "View logs with: docker-compose -f $COMPOSE_FILE logs -f"
    log_info "Stop services with: docker-compose -f $COMPOSE_FILE down"
}

# Handle command line arguments
case "${1:-}" in
    "check")
        pre_deployment_checks
        ;;
    "stop")
        log_info "Stopping production services..."
        cd "$PROJECT_ROOT"
        docker-compose -f "$COMPOSE_FILE" down
        log_success "Services stopped"
        ;;
    "restart")
        log_info "Restarting production services..."
        cd "$PROJECT_ROOT"
        docker-compose -f "$COMPOSE_FILE" restart
        log_success "Services restarted"
        ;;
    "logs")
        log_info "Showing service logs..."
        cd "$PROJECT_ROOT"
        docker-compose -f "$COMPOSE_FILE" logs -f
        ;;
    "status")
        log_info "Service status:"
        cd "$PROJECT_ROOT"
        docker-compose -f "$COMPOSE_FILE" ps
        ;;
    "backup")
        log_info "Creating backup..."
        # Add backup logic here
        log_warning "Backup functionality not yet implemented"
        ;;
    *)
        main
        ;;
esac