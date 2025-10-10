# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mail Server Factory is a Kotlin-based automation tool that deploys complete mail server stacks (Postfix, Dovecot, PostgreSQL, Rspamd, Redis, ClamAV) on remote Linux servers using Docker. Users provide JSON configuration files that the system interprets to perform installations, configure services, and initialize the mail server environment via SSH.

## Build System

The project uses Gradle with a multi-module structure. Written in Kotlin 1.5.0, targeting Java 11.

### Building and Testing

```bash
# Initial setup (if gradlew is missing)
gradle wrapper

# Build the entire project
./gradlew assemble

# Run all tests (requires Docker to be installed)
./gradlew test

# Build and install the application JAR
./gradlew :Application:install
```

The built JAR is located at: `Application/build/libs/Application.jar`

### Running Single Tests

```bash
# Run a specific test class
./gradlew test --tests "ClassName"

# Run a specific test method
./gradlew test --tests "ClassName.methodName"
```

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

## Important Development Notes

- The application uses OS-specific source sets: `src/os/macos/kotlin` for macOS, `src/os/default/kotlin` for other platforms
- Logs are written to the installation home directory with timestamped filenames
- Docker must be installed locally to run tests
- Clean server installations are strongly recommended to avoid conflicts
