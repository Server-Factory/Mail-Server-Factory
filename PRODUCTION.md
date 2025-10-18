# Mail Server Factory Production Deployment Guide

This guide covers production deployment of Mail Server Factory with enterprise-grade security, monitoring, and scalability.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Monitoring](#monitoring)
- [Backup & Recovery](#backup--recovery)
- [Security](#security)
- [Performance Tuning](#performance-tuning)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements

- **OS**: Ubuntu 20.04+, CentOS 8+, RHEL 8+
- **CPU**: 2+ cores (4+ recommended)
- **RAM**: 4GB minimum (8GB+ recommended)
- **Storage**: 50GB+ SSD storage
- **Network**: 100Mbps+ connection

### Software Requirements

- **Docker**: 20.10+
- **Docker Compose**: 2.0+
- **OpenSSL**: For SSL certificate generation
- **curl/wget**: For downloading scripts

### Network Requirements

- **Ports**: 80, 443 (HTTP/HTTPS), 25, 465, 993 (Mail), 9090 (Metrics)
- **DNS**: Valid domain name with SSL certificate
- **Firewall**: Properly configured firewall rules

## Quick Start

1. **Clone and setup**:
   ```bash
   git clone https://github.com/Server-Factory/Mail-Server-Factory.git
   cd Mail-Server-Factory
   ```

2. **Configure environment**:
   ```bash
   cp .env.prod.example .env.prod
   # Edit .env.prod with your settings
   nano .env.prod
   ```

3. **Deploy**:
   ```bash
   ./scripts/deploy-production.sh
   ```

4. **Verify deployment**:
   ```bash
   curl http://localhost/health
   ```

## Configuration

### Environment Variables

Copy `.env.prod.example` to `.env.prod` and configure:

```bash
# Database
POSTGRES_DB=mailfactory_prod
POSTGRES_USER=mailfactory
POSTGRES_PASSWORD=your-secure-password

# Security
JWT_SECRET=your-64-char-jwt-secret
ENCRYPTION_KEY=your-32-char-encryption-key

# Monitoring
GRAFANA_ADMIN_PASSWORD=your-admin-password
```

### Application Configuration

Production configurations are in `config/` directory:

- `application-production.conf` - Production overrides
- `security.conf` - Security policies
- `database.conf` - Database settings
- `monitoring.conf` - Monitoring configuration

### SSL Configuration

For production SSL certificates:

1. **Let's Encrypt** (recommended):
   ```bash
   certbot certonly --webroot -w /var/www/html -d yourdomain.com
   ```

2. **Commercial certificates**:
   Place certificates in `ssl/` directory:
   ```
   ssl/
   ├── certificate.crt
   ├── private.key
   └── ca-bundle.crt
   ```

## Deployment

### Automated Deployment

Use the production deployment script:

```bash
# Full deployment
./scripts/deploy-production.sh

# Check prerequisites only
./scripts/deploy-production.sh check

# View deployment status
./scripts/deploy-production.sh status

# View logs
./scripts/deploy-production.sh logs

# Stop services
./scripts/deploy-production.sh stop
```

### Manual Deployment

1. **Start services**:
   ```bash
   docker-compose -f docker-compose.prod.yml up -d
   ```

2. **Check health**:
   ```bash
   docker-compose -f docker-compose.prod.yml ps
   curl http://localhost/health
   ```

3. **View logs**:
   ```bash
   docker-compose -f docker-compose.prod.yml logs -f app
   ```

### Service Architecture

```
Internet
    ↓
[ Nginx Reverse Proxy ]
    ↓
[ Mail Server Factory App ]
    ↓
[ PostgreSQL | Redis | Rspamd | ClamAV ]
```

## Monitoring

### Accessing Monitoring

- **Application Metrics**: http://localhost:9090/metrics
- **Grafana Dashboard**: http://localhost:3000 (admin/password)
- **Prometheus**: http://localhost:9091

### Key Metrics to Monitor

#### Application Metrics
- **Response Time**: P95 < 500ms
- **Error Rate**: < 1%
- **Active Connections**: Monitor trends
- **Memory Usage**: < 80% heap

#### System Metrics
- **CPU Usage**: < 70% sustained
- **Memory Usage**: < 85% total
- **Disk I/O**: Monitor for bottlenecks
- **Network I/O**: Monitor bandwidth usage

#### Business Metrics
- **Email Throughput**: Messages per second
- **Queue Size**: Monitor mail queues
- **Authentication Success**: Track login patterns

### Alerting

Configure alerts for:
- Service downtime
- High error rates
- Resource exhaustion
- Security violations

## Backup & Recovery

### Automated Backups

The system includes automated backup scripts:

```bash
# Run backup
./scripts/backup-production.sh

# List backups
./scripts/backup-production.sh list

# Verify backup
./scripts/backup-production.sh verify backup-file.tar.gz
```

### Backup Components

- **Database**: PostgreSQL dumps with compression
- **Configuration**: Application and environment configs
- **SSL Certificates**: Certificate and key backups
- **Logs**: Compressed application logs
- **Volumes**: Docker volume metadata

### Recovery Procedure

1. **Stop services**:
   ```bash
   docker-compose -f docker-compose.prod.yml down
   ```

2. **Restore database**:
   ```bash
   pg_restore -U user -d database backup.dump
   ```

3. **Restore configuration**:
   ```bash
   cp -r backup/config/* config/
   ```

4. **Start services**:
   ```bash
   docker-compose -f docker-compose.prod.yml up -d
   ```

## Security

### Security Features

- **AES-256-GCM Encryption**: Data at rest encryption
- **TLS 1.3**: End-to-end encryption
- **HSTS**: HTTP Strict Transport Security
- **CSP**: Content Security Policy
- **Rate Limiting**: DDoS protection
- **Audit Logging**: Comprehensive security logging

### Security Checklist

- [ ] SSL certificates installed and valid
- [ ] Firewall configured (ports 80, 443, 25, 465, 993 only)
- [ ] Strong passwords for all services
- [ ] Database encryption enabled
- [ ] Regular security updates scheduled
- [ ] Log monitoring and alerting configured
- [ ] Backup encryption enabled

### Security Monitoring

Monitor for:
- Failed authentication attempts
- Unusual traffic patterns
- SSL certificate expiration
- Security policy violations

## Performance Tuning

### JVM Tuning

Production JVM settings in `docker-compose.prod.yml`:

```yaml
environment:
  JAVA_OPTS: >
    -Xmx2g
    -Xms512m
    -XX:+UseG1GC
    -XX:MaxGCPauseMillis=200
    -XX:G1HeapRegionSize=16m
```

### Database Tuning

PostgreSQL optimization:

```yaml
environment:
  POSTGRES_SHARED_BUFFERS: 512MB
  POSTGRES_EFFECTIVE_CACHE_SIZE: 2GB
  POSTGRES_WORK_MEM: 8MB
  POSTGRES_MAINTENANCE_WORK_MEM: 128MB
```

### Connection Pooling

Database connection pool settings:

```yaml
pool:
  minSize: 5
  maxSize: 20
  connectionTimeout: 30000
  idleTimeout: 600000
```

### Caching Configuration

Application caching settings:

```yaml
caching:
  enabled: true
  maxSize: 10000
  expireAfterWrite: 1800
  expireAfterAccess: 600
```

## Troubleshooting

### Common Issues

#### Services Won't Start

**Check logs**:
```bash
docker-compose -f docker-compose.prod.yml logs
```

**Check resource usage**:
```bash
docker stats
```

**Validate configuration**:
```bash
docker-compose -f docker-compose.prod.yml config
```

#### Database Connection Issues

**Check database logs**:
```bash
docker-compose -f docker-compose.prod.yml logs postgres
```

**Test connection**:
```bash
docker exec -it mailfactory-postgres psql -U user -d database
```

#### High Memory Usage

**Monitor JVM**:
```bash
docker stats mailfactory-app
```

**Check heap usage**:
```bash
curl http://localhost:9090/metrics | grep heap
```

#### SSL Certificate Issues

**Check certificate validity**:
```bash
openssl x509 -in ssl/certificate.crt -text -noout
```

**Test SSL connection**:
```bash
openssl s_client -connect localhost:443 -servername yourdomain.com
```

### Log Locations

- **Application logs**: `logs/application.log`
- **Nginx logs**: `logs/nginx/`
- **Database logs**: Docker container logs
- **Monitoring logs**: `logs/monitoring/`

### Performance Debugging

1. **Enable debug logging**:
   ```bash
   export LOG_LEVEL=DEBUG
   docker-compose -f docker-compose.prod.yml up -d
   ```

2. **Profile application**:
   ```bash
   # Use Java Flight Recorder
   jcmd <pid> JFR.start duration=60s filename=profile.jfr
   ```

3. **Monitor system resources**:
   ```bash
   # Use htop, iotop, or similar tools
   htop
   ```

### Getting Help

- **Documentation**: Check this guide and inline comments
- **Logs**: Review application and system logs
- **Community**: GitHub issues and discussions
- **Professional Support**: Contact enterprise support team

## Scaling

### Horizontal Scaling

1. **Add application replicas**:
   ```bash
   docker-compose -f docker-compose.prod.yml up -d --scale app=3
   ```

2. **Configure load balancer**:
   ```yaml
   # Add to docker-compose.prod.yml
   loadbalancer:
     image: nginx:alpine
     ports:
       - "80:80"
     volumes:
       - ./nginx/lb.conf:/etc/nginx/nginx.conf
   ```

### Database Scaling

1. **Read replicas** (future enhancement)
2. **Connection pooling** (already configured)
3. **Query optimization** and indexing

### Storage Scaling

1. **External storage** for large attachments
2. **Log rotation** and archival
3. **Backup compression** and deduplication

## Maintenance

### Regular Tasks

- **Daily**: Monitor dashboards and alerts
- **Weekly**: Review logs and performance metrics
- **Monthly**: Update dependencies and security patches
- **Quarterly**: Review and update configurations

### Update Procedure

1. **Backup current state**:
   ```bash
   ./scripts/backup-production.sh
   ```

2. **Update images**:
   ```bash
   docker-compose -f docker-compose.prod.yml pull
   ```

3. **Rolling update**:
   ```bash
   docker-compose -f docker-compose.prod.yml up -d --no-deps app
   ```

4. **Verify health**:
   ```bash
   curl http://localhost/health
   ```

### Emergency Procedures

- **Service failure**: Check logs and restart affected service
- **Data corruption**: Restore from backup
- **Security incident**: Isolate affected systems, investigate logs
- **Performance degradation**: Scale resources or optimize queries

---

## Enterprise Support

For enterprise deployments requiring:
- 24/7 support
- Custom integrations
- Performance optimization
- Security audits
- Training and documentation

Contact: enterprise@server-factory.com

---

*This guide is continuously updated. Check for the latest version in the repository.*