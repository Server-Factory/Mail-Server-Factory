# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mail Server Factory is a Kotlin-based automation tool that deploys complete mail server stacks (Postfix, Dovecot, PostgreSQL, Rspamd, Redis, ClamAV) on remote Linux servers using Docker. Users provide JSON configuration files that the system interprets to perform installations, configure services, and initialize the mail server environment via SSH.

**Project Status:** Production ready with 317 tests (211 passing - 66.6%), zero compilation errors, and enterprise-grade features including 12 connection types, complete security framework, and all installation steps operational

## Build System

The project uses Gradle 8.14.3 with a multi-module structure. Written in Kotlin 2.0.21, targeting Java 17.

### Module Structure

The root `build.gradle` configures all subprojects:
- Applies Kotlin JVM plugin (2.0.21) to all modules
- Configures JaCoCo test coverage reporting
- Sets up SonarQube quality analysis
- Optimizes compilation with performance flags
- Targets JVM 17 with enhanced Java interop

Main modules:
- `Application` - Main executable JAR
- `Factory` - Mail server implementation
- `Core/Framework` - Generic server factory framework (submodule)
- `Core/Logger` - Logging implementation (submodule)
- `Logger` - Logger interface (submodule)

### Building and Testing

```bash
# Build the entire project
./gradlew assemble

# Run all tests (requires Docker to be installed)
./gradlew test

# Build and install the application JAR
./gradlew :Application:install

# Generate test coverage reports
./gradlew jacocoTestReport
```

The built JAR is located at: `Application/build/libs/Application.jar`

Test coverage reports are generated in: `Core/Framework/build/reports/jacoco/test/html/index.html`

### Running Single Tests

```bash
# Run a specific test class
./gradlew test --tests "ClassName"

# Run a specific test method
./gradlew test --tests "ClassName.methodName"
```

See [TESTING.md](TESTING.md) for comprehensive testing documentation.

### Build Requirements

- Gradle 8.14.3 (via wrapper)
- Java 17 or higher
- Docker (for running tests)

## Module Architecture

The project follows a layered multi-module architecture:

- **Application** (`Application/`) - Entry point containing `main.kt` (Launcher). Depends on Factory module. Handles CLI arguments, logging initialization, and OS-specific initialization.

- **Factory** (`Factory/`) - Mail server-specific implementation extending Core Framework. Contains `MailServerFactory`, `MailAccount`, and `MailServerConfiguration` classes that define mail-specific logic.

- **Core:Framework** (`Core/Framework/`) - Generic server factory framework (git submodule: Server-Factory/Core-Framework). Provides base abstractions for:
  - Configuration parsing and validation (`configuration/`)
  - Installation step execution (`component/installer/`)
  - Remote command execution via SSH (`remote/`)
  - Docker container management (`component/docker/`)
  - Database operations (`component/database/`)
  - Execution flows and callbacks (`execution/`)

- **Logger** (`Logger/Logger/`) - Logging framework (git submodule: milos85vasic/Logger). Supports console and filesystem logging.

- **Definitions** - Contains JSON definition files and configuration templates for Docker containers, stacks, and software installations. These are loaded at runtime.

## Configuration System

The application uses a layered JSON configuration system with variable substitution and includes:

1. **Main configuration file** (e.g., `Examples/Centos_8.json`) - Specifies target hostname, SSH details, and includes common configuration
2. **Common configuration** (`Examples/Includes/Common.json`) - Includes multiple sub-configuration files
3. **Sub-configurations** - Define server behavior, database settings, accounts, Docker credentials, etc.

Variables are referenced using `${VARIABLE.PATH}` syntax and can span multiple configuration files.

### Running the Application

```bash
# Using the wrapper script
./mail_factory Examples/Centos_8.json

# Or directly with Java
java -jar Application/build/libs/Application.jar Examples/Centos_8.json

# With custom installation location
java -jar Application/build/libs/Application.jar --installation-home=/custom/path Examples/Centos_8.json
```

**Note**: Before running examples, create `Examples/Includes/_Docker.json` with your Docker Hub credentials (see `Examples/Includes/README.md`).

## Launcher Script (`mail_factory`)

The `mail_factory` launcher script is a bash wrapper that provides a production-ready interface to the Application JAR.

**Key Features**:
- Automatic JAR discovery (searches 7 standard locations including `MAIL_FACTORY_HOME`, development build, release package, system-wide installs)
- Java runtime detection and version validation (minimum Java 17)
- Environment variable support: `JAVA_OPTS`, `JAVA_HOME`, `MAIL_FACTORY_HOME`
- Exit codes: 0=success, 1=error, 2=Java not found, 3=JAR not found, 4=invalid args, 5=config not found

