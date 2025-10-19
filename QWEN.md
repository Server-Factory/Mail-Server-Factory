# Mail Server Factory - Project Context

## Project Overview

Mail Server Factory is a sophisticated Kotlin-based application designed to simplify the setup and deployment of mail servers. It interprets JSON configuration files and performs automated installations and initializations on target operating systems using Docker containers. The project is built with enterprise-grade security, performance, and monitoring features.

### Key Features
- **Automated Deployment**: Interprets JSON configurations to deploy mail server components (PostgreSQL, Dovecot, Postfix, Rspamd, Redis, ClamAV)
- **Cross-Platform Support**: Supports 12 major Linux distributions including Ubuntu, Debian, RHEL, AlmaLinux, Rocky Linux, Fedora, and openSUSE
- **Enterprise Security**: AES-256-GCM encryption, advanced authentication, audit logging, and role-based access control
- **Performance & Scalability**: JVM optimization, caching with Caffeine, thread pool management, and async processing
- **Monitoring & Observability**: Prometheus-compatible metrics, health checks, and structured logging
- **Configuration Management**: Environment-specific configurations with hot reloading capabilities

### Technology Stack
- **Language**: Kotlin 2.0.21
- **Build System**: Gradle 8.14.3
- **Runtime**: Java 17+
- **Containerization**: Docker
- **Database**: PostgreSQL
- **Mail Services**: Dovecot, Postfix
- **Security**: Rspamd (anti-spam), ClamAV (anti-virus), Redis
- **Caching**: Caffeine
- **Configuration**: Typesafe Config (HOCON format)

### Project Architecture
The project follows a modular architecture with distinct components:
- `Core:Framework`: Core framework and utilities
- `Logger:Logger`: Logging infrastructure
- `Factory`: Main application logic
- `Application`: Entry point and packaging

## Building and Running

### Prerequisites
- OpenJDK 17 or higher
- Gradle 8.14.3 (project includes wrapper)
- Docker for running tests and deployed mail server

### Build Commands
```bash
# Clone the project with submodules
git clone --recurse-submodules git@github.com:Server-Factory/Mail-Server-Factory.git

# Build the project
./gradlew assemble

# Run tests
./gradlew test

# Generate coverage reports
./gradlew jacocoTestReport

# Run all tests including SonarQube analysis
./gradlew allTests
```

### Running the Application
The application can be run using the launcher script:
```bash
# Using the launcher script (recommended)
mail_factory Examples/Ubuntu_22.json

# Or directly with Java
java -jar Application/build/libs/Application.jar Examples/Ubuntu_22.json
```

### Configuration
The application accepts JSON configuration files that define the mail server setup. Example configurations are available in the `Examples/` directory.

## Development Conventions

### Code Style
- Kotlin: Follows standard Kotlin coding conventions
- File encoding: UTF-8
- Indentation: 4 spaces
- Naming: PascalCase for classes, camelCase for functions and variables

### Testing
- JUnit Jupiter for unit testing
- Test coverage: 85%+ minimum
- Tests are organized in the `tests/` directory
- SonarQube quality gate: 100% pass rate required

### Configuration Management
- Uses Typesafe Config for hierarchical configuration
- Supports multiple environments (dev/staging/production)
- Configuration files in HOCON format
- Hot reloading of configurations

### Security Features
- All sensitive data encrypted with AES-256-GCM
- Strong password policies enforced
- Session management with timeout and concurrent session limits
- Comprehensive audit logging
- TLS 1.3 enforced for data in transit

### Performance Considerations
- JVM optimized with G1GC settings
- Multi-region caching with Caffeine
- Thread pool management for optimal resource utilization
- Async processing for better concurrency

## Project Structure

```
├── Application/          # Main application packaging
├── Core/                 # Core framework components
│   └── Framework/        # Core functionality
├── Factory/              # Main application logic
├── Logger/               # Logging infrastructure
├── Examples/             # Example configuration files
├── config/               # Configuration files
├── docs/                 # Documentation
├── scripts/              # Utility scripts
├── tests/                # Test files
├── build.gradle          # Root build configuration
└── settings.gradle       # Gradle project settings
```

## Running Tests

The project includes comprehensive tests for all components:

```bash
# Run all tests
./gradlew test

# Run tests with coverage
./gradlew test jacocoTestReport

# Run specific test classes
./gradlew test --tests "com.example.TestClass"

# Run tests for a specific module
./gradlew :Factory:test
```

### Testing Framework
- JUnit 5 for unit tests
- Comprehensive test coverage across all modules
- Automated integration testing with Docker
- Cross-distribution compatibility testing for all supported OSes

## Docker Integration

The application deploys mail server components as Docker containers:
- PostgreSQL: main database
- Dovecot & Postfix: core mail services
- Rspamd: anti-spam service
- Redis: in-memory database for Rspamd
- ClamAV: anti-virus service

## Environment Variables

The application supports various environment variables:
- `MAIL_FACTORY_ENV`: Environment type (dev/staging/production)
- `MAIL_FACTORY_CONFIG_DIR`: Custom configuration directory
- `JAVA_OPTS`: Additional JVM options

## Launcher Script Options

The `mail_factory` script provides several options:
- `--debug`: Enable debug output
- `--dry-run`: Show command without executing
- `--jar <path>`: Specify JAR file location
- `--installation-home`: Set custom installation home

## Enterprise Features

### Security
- AES-256-GCM encryption for data at rest
- TLS 1.3 for data in transit
- Advanced password policies
- Session management with concurrent session control
- Comprehensive audit logging with retention policies

### Performance
- JVM tuning with G1GC and performance-optimized settings
- Multi-level caching system
- Configurable thread pools
- Connection pooling and query optimization

### Monitoring
- Real-time metrics collection
- Health monitoring for all components
- Structured logging with context and correlation IDs
- Integration ready for Grafana, ELK stack

## Important Files and Directories

- `README.md`: Main project documentation
- `build.gradle`: Root build configuration
- `settings.gradle`: Project module configuration
- `docker-compose.yml`: SonarQube container setup
- `mail_factory`: Launcher script
- `Examples/`: Sample configuration files
- `Core/Framework/`: Core framework code
- `Factory/`: Main application logic
- `Application/`: Application packaging
- `config/`: Configuration files
- `tests/`: Test suite