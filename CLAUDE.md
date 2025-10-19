# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mail Server Factory is a Kotlin-based automation tool that deploys complete mail server stacks (Postfix, Dovecot, PostgreSQL, Rspamd, Redis, ClamAV) on remote Linux servers using Docker. Users provide JSON configuration files that the system interprets to perform installations, configure services, and initialize the mail server environment via SSH.

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

### Test Execution

The project has comprehensive test coverage with 100% test execution success:

| Module | Tests | Coverage | Status |
|--------|-------|----------|--------|
| Core:Framework | 14 | 21% (baseline) | ✅ 100% Pass |
| Factory | 33 | Full unit coverage | ✅ 100% Pass |
| Application | 0 | Pending | ⏳ To be added |
| **Total** | **47** | **Growing** | **✅ 100% Pass** |

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

The `mail_factory` launcher script is a bash wrapper that provides a production-ready interface to the Application JAR. It handles environment detection, JAR discovery, and argument forwarding with comprehensive error handling.

### Launcher Architecture

**Location**: `./mail_factory` (project root)

**Key Responsibilities**:
- Java runtime detection (via `JAVA_HOME` or `PATH`)
- Java version validation (minimum Java 17)
- Application JAR discovery (searches 7 standard locations)
- Environment variable processing (`JAVA_OPTS`, `MAIL_FACTORY_HOME`)
- Configuration file validation
- Argument forwarding to the Java application
- Exit code management (0, 1, 2, 3, 4, 5)

### Launcher Options

```bash
mail_factory [options] <configuration-file>

Options:
  --help, -h              Show help message
  --version, -v           Show version information
  --debug                 Enable verbose debugging output
  --dry-run               Show command without executing
  --jar <path>            Override JAR location
  --installation-home=X   Forward custom installation home to application
```

### JAR Search Order

The launcher searches for `Application.jar` in these locations:

1. `${MAIL_FACTORY_HOME}/Application.jar` (environment override)
2. `${SCRIPT_DIR}/Application/build/libs/Application.jar` (development build)
3. `${SCRIPT_DIR}/build/libs/Application.jar` (alternative build location)
4. `${SCRIPT_DIR}/Release/Application.jar` (release package)
5. `${SCRIPT_DIR}/Application.jar` (root directory)
6. `/usr/local/lib/mail-factory/Application.jar` (system-wide install)
7. `/opt/mail-factory/Application.jar` (alternative system location)

### Exit Codes

| Code | Meaning | When It Occurs |
|------|---------|----------------|
| 0 | Success | Normal execution or help/version display |
| 1 | General error | Unexpected failures |
| 2 | Java not found | Java not installed or not in PATH |
| 3 | JAR not found | Application JAR missing from all search locations |
| 4 | Invalid arguments | No configuration file provided |
| 5 | Config not found | Specified configuration file doesn't exist |

### Testing the Launcher

**Test Suite Location**: `tests/launcher/test_launcher.sh`

The launcher has a comprehensive test suite with 41 test cases covering:

```bash
# Run all launcher tests
./tests/launcher/test_launcher.sh

# Test output shows:
# - Individual test results (✓ PASS / ✗ FAIL)
# - Total tests run: 41
# - Tests passed / failed summary
```

**Test Categories**:
- **Help/Version Tests**: `--help` and `--version` flags
- **Argument Validation**: Missing args, missing config file, invalid JAR
- **Execution Modes**: Dry run, debug mode, normal execution
- **Configuration Tests**: Explicit JAR, installation home, multiple args, relative/absolute paths
- **Environment Tests**: `JAVA_OPTS`, `JAVA_HOME`, `MAIL_FACTORY_HOME`
- **File Validation**: Config file existence, extension validation, JAR search locations

**Test Infrastructure**:
- Mock configuration files: `tests/launcher/test_tmp/config/test.json`
- Mock JAR: `tests/launcher/mocks/mock-application.jar`
- Isolated test environment (automatically cleaned up)
- Color-coded output (green for pass, red for fail, blue for info)

### Development Guidelines

**When modifying the launcher**:

1. **Always run the test suite** after changes:
   ```bash
   ./tests/launcher/test_launcher.sh
   ```

2. **Exit code handling**: The launcher deliberately avoids `set -e` to allow proper exit code management. Functions return specific exit codes that are captured and propagated.

3. **Adding new options**:
   - Update the argument parsing section (lines 213-244)
   - Add to `show_help()` function (lines 64-109)
   - Create corresponding test case in `tests/launcher/test_launcher.sh`
   - Update documentation in README.md and CLAUDE.md