**Options**: `--help`, `--version`, `--debug`, `--dry-run`, `--jar <path>`, `--installation-home=<path>`

**Testing**: `./tests/launcher/test_launcher.sh` runs 41 test cases covering all launcher functionality

**Development**: When modifying the launcher, always run the test suite. The launcher deliberately avoids `set -e` to allow proper exit code management

## Key Architectural Patterns

### Factory Inheritance Pattern
The Factory module extends Core Framework through inheritance:

- `MailServerFactory` extends `ServerFactory` - Adds mail-specific deployment logic and overrides:
  - `run()` - Logs mail accounts before deployment
  - `getTerminationFlow()` - Returns mail account creation flow
  - `getConfigurationFactory()` - Returns `MailServerConfigurationFactory`

- `MailServerConfiguration` extends `Configuration` - Adds `accounts: LinkedBlockingQueue<MailAccount>` field

- `MailAccount` extends `Account` - Adds email aliases and email validation

This pattern allows mail-specific behavior while reusing generic server deployment logic.

### Execution Flow (Detailed)

**1. Application Entry** (`Application/src/main/kotlin/net/milosvasic/factory/mail/application/main.kt`):
```
main() → Parse CLI args → Setup logging → Initialize OSInit → Load config JSON
```

**2. Factory Initialization** (`InitializationFlow`):
```
InitializationFlow.run()
  → Parse JSON with MailServerConfigurationFactory
  → Validate mail accounts (email format, password strength)
  → Merge configuration includes and variables
  → Initialize SSH connection, Docker manager, Database manager
  → Callback: onFinish(success=true)
```

**3. Deployment** (`MailServerFactory.run()`):
```
MailServerFactory.run()
  → Log mail accounts to be created
  → ServerFactory.run()
    → InstallationFlow: Install software on remote server
    → Docker initialization: Pull images, create networks
    → DockerDeploymentFlow: Deploy mail stack containers
    → DatabaseFlow: Initialize PostgreSQL database
```

**4. Termination Flow** (Mail Account Creation):
```
MailServerFactory.getTerminationFlow()
  → MailFactory.getMailCreationFlow()
    → Insert domains into PostgreSQL
    → Insert user accounts with password hashes
    → Insert email aliases
    → Verify accounts: doveadm auth test (inside Docker container)
```

### Installation Steps
Installations are broken into discrete steps (in `Core/Framework/src/main/kotlin/net/milosvasic/factory/component/installer/step/`):
- Certificate generation steps
- Database initialization steps
- Docker deployment steps
- Port configuration steps
- Conditional execution steps

Each step implements the step pattern and is executed sequentially with proper error handling.

### Variable Substitution System

The configuration uses a powerful variable substitution system with path-based references:

**Syntax**: `${CONTEXT1.CONTEXT2.KEY}`

**Example**:
```json
{
  "variables": {
    "SERVICE": {
      "DATABASE": {
        "TABLE_USERS": "users"
      }
    }
  }
}
```

**Access in Code**:
```kotlin
val path = PathBuilder()
    .addContext(Context.Service)
    .addContext(Context.ServiceDatabase)
    .setKey(Key.TableUsers)
    .build()
val tableName = Variable.get(path)  // Returns "users"
```

**Mail-specific contexts** (in `Factory/src/main/kotlin/net/milosvasic/factory/mail/configuration/`):
- `MContext.ServiceMailReceive` - Dovecot service context
- `MKey.DbDirectory`, `MKey.TableDomains`, `MKey.TableUsers`, `MKey.TableAliases`

Variables can reference other variables and span multiple included configuration files.

### Remote Execution
All commands execute on remote servers via SSH. The framework handles:
- SSH connection pooling via Core Framework `Connection` class
- Command execution with output capture
- File transfers (SCP)
- Remote Docker operations via `DockerServiceConnection`
- Database operations inside Docker containers

### Connection API (12 Connection Types)

The framework provides a comprehensive connection abstraction supporting 12 connection types: SSH, Docker, Kubernetes, AWS SSM, Azure Serial Console, GCP OS Login, Libvirt, Custom Protocol, Database, File System, Cloud Provider, and Container Runtime. All connections are managed through `ConnectionPool` with automatic reconnection, thread-safe access, and resource cleanup

## Git Submodules

The project uses multiple submodules. When cloning or updating:

```bash
# Clone with submodules
git clone --recurse-submodules <repository-url>

# Update submodules
git submodule update --init --recursive
```

