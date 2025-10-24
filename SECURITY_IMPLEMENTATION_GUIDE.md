# Security Implementation Guide

**Mail Server Factory - Version 3.1.0**
**Date**: 2025-10-24
**Status**: Implementation Complete

---

## Table of Contents

1. [Overview](#overview)
2. [Critical Security Fixes](#critical-security-fixes)
3. [Encryption System](#encryption-system)
4. [Input Validation System](#input-validation-system)
5. [Secure Configuration Management](#secure-configuration-management)
6. [Password Encryptor Tool](#password-encryptor-tool)
7. [Enhanced Reboot Step](#enhanced-reboot-step)
8. [Connection Pool Management](#connection-pool-management)
9. [Usage Examples](#usage-examples)
10. [Testing](#testing)
11. [Security Best Practices](#security-best-practices)
12. [Migration Guide](#migration-guide)

---

## Overview

This document describes the comprehensive security enhancements implemented in Mail Server Factory 3.1.0 to address critical security vulnerabilities (P0) and high-priority issues (P1) identified in the stability analysis.

### Issues Addressed

**P0 Critical Issues** (FIXED):
- **Issue #18**: Passwords in Plain Text
- **Issue #9**: No Input Validation

**P1 High-Priority Issues** (FIXED):
- **Issue #1**: SSH Connection Pooling Leak
- **Issue #2**: Reboot Verification Missing

### Components Implemented

| Component | File Location | Purpose |
|-----------|--------------|---------|
| Encryption | `Core/Framework/src/main/kotlin/net/milosvasic/factory/security/Encryption.kt` | AES-256-GCM encryption |
| InputValidator | `Core/Framework/src/main/kotlin/net/milosvasic/factory/validation/InputValidator.kt` | Comprehensive input validation |
| SecureConfiguration | `Core/Framework/src/main/kotlin/net/milosvasic/factory/security/SecureConfiguration.kt` | Secure credential management |
| PasswordEncryptor | `Application/src/main/kotlin/net/milosvasic/factory/mail/tools/PasswordEncryptor.kt` | CLI encryption tool |
| RebootStep | `Core/Framework/src/main/kotlin/net/milosvasic/factory/component/installer/step/reboot/RebootStep.kt` | Enhanced reboot with verification |
| ConnectionPool | `Core/Framework/src/main/kotlin/net/milosvasic/factory/remote/ConnectionPool.kt` | Connection lifecycle management |

---

## Critical Security Fixes

### Issue #18: Passwords in Plain Text (P0) ✅ FIXED

**Problem**: Passwords stored in plain text in JSON configuration files.

**Solution**: AES-256-GCM encryption with PBKDF2 key derivation.

**Impact**: Passwords are now encrypted with industry-standard encryption.

**Files Changed**:
- NEW: `Encryption.kt` - Encryption/decryption implementation
- NEW: `SecureConfiguration.kt` - Credential management
- NEW: `PasswordEncryptor.kt` - CLI tool for users

### Issue #9: No Input Validation (P0) ✅ FIXED

**Problem**: User input not validated, enabling command injection attacks.

**Solution**: Comprehensive input validation for all user-provided data.

**Impact**: Prevents command injection, path traversal, and other injection attacks.

**Files Changed**:
- NEW: `InputValidator.kt` - Validation for hosts, ports, emails, paths, commands
- Enhanced: All configuration loading code to use validation

### Issue #1: SSH Connection Pooling Leak (P1) ✅ FIXED

**Problem**: SSH connections not properly managed, causing resource leaks.

**Solution**: Connection pool with reference counting and lifecycle management.

**Impact**: Connections reused efficiently, no resource leaks.

**Files Changed**:
- NEW: `ConnectionPool.kt` - Pooled connection management

### Issue #2: Reboot Verification Missing (P1) ✅ FIXED

**Problem**: No verification that system actually rebooted.

**Solution**: Enhanced reboot step with boot ID verification and health checks.

**Impact**: Reliable reboot detection for real hardware and QEMU.

**Files Changed**:
- NEW: `RebootStep.kt` - Comprehensive reboot handling

---

## Encryption System

### Architecture

The encryption system uses **AES-256-GCM** (Galois/Counter Mode) for authenticated encryption with **PBKDF2-HMAC-SHA256** for key derivation.

### Security Features

1. **Authenticated Encryption** (GCM mode)
   - Prevents tampering
   - 128-bit authentication tag
   - Automatic integrity verification

2. **Key Derivation** (PBKDF2)
   - 65,536 iterations
   - HMAC-SHA256
   - 16-byte random salt per password
   - Prevents rainbow table attacks

3. **Randomization**
   - 12-byte random IV per encryption
   - Prevents pattern analysis
   - Same plaintext produces different ciphertext each time

4. **Format**
   ```
   encrypted:base64(salt):base64(iv):base64(ciphertext+tag)
   ```

### API Reference

```kotlin
import net.milosvasic.factory.security.Encryption

// Encrypt a password
val masterKey = "your-strong-master-key"
val plainPassword = "user-password"
val encrypted = Encryption.encrypt(plainPassword, masterKey)
// Result: "salt:iv:ciphertext"

// Decrypt a password
val decrypted = Encryption.decrypt(encrypted, masterKey)
// Result: "user-password"

// Wipe sensitive data from memory
val sensitiveChars = "password".toCharArray()
Encryption.wipe(sensitiveChars) // Overwrites with null bytes
```

### Usage in Configuration

**Old Format** (INSECURE):
```json
{
  "credentials": {
    "password": "mypassword123"
  }
}
```

**New Format** (SECURE):
```json
{
  "credentials": {
    "password": "encrypted:ABC123==:DEF456==:GHI789=="
  }
}
```

### Environment Variables

```bash
# Set master key (REQUIRED)
export MAIL_FACTORY_MASTER_KEY="your-strong-master-key"

# Run application
./mail_factory config.json
```

---

## Input Validation System

### Validation Types

| Type | Pattern | Example Valid | Example Invalid |
|------|---------|---------------|-----------------|
| Hostname | RFC 1123 | `example.com` | `-invalid.com` |
| IPv4 | Dotted decimal | `192.168.1.1` | `256.1.1.1` |
| IPv6 | Standard notation | `::1` | `invalid::g` |
| Port | 1-65535 | `8080` | `70000` |
| Username | 3-32 alphanumeric | `user123` | `ab` |
| Email | RFC 5322 | `user@example.com` | `@invalid` |
| Path | Safe paths | `/home/user` | `../../../etc/passwd` |
| Variable | Alphanumeric + dots | `config.db.host` | `123invalid` |

### API Reference

```kotlin
import net.milosvasic.factory.validation.InputValidator
import net.milosvasic.factory.validation.ValidationResult

// Validate hostname
val hostResult = InputValidator.validateHost("example.com")
when (hostResult) {
    is ValidationResult.Valid -> println("Valid")
    is ValidationResult.Invalid -> println("Invalid: ${hostResult.reason}")
    is ValidationResult.Warning -> println("Warning: ${hostResult.message}")
}

// Validate port
val portResult = InputValidator.validatePort(8080, allowPrivileged = false)

// Validate username
val userResult = InputValidator.validateUsername("admin")

// Validate email
val emailResult = InputValidator.validateEmail("user@example.com")

// Validate path (prevent path traversal)
val pathResult = InputValidator.validatePath(
    "/home/user/file.txt",
    mustExist = false,
    allowAbsolute = true
)

// Sanitize for shell execution
val userInput = "dangerous; rm -rf /"
val safe = InputValidator.sanitizeForShell(userInput)
// Result: 'dangerous rm -rf ' (dangerous chars removed, single-quoted)

// Validate command for dangerous patterns
val cmdResult = InputValidator.validateCommand("rm -rf /")
// Result: Warning about dangerous command

// Infer type and validate
val (type, result) = InputValidator.inferAndValidate("192.168.1.1")
// type = VariableType.IP_ADDRESS, result = Valid
```

### Protection Against

- **Command Injection**: Shell characters removed/escaped
- **Path Traversal**: `..`, `~`, `$HOME`, `${` blocked
- **SQL Injection**: Special characters validated
- **Email Injection**: RFC 5322 compliance enforced
- **DoS**: Length limits enforced

---

## Secure Configuration Management

### Features

1. **Environment Variable Support**
   - Passwords loaded from environment (recommended)
   - Secrets file support
   - Master key from environment

2. **Encrypted Configuration Support**
   - Detects `encrypted:` prefix
   - Automatic decryption
   - Fallback to environment

3. **Secret Management**
   - Centralized secret access
   - Memory clearing
   - Required secret validation

### API Reference

```kotlin
import net.milosvasic.factory.security.SecureConfiguration

// Get master key
val masterKey = SecureConfiguration.getMasterKey()

// Check if value is encrypted
if (SecureConfiguration.isEncrypted(password)) {
    val decrypted = SecureConfiguration.decryptPassword(password, masterKey)
}

// Get secret from environment or file
val secret = SecureConfiguration.getSecret("MAIL_FACTORY_DB_PASSWORD")

// Require secret (throws if missing)
val required = SecureConfiguration.requireSecret("MAIL_FACTORY_MASTER_KEY")

// Get specific password with fallback to environment
val dbPass = SecureConfiguration.getDatabasePassword(configPassword)
val sshPass = SecureConfiguration.getSshPassword(configPassword)
val dockerPass = SecureConfiguration.getDockerPassword(configPassword)

// Clear secrets from memory
SecureConfiguration.clearSecrets()

// Validate required secrets
SecureConfiguration.validateRequiredSecrets(
    listOf("MAIL_FACTORY_MASTER_KEY", "MAIL_FACTORY_DB_PASSWORD")
)
```

### Environment Variables

```bash
# Master encryption key (REQUIRED for encrypted passwords)
export MAIL_FACTORY_MASTER_KEY="your-strong-master-key"

# Alternative: provide passwords via environment (no encryption needed)
export MAIL_FACTORY_DB_PASSWORD="database-password"
export MAIL_FACTORY_SSH_PASSWORD="ssh-password"
export MAIL_FACTORY_DOCKER_PASSWORD="docker-hub-password"

# Alternative: secrets file
export MAIL_FACTORY_SECRETS_FILE="/secure/path/secrets.properties"
```

### Secrets File Format

```properties
# secrets.properties
MAIL_FACTORY_DB_PASSWORD=database-password
MAIL_FACTORY_SSH_PASSWORD=ssh-password
MAIL_FACTORY_DOCKER_PASSWORD=docker-hub-password
```

**Security Note**: Store secrets file with restricted permissions:
```bash
chmod 600 /secure/path/secrets.properties
chown app-user:app-group /secure/path/secrets.properties
```

---

## Password Encryptor Tool

### Overview

Command-line tool for encrypting passwords before storing them in configuration files.

### Usage

#### Interactive Mode (Recommended)

```bash
# Set master key
export MAIL_FACTORY_MASTER_KEY="your-strong-master-key"

# Run tool
java -jar Application.jar encrypt-password
```

Prompts:
1. Password to encrypt
2. Confirmation

Output:
```
======================================================================
ENCRYPTED PASSWORD (use this in your JSON configuration)
======================================================================

encrypted:ABC123==:DEF456==:GHI789==

======================================================================

Example usage in JSON:
{
  "credentials": {
    "password": "encrypted:ABC123==:DEF456==:GHI789=="
  }
}

IMPORTANT: Keep your master key secure!
Set environment variable: export MAIL_FACTORY_MASTER_KEY='your-master-key'
```

#### Command-Line Options

```bash
# Encrypt with explicit password (NOT RECOMMENDED - visible in history)
java -jar Application.jar encrypt-password --password "mypassword"

# Decrypt for verification
java -jar Application.jar decrypt-password "encrypted:ABC==:DEF==:GHI=="

# Show help
java -jar Application.jar encrypt-password --help
```

### Integration Workflow

1. **Generate Encrypted Password**:
   ```bash
   export MAIL_FACTORY_MASTER_KEY="your-master-key"
   java -jar Application.jar encrypt-password
   ```

2. **Copy Output to JSON**:
   ```json
   {
     "credentials": {
       "password": "encrypted:PASTE_HERE"
     }
   }
   ```

3. **Set Master Key in Production**:
   ```bash
   export MAIL_FACTORY_MASTER_KEY="your-master-key"
   ```

4. **Run Application**:
   ```bash
   ./mail_factory config.json
   ```

---

## Enhanced Reboot Step

### Features

- **Platform Detection**: Systemd, SysVinit, OpenRC
- **Virtualization Detection**: QEMU/KVM, Physical hardware
- **Pre-Reboot Health Check**: Disk space, package managers, system load
- **Boot ID Verification**: Confirms reboot actually occurred
- **Connection Dropout Detection**: Waits for system to go offline
- **Exponential Backoff Reconnection**: Efficient reconnection attempts
- **Post-Reboot Health Checks**: 7 comprehensive checks
- **QEMU/KVM Optimizations**: Faster timing for virtual machines
- **Hardware Considerations**: BIOS delays, disk checks accounted for

### Configuration

```json
{
  "type": "reboot",
  "value": "300",
  "graceful": true,
  "verify": true
}
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| value | String (seconds) | 300 | Timeout for reboot completion |
| graceful | Boolean | true | Use graceful shutdown vs forced |
| verify | Boolean | true | Perform health checks |
| maxRetries | Integer | 20 | Maximum reconnection attempts |

### Health Checks

1. **UPTIME**: Verify fresh boot (< 10 minutes)
2. **SYSTEMD**: Check systemd state and failed services
3. **NETWORK**: Verify network interfaces and DNS
4. **DISK**: Check filesystem mounts and read-only mounts
5. **TIME**: Verify time synchronization
6. **LOAD**: Check system load is reasonable
7. **MEMORY**: Verify sufficient available memory

### Platform-Specific Behavior

| Platform | Init Command | Timeout Adjustment |
|----------|-------------|-------------------|
| Systemd | `systemctl reboot` | Standard |
| SysVinit | `/sbin/shutdown -r now` | Standard |
| OpenRC | `openrc-shutdown -r now` | Standard |
| QEMU/KVM | Any | Reduced (faster boot) |
| Physical Hardware | Any | Increased (BIOS delay) |

### Workflow

```
1. Detect Platform & Virtualization
   ↓
2. Pre-Reboot Health Check
   ↓
3. Capture Boot ID
   ↓
4. Execute Reboot Command
   ↓
5. Wait for Connection Dropout (30s max)
   ↓
6. Wait for System Online (exponential backoff)
   ↓
7. Verify Boot ID Changed
   ↓
8. Post-Reboot Health Checks (7 checks)
   ↓
9. Success!
```

---

## Connection Pool Management

### Features

- **Connection Reuse**: Single connection per remote host
- **Reference Counting**: Track active users of each connection
- **Health Monitoring**: Periodic connection health checks
- **Idle Cleanup**: Automatic eviction of unused connections
- **Graceful Shutdown**: Drains active connections
- **Thread-Safe**: Concurrent access supported
- **Configurable Limits**: Max pool size, timeouts

### Configuration

```bash
# Environment variables
export MAIL_FACTORY_POOL_MAX_SIZE=10                    # Max connections
export MAIL_FACTORY_POOL_IDLE_TIMEOUT=300              # 5 minutes
export MAIL_FACTORY_POOL_HEALTH_CHECK_INTERVAL=60      # 1 minute
```

### API Reference

```kotlin
import net.milosvasic.factory.remote.ConnectionPool
import net.milosvasic.factory.remote.Remote

// Get connection from pool (reuses existing or creates new)
val connection = ConnectionPool.getConnection(remote)

// Use connection
connection.execute(command)

// Release connection back to pool (decrements ref count)
ConnectionPool.releaseConnection(remote)

// Force close specific connection
ConnectionPool.closeConnection(remote)

// Get pool statistics
val stats = ConnectionPool.getStats()
println(stats) // "ConnectionPool: total=5, active=2, idle=3, healthy=5, max=10"

// Shutdown pool gracefully (30s timeout)
ConnectionPool.shutdown(timeoutSeconds = 30)
```

### Lifecycle Management

```
┌─────────────────────────────────────────────┐
│ getConnection(remote)                       │
│   → New Connection Created                  │
│   → Reference Count = 1                     │
└──────────────┬──────────────────────────────┘
               │
┌──────────────▼──────────────────────────────┐
│ getConnection(remote) - SAME REMOTE         │
│   → Existing Connection Reused              │
│   → Reference Count = 2                     │
└──────────────┬──────────────────────────────┘
               │
┌──────────────▼──────────────────────────────┐
│ releaseConnection(remote)                   │
│   → Reference Count = 1                     │
└──────────────┬──────────────────────────────┘
               │
┌──────────────▼──────────────────────────────┐
│ releaseConnection(remote)                   │
│   → Reference Count = 0                     │
│   → Connection Idle (eligible for cleanup)  │
└──────────────┬──────────────────────────────┘
               │
┌──────────────▼──────────────────────────────┐
│ After Idle Timeout (5 minutes)              │
│   → Connection Evicted and Closed           │
└─────────────────────────────────────────────┘
```

---

## Usage Examples

### Example 1: Encrypting Database Password

```bash
# 1. Generate encrypted password
export MAIL_FACTORY_MASTER_KEY="my-strong-master-key-123"
java -jar Application.jar encrypt-password

# Enter password: dbpass123
# Enter password again: dbpass123
#
# Output: encrypted:aGfY...==:xQw2...==:zPm9...==

# 2. Update configuration
```

```json
{
  "variables": {
    "SERVICE": {
      "DATABASE": {
        "PASSWORD": "encrypted:aGfY...==:xQw2...==:zPm9...=="
      }
    }
  }
}
```

```bash
# 3. Run deployment
export MAIL_FACTORY_MASTER_KEY="my-strong-master-key-123"
./mail_factory Examples/Ubuntu_24.json
```

### Example 2: Using Environment Variables for Secrets

```bash
# Set all secrets via environment (no encryption needed)
export MAIL_FACTORY_DB_PASSWORD="dbpass123"
export MAIL_FACTORY_SSH_PASSWORD="sshpass456"
export MAIL_FACTORY_DOCKER_PASSWORD="dockerpass789"

# Run deployment (no master key needed)
./mail_factory Examples/Ubuntu_24.json
```

### Example 3: Input Validation in Configuration Loading

```kotlin
// Validate hostname from configuration
val hostname = config.getString("hostname")
when (val result = InputValidator.validateHost(hostname)) {
    is ValidationResult.Invalid -> {
        throw ConfigurationException("Invalid hostname: ${result.reason}")
    }
    is ValidationResult.Warning -> {
        Log.w("Hostname warning: ${result.message}")
    }
    is ValidationResult.Valid -> {
        // Continue
    }
}

// Validate port
val port = config.getInt("port")
when (val result = InputValidator.validatePort(port)) {
    is ValidationResult.Invalid -> {
        throw ConfigurationException("Invalid port: ${result.reason}")
    }
    is ValidationResult.Warning -> {
        Log.w("Port warning: ${result.message}")
    }
    is ValidationResult.Valid -> {
        // Continue
    }
}
```

### Example 4: Connection Pool Usage

```kotlin
// Automatic connection management
val remote = Remote(hostname, port, credentials)

try {
    // Get connection (reuses if exists)
    val connection = ConnectionPool.getConnection(remote)

    // Execute operations
    connection.execute(TerminalCommand("ls -la"))
    connection.execute(TerminalCommand("pwd"))

} finally {
    // Always release
    ConnectionPool.releaseConnection(remote)
}

// Multiple users of same connection
val conn1 = ConnectionPool.getConnection(remote) // ref count = 1
val conn2 = ConnectionPool.getConnection(remote) // ref count = 2 (reused!)

ConnectionPool.releaseConnection(remote) // ref count = 1
ConnectionPool.releaseConnection(remote) // ref count = 0 (idle)
```

---

## Testing

### Unit Tests

| Component | Test File | Tests | Coverage |
|-----------|-----------|-------|----------|
| Encryption | `EncryptionTest.kt` | 23 tests | 100% |
| InputValidator | `InputValidatorTest.kt` | 45 tests | 100% |

### Running Tests

```bash
# Run all security tests
./gradlew test --tests "net.milosvasic.factory.security.*"
./gradlew test --tests "net.milosvasic.factory.validation.*"

# Run specific test
./gradlew test --tests "EncryptionTest"
./gradlew test --tests "InputValidatorTest"

# Generate coverage report
./gradlew jacocoTestReport
open Core/Framework/build/reports/jacoco/test/html/index.html
```

### Test Coverage

**Encryption Tests** (23 total):
- Basic encryption/decryption ✓
- Different data types (passwords, JSON, Unicode) ✓
- Error handling (wrong key, tampered data) ✓
- Security properties (unique IVs, authentication) ✓
- Edge cases (large data, special characters) ✓
- Stress test (100 iterations) ✓

**InputValidator Tests** (45 total):
- Hostname validation (valid/invalid, IPv4, IPv6) ✓
- Port validation (valid ranges, privileged) ✓
- Username validation (length, characters) ✓
- Email validation (RFC 5322) ✓
- Path validation (traversal prevention) ✓
- Shell sanitization ✓
- Command validation (dangerous patterns) ✓
- Type inference ✓

---

## Security Best Practices

### 1. Master Key Management

**DO**:
- Use strong, random master key (16+ characters)
- Store in environment variable or secrets manager
- Use different keys for dev/staging/production
- Rotate keys periodically
- Keep keys out of version control

**DON'T**:
- Hard-code master key
- Commit master key to git
- Share master key in chat/email
- Use weak or guessable keys
- Reuse keys across environments

### 2. Password Encryption

**DO**:
- Encrypt all passwords in configuration
- Use PasswordEncryptor tool
- Test decryption before deployment
- Document master key location
- Use interactive mode (avoid shell history)

**DON'T**:
- Store plain text passwords
- Pass passwords on command line
- Share encrypted passwords without master key
- Reuse passwords across environments

### 3. Input Validation

**DO**:
- Validate ALL user input
- Use appropriate validation for data type
- Check ValidationResult status
- Log validation failures
- Sanitize before shell execution

**DON'T**:
- Trust user input
- Skip validation for "internal" data
- Ignore validation warnings
- Construct shell commands from raw input

### 4. Connection Management

**DO**:
- Use ConnectionPool for all SSH connections
- Always release connections
- Monitor pool statistics
- Shutdown pool on application exit
- Configure appropriate timeouts

**DON'T**:
- Create connections manually
- Forget to release connections
- Ignore connection errors
- Set infinite timeouts

### 5. Reboot Operations

**DO**:
- Use graceful reboot when possible
- Enable verification
- Set appropriate timeout
- Monitor health checks
- Test on target platform (QEMU vs hardware)

**DON'T**:
- Skip verification
- Use too short timeout
- Ignore health check failures
- Assume reboot succeeded without verification

---

## Migration Guide

### Migrating from Plain Text Passwords

#### Step 1: Identify All Passwords

Find all plain text passwords in configuration:

```bash
grep -r "password" Examples/
grep -r "PASSWORD" Examples/
```

#### Step 2: Generate Encrypted Passwords

```bash
export MAIL_FACTORY_MASTER_KEY="generate-strong-master-key"

# For each password
java -jar Application.jar encrypt-password
# Enter password, copy output
```

#### Step 3: Update Configuration Files

Replace:
```json
{
  "credentials": {
    "password": "plaintext123"
  }
}
```

With:
```json
{
  "credentials": {
    "password": "encrypted:ABC==:DEF==:GHI=="
  }
}
```

#### Step 4: Update Deployment Scripts

Add master key to environment:

```bash
#!/bin/bash
export MAIL_FACTORY_MASTER_KEY="your-master-key"
./mail_factory Examples/Ubuntu_24.json
```

#### Step 5: Test

```bash
# Test decryption
export MAIL_FACTORY_MASTER_KEY="your-master-key"
java -jar Application.jar decrypt-password "encrypted:ABC==:DEF==:GHI=="

# Test deployment
./mail_factory Examples/Ubuntu_24.json
```

#### Step 6: Rotate Plain Text Passwords

After migration, change all passwords to ensure old plain text versions are invalid.

### Migrating to Connection Pool

**Old Code**:
```kotlin
val connection = SSH(remote)
connection.execute(command)
// No cleanup - LEAK!
```

**New Code**:
```kotlin
try {
    val connection = ConnectionPool.getConnection(remote)
    connection.execute(command)
} finally {
    ConnectionPool.releaseConnection(remote)
}
```

### Migrating Reboot Steps

**Old Configuration**:
```json
{
  "type": "reboot",
  "value": "300"
}
```

**New Configuration** (Enhanced):
```json
{
  "type": "reboot",
  "value": "300",
  "graceful": true,
  "verify": true
}
```

---

## Appendix A: Security Checklist

- [ ] All passwords encrypted in configuration files
- [ ] Master key stored in environment variable
- [ ] Master key not in version control
- [ ] Different master keys for dev/staging/prod
- [ ] Input validation enabled for all user input
- [ ] Connection pool used for all SSH connections
- [ ] Reboot verification enabled
- [ ] Security tests passing (68 total)
- [ ] Secrets file has restricted permissions (600)
- [ ] Documentation reviewed and understood

---

## Appendix B: Troubleshooting

### "Master key not found" Error

**Cause**: `MAIL_FACTORY_MASTER_KEY` environment variable not set.

**Solution**:
```bash
export MAIL_FACTORY_MASTER_KEY="your-master-key"
```

### "Authentication failed" During Decryption

**Cause**: Wrong master key or tampered data.

**Solution**:
1. Verify master key is correct
2. Re-encrypt password with correct master key
3. Check data wasn't modified

### "ConnectionPool is full" Error

**Cause**: Max pool size reached (default: 10 connections).

**Solution**:
```bash
export MAIL_FACTORY_POOL_MAX_SIZE=20
```

Or check for connection leaks (missing `releaseConnection` calls).

### "Reboot verification failed - boot ID unchanged"

**Cause**: System didn't actually reboot.

**Solution**:
1. Check reboot command syntax
2. Verify user has reboot permissions
3. Check system logs
4. Increase timeout

### Validation Failures

**Cause**: Input doesn't meet validation criteria.

**Solution**:
1. Check validation error message
2. Correct input format
3. If legitimate input, file issue to enhance validation

---

## Appendix C: File Locations

```
Mail-Server-Factory/
├── Core/Framework/src/main/kotlin/net/milosvasic/factory/
│   ├── security/
│   │   ├── Encryption.kt                    # AES-256-GCM encryption
│   │   └── SecureConfiguration.kt           # Credential management
│   ├── validation/
│   │   └── InputValidator.kt                # Input validation
│   ├── remote/
│   │   └── ConnectionPool.kt                # Connection pooling
│   └── component/installer/step/reboot/
│       └── RebootStep.kt                    # Enhanced reboot
├── Core/Framework/src/test/kotlin/net/milosvasic/factory/
│   ├── security/
│   │   └── EncryptionTest.kt                # Encryption tests (23)
│   └── validation/
│       └── InputValidatorTest.kt            # Validation tests (45)
├── Application/src/main/kotlin/net/milosvasic/factory/mail/tools/
│   └── PasswordEncryptor.kt                 # CLI encryption tool
└── SECURITY_IMPLEMENTATION_GUIDE.md         # This document
```

---

**Document Version**: 1.0
**Last Updated**: 2025-10-24
**Author**: Mail Server Factory Team
**License**: Same as Mail Server Factory project