4. **Error handling pattern**:
   ```bash
   # Functions return exit codes
   function_name || exit $?

   # Or capture for custom handling
   result=$(function_name) || exit_code=$?
   ```

5. **Debugging launcher issues**:
   ```bash
   # Use debug mode to see internals
   ./mail_factory --debug --dry-run config.json

   # Or run with bash tracing
   bash -x ./mail_factory config.json
   ```

### Adding New Test Cases

To add a new launcher test:

1. Create test function in `tests/launcher/test_launcher.sh`:
   ```bash
   test_my_new_feature() {
       print_test_header "My new feature test"

       local output
       output=$("${LAUNCHER}" --my-flag test.json 2>&1)
       local exit_code=$?

       assert_exit_code 0 ${exit_code} "Feature returns exit code 0"
       assert_output_contains "expected" "${output}" "Output contains expected"
   }
   ```

2. Add function call to `main()` in the test script
3. Update `tests/launcher/README.md` with test description
4. Run full test suite to verify

### Launcher vs Direct Java Invocation

**Use the launcher when**:
- Running in production environments
- Need automatic JAR discovery
- Want standardized error messages
- Require environment variable support

**Use direct Java when**:
- Debugging application code (use IDE debugging)
- Need specific JVM diagnostic flags
- Testing JAR directly without wrapper logic
- Automation scripts with explicit paths

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

The project includes comprehensive scripts for testing mail server deployment across all supported distributions using QEMU virtualization.

### Testing Scripts

**`scripts/iso_manager.sh`** - ISO management
```bash
# Download ISOs for all supported distributions
./scripts/iso_manager.sh download

# Verify ISO checksums
./scripts/iso_manager.sh verify

# List available ISOs
./scripts/iso_manager.sh list
```

**`scripts/qemu_manager.sh`** - VM lifecycle management
```bash
# Create VM with distribution-specific settings
./scripts/qemu_manager.sh create <distribution> [memory] [disk] [cpus]

# Examples:
./scripts/qemu_manager.sh create ubuntu-22 4096 20G 2
./scripts/qemu_manager.sh create fedora-41 8192 40G 4
./scripts/qemu_manager.sh create rocky-9 8192 40G 4

# Start/stop/status/delete VMs
./scripts/qemu_manager.sh start <distribution>
./scripts/qemu_manager.sh stop <distribution>
./scripts/qemu_manager.sh status <distribution>
./scripts/qemu_manager.sh delete <distribution>
```

**`scripts/test_all_distributions.sh`** - Automated distribution testing
```bash
# Test all distributions
./scripts/test_all_distributions.sh all

# Test single distribution
./scripts/test_all_distributions.sh single Ubuntu_22

# Generate test report
./scripts/test_all_distributions.sh report
```

### VM Directory Structure

```
vms/
├── ubuntu-22/          # VM directory (per distribution)
│   ├── disk.qcow2      # Virtual disk
│   ├── vm.pid          # QEMU process ID
│   └── serial.log      # Console output
├── logs/               # VM creation logs
└── isos/               # Downloaded ISO files
```

### Automated Installation Configurations

Located in `preseeds/` directory:
- **Ubuntu/Debian**: `preseed.cfg` - Debian preseed format
- **Fedora/RHEL/AlmaLinux/Rocky**: `ks.cfg` - Kickstart format
- **openSUSE**: `autoyast.xml` - AutoYaST format

Each configuration provides:
- Non-interactive installation
- Automatic partitioning
- Network configuration (hostname.local resolution)
- SSH server installation
- Docker installation
- User account setup

### Testing Workflow

1. **Download ISOs**: `./scripts/iso_manager.sh download`
2. **Create VMs**: Use `qemu_manager.sh create` for each distribution
3. **Wait for Installation**: VMs auto-install (10-30 minutes per distribution)
4. **Deploy Mail Server**: Run `./mail_factory Examples/<Distribution>.json`
5. **Verify Services**: Check Docker containers with `docker ps -a`
6. **Run Tests**: Execute distribution-specific validation tests
7. **Generate Report**: `./scripts/test_all_distributions.sh report`

### Resource Requirements

- **Disk Space**: ~100GB (for ISOs and VM images)
- **RAM**: 16GB recommended (for running multiple VMs)
- **CPU**: Hardware virtualization support (Intel VT-x or AMD-V)

### Test Results

Test results are stored in `test_results/` directory:
- Markdown reports: `test_results_<timestamp>.md`
- JSON reports: `test_results_<timestamp>.json`
- Individual distribution logs: `<distribution>_<timestamp>.log`

See [TESTING.md](TESTING.md) for detailed testing documentation.

## Testing

### Test Structure

