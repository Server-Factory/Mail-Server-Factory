# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mail Server Factory is a Kotlin-based automation tool that deploys complete mail server stacks (Postfix, Dovecot, PostgreSQL, Rspamd, Redis, ClamAV) on remote Linux servers using Docker. Users provide JSON configuration files that the system interprets to perform installations, configure services, and initialize the mail server environment via SSH.

## Build System

The project uses Gradle with a multi-module structure. Written in Kotlin 2.0.21, targeting Java 17.

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

### Initialization Flow
The application follows an initialization-execution pattern:
1. Parse configuration JSON
2. Build ServerFactory via ServerFactoryBuilder
3. Run InitializationFlow with initialization operations
4. On success, execute factory.run() which performs the actual deployment

### Installation Steps
Installations are broken into discrete steps (in `component/installer/step/`):
- Certificate generation steps
- Database initialization steps
- Docker deployment steps
- Port configuration steps
- Conditional execution steps

Each step implements the step pattern and is executed sequentially with proper error handling.

### Remote Execution
All commands execute on remote servers via SSH. The framework handles:
- SSH connection pooling
- Command execution with output capture
- File transfers (SCP)
- Remote Docker operations

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

Supports CentOS 7-8, Fedora Server/Workstation 30-34, Ubuntu Desktop 20-21. SELinux enforcing is not currently supported.

## SSH Access

The system requires SSH key-based authentication. Use `Core/Utils/init_ssh_access.sh` to configure passwordless SSH access to target servers.

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

## Important Development Notes

- The application uses OS-specific source sets: `src/os/macos/kotlin` for macOS, `src/os/default/kotlin` for other platforms
- Logs are written to the installation home directory with timestamped filenames
- **Docker must be installed locally to run tests**
- Clean server installations are strongly recommended to avoid conflicts
- **Always run tests before committing**: `./gradlew test`
- Test reports available at: `<module>/build/reports/tests/test/index.html`