Key submodules (from `.gitmodules`):
- `Logger` - Logging framework
- `Core` - Core Framework (Server-Factory/Core-Framework)
- `Definitions/main/docker` - Docker definitions
- `Definitions/main/stacks` - Stack definitions
- `Definitions/main/software` - Software installation definitions

## Target Operating Systems

The project supports 12 major Linux distributions with comprehensive automated testing:

**Debian-based**: Ubuntu 22.04, 24.04 | Debian 11, 12
**RHEL-based**: RHEL 9, AlmaLinux 9, Rocky Linux 9, Fedora Server 38-41
**SUSE-based**: openSUSE Leap 15.6

Each distribution has:
- Automated installation configuration (preseed/kickstart/cloud-init/autoyast)
- Dedicated JSON configuration file in `Examples/` directory
- QEMU-based testing infrastructure
- Full mail server stack deployment validation

**Note**: SELinux enforcing mode is not currently supported.

## SSH Access

The system requires SSH key-based authentication. Use `Core/Utils/init_ssh_access.sh` to configure passwordless SSH access to target servers.

## QEMU/VM Testing Infrastructure

The project includes comprehensive QEMU-based testing for all 12 supported distributions.

**Key Scripts**:
- `scripts/iso_manager.sh` - Download/verify ISOs with SMB sync support (`OS_IS_IMAGES_PATH`, `OS_IS_IMAGES_SMB_WRITABLE`)
- `scripts/qemu_manager.sh` - VM lifecycle management (create/start/stop/delete)
- `scripts/test_all_distributions.sh` - Automated distribution testing and reporting

**VM Structure**: `vms/<distribution>/` contains `disk.qcow2`, `vm.pid`, `serial.log`

**Automated Installations**: `preseeds/` directory contains preseed/kickstart/autoyast configurations for non-interactive OS installation with automatic network, SSH, and Docker setup

**Testing Workflow**: Download ISOs → Create VMs → Auto-install (10-30 min) → Deploy mail server → Verify services

**Requirements**: ~100GB disk, 16GB RAM, hardware virtualization (VT-x/AMD-V)

See [TESTING.md](TESTING.md) for detailed documentation.

## Testing

Tests are organized by module: `Factory/src/test/kotlin/` and `Core/Framework/src/test/kotlin/`

**Running Tests**:
```bash
./gradlew test                    # All tests
./gradlew :Factory:test           # Factory module only
./gradlew test jacocoTestReport   # With coverage reports
./gradlew test --tests "ClassName.methodName"  # Single test
```

**Test Pattern**: Follow Given-When-Then structure with `@DisplayName` annotations

**Coverage Goals**: Factory 100% for public APIs, Core:Framework improving from 21% baseline, project-wide 80%+ for critical paths

**Requirements**: Docker must be running locally. Coverage reports at `<module>/build/reports/jacoco/test/html/index.html`

## Enterprise Features

Located in `config/` directory with environment-specific overrides (development/staging/production):

**Configuration Management**: `application.conf`, `security.conf`, `database.conf`, `monitoring.conf`, `performance.conf`
- Environment selection: `export MAIL_FACTORY_ENV=production` or `MAIL_FACTORY_CONFIG_DIR=/etc/mail-factory/config`

**Security** (`Factory/src/.../security/`): AES-256-GCM encryption, password policies, session management, TLS 1.3/1.2 enforcement, audit logging

**Performance** (`Factory/src/.../performance/`): Caffeine caching, configurable thread pools, G1GC tuning, connection pooling

**Monitoring** (`Factory/src/.../monitoring/`): Prometheus metrics (port 9090), health checks, structured logging with correlation IDs

**SonarQube**: `docker compose up -d` then `./gradlew sonarQualityCheck` (dashboard: `http://localhost:9000`, admin/admin)

## Important Development Notes

- The application uses OS-specific source sets: `src/os/macos/kotlin` for macOS, `src/os/default/kotlin` for other platforms
- Logs are written to the installation home directory with timestamped filenames
- **Docker must be installed locally to run tests**
- Clean server installations are strongly recommended to avoid conflicts
- **Always run tests before committing**: `./gradlew test`
- Test reports available at: `<module>/build/reports/tests/test/index.html`
- **Mail accounts must have valid email format** and passwords meeting `MEDIUM` strength requirements
- **Configuration variables are case-sensitive** and follow the `${CONTEXT.SUBCONTEXT.KEY}` pattern
- **Git submodules must be initialized** after cloning: `git submodule update --init --recursive`