Tests are organized by module following the source directory structure:

```
Factory/src/test/kotlin/
  └── net/milosvasic/factory/mail/
      ├── account/
      │   ├── MailAccountTest.kt (13 tests)
      │   └── MailAccountValidatorTest.kt (7 tests)
      └── configuration/
          ├── MailServerConfigurationTest.kt (5 tests)
          └── MailServerConfigurationFactoryTest.kt (8 tests)

Core/Framework/src/test/kotlin/
  └── net/milosvasic/factory/test/
      ├── Installation step tests (5 tests)
      ├── Flow tests (6 tests)
      └── Other tests (3 tests)
```

### Running Tests

```bash
# Run all tests
./gradlew test

# Run tests for specific module
./gradlew :Factory:test
./gradlew :Core:Framework:test

# Run with coverage reports
./gradlew test jacocoTestReport
```

### Writing Tests

When adding new functionality, always include comprehensive tests:

1. **Unit Tests**: Test individual classes and methods in isolation
2. **Integration Tests**: Test interactions between components
3. **Edge Cases**: Test null handling, empty collections, boundary conditions

Example test structure:

```kotlin
@Test
@DisplayName("Clear description of what is being tested")
fun testMethodName() {
    // Given - Setup
    val input = createTestData()

    // When - Execute
    val result = methodUnderTest(input)

    // Then - Verify
    assertEquals(expected, result)
}
```

### Test Coverage Goals

- **Factory Module**: ✅ 100% unit test coverage for public APIs
- **Core:Framework**: 21% baseline coverage (to be improved)
- **Project Goal**: 80%+ coverage for critical paths

### Known Issues

- **StackStepTest**: Temporarily excluded due to initialization issues (Docker-related)
- Tests require Docker to be running locally

### Bug Fixes

**MailAccount Constructor Bug** (Fixed 2025-10-10)
- **Issue**: Parameters passed to parent Account class in wrong order
- **Fix**: Changed from `Account(name, credentials, type)` to `Account(name, type, credentials)`
- **Impact**: Prevented credentials/type swap that would cause authentication failures
- **File**: `Factory/src/main/kotlin/net/milosvasic/factory/mail/account/MailAccount.kt:15`

## Enterprise Features

The application includes enterprise-grade features for production deployment:

### Configuration Management

Located in `config/` directory:
- `application.conf` - Base application configuration
- `application-{environment}.conf` - Environment-specific overrides (development/staging/production)
- `security.conf` - Security policies and encryption settings
- `database.conf` - Database connection and pooling settings
- `monitoring.conf` - Metrics and health check configuration
- `performance.conf` - JVM tuning and caching settings

**Environment Selection**:
```bash
# Set environment via environment variable
export MAIL_FACTORY_ENV=production
./mail_factory config.json

# Or via custom config directory
export MAIL_FACTORY_CONFIG_DIR=/etc/mail-factory/config
```

### Security Features (`Factory/src/main/kotlin/net/milosvasic/factory/mail/security/`)

- **Encryption**: AES-256-GCM for sensitive data encryption
- **Password Policies**: Configurable strength requirements (min length, uppercase, digits, special chars)
- **Session Management**: Timeout controls, concurrent session limits
- **TLS/SSL**: Enforced TLS 1.3/1.2 for all connections
- **Audit Logging**: Security event tracking with retention policies

### Performance Features (`Factory/src/main/kotlin/net/milosvasic/factory/mail/performance/`)

- **Caching**: Caffeine-based multi-region caching with configurable TTL
- **Thread Pools**: Configurable thread pool sizing for optimal concurrency
- **JVM Tuning**: G1GC configuration and heap size management
- **Connection Pooling**: Database connection pooling for high throughput

### Monitoring Features (`Factory/src/main/kotlin/net/milosvasic/factory/mail/monitoring/`)

- **Metrics Export**: Prometheus-compatible metrics endpoint (default port 9090)
- **Health Checks**: Automated health monitoring for system, database, security, and performance
- **Structured Logging**: JSON-formatted logs with correlation IDs (`Factory/src/main/kotlin/net/milosvasic/factory/mail/logging/`)
- **Performance Monitoring**: Real-time JVM, database, and application metrics

**Access metrics**:
```bash
curl http://localhost:9090/metrics
```

### SonarQube Integration

The project includes SonarQube quality analysis:

```bash
# Start SonarQube containers
docker compose up -d

# Run quality analysis
./gradlew sonarQualityCheck

# Or run comprehensive tests including quality analysis
./gradlew allTests
```

SonarQube dashboard: `http://localhost:9000` (credentials: admin/admin)

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
