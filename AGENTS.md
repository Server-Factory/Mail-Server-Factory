# Agent Guidelines for Mail Server Factory

## Build & Test Commands
- **Build project**: `./gradlew assemble`
- **Run complete test suite**: `./run-all-tests.sh` (includes unit tests, coverage, and SonarQube)
- **Run all tests**: `./gradlew test`
- **Run comprehensive tests**: `./gradlew allTests`
- **Test single class**: `./gradlew test --tests "ClassName"`
- **Test single method**: `./gradlew test --tests "ClassName.methodName"`
- **Test specific module**: `./gradlew :ModuleName:test`
- **Generate coverage**: `./gradlew test jacocoTestReport`
- **Run quality checks**: `./gradlew check` (includes SonarQube analysis)
- **Run SonarQube analysis**: `./sonar-analysis.sh`

## Code Quality Standards
- **SonarQube Quality Gate**: Must pass 100% (no issues allowed)
- **Test Coverage**: Minimum 80% overall coverage required
- **Code Smells**: Zero tolerance - all must be fixed
- **Security Vulnerabilities**: Zero tolerance - all must be fixed
- **Bugs**: Zero tolerance - all must be fixed

## Enterprise Features

### Security Configuration
- **Encryption**: AES-256-GCM for sensitive data
- **Password Policy**: Minimum 12 chars, uppercase, lowercase, digits, special chars
- **Session Security**: 30-minute timeout, 5 login attempts max, 15-minute lockout
- **TLS Enforcement**: TLS 1.3 required, HSTS enabled
- **Audit Logging**: 90-day retention, real-time security event monitoring

### Performance Optimization
- **JVM Tuning**: G1GC, 2GB heap, optimized for enterprise workloads
- **Caching**: Caffeine-based multi-region caching (10k max size, 30min TTL)
- **Thread Pools**: Configurable pools (10-50 threads, 5min keep-alive)
- **Database**: Connection pooling (5-20 connections, 30s timeout)
- **Async I/O**: Non-blocking operations for high concurrency

### Monitoring & Observability
- **Metrics**: Prometheus-compatible endpoint on port 9090
- **Health Checks**: Automated monitoring of system, database, security, performance
- **Structured Logging**: Enterprise-grade logging with correlation IDs
- **Alerting**: Configurable alerts for security violations and performance issues

### Configuration Management
- **Environment Support**: Development, staging, production configurations
- **Hot Reloading**: Automatic configuration reloading without restart
- **Validation**: Schema validation with detailed error reporting
- **File Watching**: Real-time configuration file monitoring

## Code Style Guidelines
- **Language**: Kotlin 2.0.21 targeting Java 17
- **Naming**: PascalCase classes, camelCase methods/properties
- **Imports**: One per line, alphabetically organized
- **Formatting**: 4-space indentation, blank lines between methods
- **Null safety**: Use `?`, `let`, Elvis operator (`?:`)
- **Error handling**: `@Throws` annotations for exceptions
- **Testing**: JUnit 5 with `@DisplayName`, Given/When/Then structure
- **Types**: Explicit types preferred, avoid `var` when possible

## Enterprise Architecture Patterns

### Security Patterns
- **Defense in Depth**: Multiple security layers (network, application, data)
- **Zero Trust Architecture**: Every request authenticated and authorized
- **Fail-Safe Defaults**: Secure defaults with explicit opt-in for relaxed security
- **Audit Everything**: Comprehensive logging of all security-relevant events

### Performance Patterns
- **Caching Strategy**: Multi-level caching (application, database, CDN)
- **Connection Pooling**: Efficient resource management for database connections
- **Async Processing**: Non-blocking operations for high throughput
- **Resource Optimization**: JVM tuning and garbage collection optimization

### Monitoring Patterns
- **Metrics Collection**: Structured metrics with consistent naming
- **Health Checks**: Automated health verification for all components
- **Log Aggregation**: Centralized logging with correlation and tracing
- **Alert Management**: Configurable alerts with appropriate severity levels

### Configuration Patterns
- **Environment Separation**: Clear separation between dev/staging/production
- **Configuration as Code**: Version-controlled configuration management
- **Validation First**: Configuration validation before application startup
- **Hot Reloading**: Runtime configuration updates without service disruption