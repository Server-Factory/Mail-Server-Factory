# Critical Issues Fixes - Implementation Plan

**Date**: 2025-10-24
**Priority**: P0 - CRITICAL
**Status**: 🔴 IN PROGRESS

---

## Overview

This document outlines the implementation plan for fixing **all critical and high-priority issues** identified in the stability, safety, and performance analysis, plus implementing comprehensive connection mechanisms.

---

## Part 1: Critical Issues (P0) - IMMEDIATE

### Issue #18: Passwords in Plain Text

**Current State**:
```json
{
  "accounts": [
    {
      "email": "user@example.com",
      "password": "plaintext_password"
    }
  ]
}
```

**Problems**:
- Passwords visible in configuration files
- Passwords in version control
- Compliance violations (PCI-DSS, GDPR, HIPAA)
- No encryption at rest

**Solution Implementation**:

#### 1. Add Encryption Layer
**File**: `Core/Framework/src/main/kotlin/net/milosvasic/factory/security/Encryption.kt`
```kotlin
package net.milosvasic.factory.security

import java.security.SecureRandom
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/**
 * AES-256-GCM encryption for sensitive data
 */
object Encryption {

    private const val ALGORITHM = "AES/GCM/NoPadding"
    private const val KEY_ALGORITHM = "PBKDF2WithHmacSHA256"
    private const val KEY_LENGTH = 256
    private const val ITERATION_COUNT = 65536
    private const val GCM_TAG_LENGTH = 128
    private const val GCM_IV_LENGTH = 12

    /**
     * Encrypt data using AES-256-GCM
     */
    fun encrypt(data: String, masterKey: String): String {
        val salt = generateSalt()
        val key = deriveKey(masterKey, salt)
        val iv = generateIV()

        val cipher = Cipher.getInstance(ALGORITHM)
        val gcmSpec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
        cipher.init(Cipher.ENCRYPT_MODE, key, gcmSpec)

        val encrypted = cipher.doFinal(data.toByteArray())

        // Format: salt:iv:encrypted
        return "${Base64.getEncoder().encodeToString(salt)}:${Base64.getEncoder().encodeToString(iv)}:${Base64.getEncoder().encodeToString(encrypted)}"
    }

    /**
     * Decrypt data using AES-256-GCM
     */
    fun decrypt(encryptedData: String, masterKey: String): String {
        val parts = encryptedData.split(":")
        require(parts.size == 3) { "Invalid encrypted data format" }

        val salt = Base64.getDecoder().decode(parts[0])
        val iv = Base64.getDecoder().decode(parts[1])
        val encrypted = Base64.getDecoder().decode(parts[2])

        val key = deriveKey(masterKey, salt)

        val cipher = Cipher.getInstance(ALGORITHM)
        val gcmSpec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
        cipher.init(Cipher.DECRYPT_MODE, key, gcmSpec)

        val decrypted = cipher.doFinal(encrypted)
        return String(decrypted)
    }

    private fun deriveKey(password: String, salt: ByteArray): SecretKey {
        val factory = SecretKeyFactory.getInstance(KEY_ALGORITHM)
        val spec = PBEKeySpec(password.toCharArray(), salt, ITERATION_COUNT, KEY_LENGTH)
        val tmp = factory.generateSecret(spec)
        return SecretKeySpec(tmp.encoded, "AES")
    }

    private fun generateSalt(): ByteArray {
        val salt = ByteArray(16)
        SecureRandom().nextBytes(salt)
        return salt
    }

    private fun generateIV(): ByteArray {
        val iv = ByteArray(GCM_IV_LENGTH)
        SecureRandom().nextBytes(iv)
        return iv
    }
}
```

#### 2. Create Secure Configuration Handler
**File**: `Core/Framework/src/main/kotlin/net/milosvasic/factory/configuration/SecureConfiguration.kt`
```kotlin
package net.milosvasic.factory.configuration

import net.milosvasic.factory.security.Encryption

/**
 * Secure configuration with encrypted passwords
 */
data class SecureCredentials(
    val username: String,
    val encryptedPassword: String,
    val isEncrypted: Boolean = true
) {
    fun getPassword(masterKey: String): String {
        return if (isEncrypted) {
            Encryption.decrypt(encryptedPassword, masterKey)
        } else {
            encryptedPassword // Fallback for plain text (deprecated)
        }
    }
}

/**
 * Utility to encrypt passwords in configuration
 */
object ConfigurationEncryption {

    /**
     * Encrypt a plain text password
     */
    fun encryptPassword(plainPassword: String, masterKey: String): String {
        return Encryption.encrypt(plainPassword, masterKey)
    }

    /**
     * Validate master key strength
     */
    fun validateMasterKey(key: String): Boolean {
        return key.length >= 16 &&
               key.any { it.isUpperCase() } &&
               key.any { it.isLowerCase() } &&
               key.any { it.isDigit() } &&
               key.any { !it.isLetterOrDigit() }
    }
}
```

#### 3. CLI Tool for Password Encryption
**File**: `Application/src/main/kotlin/net/milosvasic/factory/mail/tools/PasswordEncryptor.kt`
```kotlin
package net.milosvasic.factory.mail.tools

import net.milosvasic.factory.configuration.ConfigurationEncryption
import java.io.Console

/**
 * CLI tool to encrypt passwords for configuration files
 */
object PasswordEncryptor {

    @JvmStatic
    fun main(args: Array<String>) {
        println("=".repeat(70))
        println("  Mail Server Factory - Password Encryption Tool")
        println("=".repeat(70))
        println()

        val console = System.console()
        if (console == null) {
            System.err.println("ERROR: No console available")
            System.exit(1)
        }

        // Get master key
        print("Enter master encryption key (min 16 chars, mixed case, numbers, symbols): ")
        val masterKey = String(console.readPassword())

        if (!ConfigurationEncryption.validateMasterKey(masterKey)) {
            System.err.println("ERROR: Master key does not meet requirements")
            System.err.println("Requirements:")
            System.err.println("  - Minimum 16 characters")
            System.err.println("  - At least one uppercase letter")
            System.err.println("  - At least one lowercase letter")
            System.err.println("  - At least one digit")
            System.err.println("  - At least one special character")
            System.exit(1)
        }

        println()
        println("Master key accepted. You can now encrypt passwords.")
        println("NOTE: Store this master key securely! You'll need it to decrypt.")
        println()

        while (true) {
            print("Enter password to encrypt (or 'quit' to exit): ")
            val password = String(console.readPassword())

            if (password.equals("quit", ignoreCase = true)) {
                break
            }

            if (password.isEmpty()) {
                println("ERROR: Password cannot be empty")
                continue
            }

            val encrypted = ConfigurationEncryption.encryptPassword(password, masterKey)
            println()
            println("Encrypted password:")
            println(encrypted)
            println()
            println("Use this in your configuration file:")
            println("""
                {
                  "credentials": {
                    "username": "your-username",
                    "encryptedPassword": "$encrypted",
                    "isEncrypted": true
                  }
                }
            """.trimIndent())
            println()
        }

        println("Done!")
    }
}
```

#### 4. Update Configuration Format
**New Configuration Format** (`Examples/Includes/_Docker.json`):
```json
{
  "variables": {
    "DOCKER": {
      "LOGIN": {
        "ACCOUNT": "your-dockerhub-username",
        "ENCRYPTED_PASSWORD": "base64_salt:base64_iv:base64_encrypted",
        "IS_ENCRYPTED": true
      }
    }
  }
}
```

#### 5. Environment Variable Support
**File**: `Core/Framework/src/main/kotlin/net/milosvasic/factory/configuration/EnvironmentConfig.kt`
```kotlin
package net.milosvasic.factory.configuration

/**
 * Support for environment variables in configuration
 */
object EnvironmentConfig {

    private const val PREFIX = "MAIL_FACTORY_"

    /**
     * Get master encryption key from environment
     */
    fun getMasterKey(): String? {
        return System.getenv("${PREFIX}MASTER_KEY")
    }

    /**
     * Get configuration value from environment or default
     */
    fun get(key: String, default: String? = null): String? {
        return System.getenv("${PREFIX}${key.uppercase()}") ?: default
    }

    /**
     * Check if running in secure mode
     */
    fun isSecureMode(): Boolean {
        return System.getenv("${PREFIX}SECURE_MODE")?.toBoolean() ?: true
    }
}
```

---

### Issue #9: No Input Validation

**Current State**: Variables substituted directly into shell commands without sanitization

**Solution Implementation**:

#### 1. Input Validator
**File**: `Core/Framework/src/main/kotlin/net/milosvasic/factory/validation/InputValidator.kt`
```kotlin
package net.milosvasic.factory.validation

/**
 * Input validation to prevent command injection
 */
object InputValidator {

    private val HOSTNAME_PATTERN = Regex("^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$")
    private val IP_PATTERN = Regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$")
    private val PORT_RANGE = 1..65535
    private val USERNAME_PATTERN = Regex("^[a-zA-Z0-9._-]{1,32}$")
    private val EMAIL_PATTERN = Regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
    private val PATH_PATTERN = Regex("^[a-zA-Z0-9/_.-]+$")

    // Dangerous characters that could lead to command injection
    private val SHELL_DANGEROUS_CHARS = setOf(';', '&', '|', '`', '$', '(', ')', '<', '>', '\n', '\r')

    /**
     * Validate hostname or IP address
     */
    fun validateHost(host: String): ValidationResult {
        return when {
            host.isEmpty() -> ValidationResult.Invalid("Hostname cannot be empty")
            host.matches(HOSTNAME_PATTERN) -> ValidationResult.Valid
            host.matches(IP_PATTERN) -> ValidationResult.Valid
            else -> ValidationResult.Invalid("Invalid hostname or IP address: $host")
        }
    }

    /**
     * Validate port number
     */
    fun validatePort(port: Int): ValidationResult {
        return if (port in PORT_RANGE) {
            ValidationResult.Valid
        } else {
            ValidationResult.Invalid("Port must be between 1 and 65535, got: $port")
        }
    }

    /**
     * Validate username
     */
    fun validateUsername(username: String): ValidationResult {
        return when {
            username.isEmpty() -> ValidationResult.Invalid("Username cannot be empty")
            !username.matches(USERNAME_PATTERN) -> ValidationResult.Invalid("Invalid username format: $username")
            username.length > 32 -> ValidationResult.Invalid("Username too long (max 32 chars): $username")
            else -> ValidationResult.Valid
        }
    }

    /**
     * Validate email address
     */
    fun validateEmail(email: String): ValidationResult {
        return when {
            email.isEmpty() -> ValidationResult.Invalid("Email cannot be empty")
            !email.matches(EMAIL_PATTERN) -> ValidationResult.Invalid("Invalid email format: $email")
            email.length > 254 -> ValidationResult.Invalid("Email too long (max 254 chars): $email")
            else -> ValidationResult.Valid
        }
    }

    /**
     * Validate file path
     */
    fun validatePath(path: String): ValidationResult {
        return when {
            path.isEmpty() -> ValidationResult.Invalid("Path cannot be empty")
            path.contains("..") -> ValidationResult.Invalid("Path cannot contain '..' (path traversal)")
            !path.matches(PATH_PATTERN) -> ValidationResult.Invalid("Invalid path format: $path")
            else -> ValidationResult.Valid
        }
    }

    /**
     * Sanitize string for shell command execution
     */
    fun sanitizeForShell(input: String): String {
        // Remove any dangerous characters
        val cleaned = input.filter { it !in SHELL_DANGEROUS_CHARS }

        // Escape single quotes
        val escaped = cleaned.replace("'", "'\\''")

        // Wrap in single quotes
        return "'$escaped'"
    }

    /**
     * Validate and sanitize variable value
     */
    fun validateVariable(name: String, value: String, type: VariableType): ValidationResult {
        return when (type) {
            VariableType.HOSTNAME -> validateHost(value)
            VariableType.PORT -> {
                val port = value.toIntOrNull()
                if (port != null) validatePort(port) else ValidationResult.Invalid("Port must be a number: $value")
            }
            VariableType.USERNAME -> validateUsername(value)
            VariableType.EMAIL -> validateEmail(value)
            VariableType.PATH -> validatePath(value)
            VariableType.STRING -> {
                if (value.any { it in SHELL_DANGEROUS_CHARS }) {
                    ValidationResult.Warning("String contains potentially dangerous characters: $value")
                } else {
                    ValidationResult.Valid
                }
            }
        }
    }
}

enum class VariableType {
    HOSTNAME,
    PORT,
    USERNAME,
    EMAIL,
    PATH,
    STRING
}

sealed class ValidationResult {
    object Valid : ValidationResult()
    data class Invalid(val reason: String) : ValidationResult()
    data class Warning(val message: String) : ValidationResult()

    fun isValid(): Boolean = this is Valid
    fun isInvalid(): Boolean = this is Invalid
    fun isWarning(): Boolean = this is Warning
}
```

#### 2. Variable Type Annotations
**File**: `Core/Framework/src/main/kotlin/net/milosvasic/factory/configuration/VariableAnnotation.kt`
```kotlin
package net.milosvasic.factory.configuration

/**
 * Annotation for variable types in configuration
 */
@Target(AnnotationTarget.FIELD, AnnotationTarget.PROPERTY)
@Retention(AnnotationRetention.RUNTIME)
annotation class VariableTypeAnnotation(
    val type: String, // "hostname", "port", "username", "email", "path", "string"
    val required: Boolean = true,
    val description: String = ""
)
```

#### 3. Update Variable Substitution
**File**: `Core/Framework/src/main/kotlin/net/milosvasic/factory/configuration/Variable.kt` (Update)
```kotlin
// Add validation before substitution
fun substitute(template: String, variables: Map<String, String>): String {
    var result = template

    variables.forEach { (key, value) ->
        // Determine variable type from key name
        val type = inferVariableType(key)

        // Validate
        val validation = InputValidator.validateVariable(key, value, type)

        when (validation) {
            is ValidationResult.Invalid -> {
                throw IllegalArgumentException("Invalid value for $key: ${validation.reason}")
            }
            is ValidationResult.Warning -> {
                logger.warn("Warning for $key: ${validation.message}")
                // Sanitize value
                val sanitized = InputValidator.sanitizeForShell(value)
                result = result.replace("{{$key}}", sanitized)
            }
            ValidationResult.Valid -> {
                result = result.replace("{{$key}}", value)
            }
        }
    }

    return result
}

private fun inferVariableType(key: String): VariableType {
    return when {
        key.contains("HOSTNAME") || key.contains("HOST") -> VariableType.HOSTNAME
        key.contains("PORT") -> VariableType.PORT
        key.contains("USER") || key.contains("ACCOUNT") -> VariableType.USERNAME
        key.contains("EMAIL") -> VariableType.EMAIL
        key.contains("PATH") || key.contains("DIR") || key.contains("HOME") -> VariableType.PATH
        else -> VariableType.STRING
    }
}
```

---

## Part 2: High Priority Issues (P1)

### Issue #1: SSH Connection Pooling Leak

**Solution**:
```kotlin
// File: Core/Framework/src/main/kotlin/net/milosvasic/factory/remote/Connection.kt

class ConnectionPool(
    private val maxConnections: Int = 10,
    private val connectionTimeout: Long = 30000L,
    private val maxIdleTime: Long = 300000L // 5 minutes
) {
    private val connections = ConcurrentHashMap<String, PooledConnection>()
    private val cleanupScheduler = Executors.newScheduledThreadPool(1)

    init {
        // Schedule periodic cleanup of idle connections
        cleanupScheduler.scheduleAtFixedRate({
            cleanupIdleConnections()
        }, 1, 1, TimeUnit.MINUTES)
    }

    data class PooledConnection(
        val connection: SSH,
        val createdAt: Long,
        var lastUsedAt: Long,
        var useCount: Int = 0
    ) {
        fun isHealthy(): Boolean {
            return connection.isConnected() &&
                   System.currentTimeMillis() - lastUsedAt < maxIdleTime
        }
    }

    fun getConnection(host: String): SSH {
        val pooled = connections.computeIfAbsent(host) {
            PooledConnection(
                connection = createConnection(host),
                createdAt = System.currentTimeMillis(),
                lastUsedAt = System.currentTimeMillis()
            )
        }

        if (!pooled.isHealthy()) {
            pooled.connection.disconnect()
            val newConnection = createConnection(host)
            connections[host] = PooledConnection(
                connection = newConnection,
                createdAt = System.currentTimeMillis(),
                lastUsedAt = System.currentTimeMillis()
            )
            return newConnection
        }

        pooled.lastUsedAt = System.currentTimeMillis()
        pooled.useCount++
        return pooled.connection
    }

    private fun cleanupIdleConnections() {
        val now = System.currentTimeMillis()
        connections.entries.removeIf { (_, pooled) ->
            if (now - pooled.lastUsedAt > maxIdleTime) {
                pooled.connection.disconnect()
                true
            } else {
                false
            }
        }
    }

    fun shutdown() {
        cleanupScheduler.shutdown()
        connections.values.forEach { it.connection.disconnect() }
        connections.clear()
    }
}
```

### Issue #2: Reboot Verification

**Solution**:
```kotlin
// File: Core/Framework/src/main/kotlin/net/milosvasic/factory/component/installer/step/RebootStep.kt

class RebootStep(private val timeout: Long = 480000L) : InstallationStep {

    override fun execute(connection: SSH): StepResult {
        logger.info("Initiating system reboot...")

        // Send reboot command
        connection.execute("reboot")

        // Wait for connection to drop
        Thread.sleep(10000) // 10 seconds

        // Verify system comes back
        val startTime = System.currentTimeMillis()
        var systemUp = false

        while (System.currentTimeMillis() - startTime < timeout) {
            try {
                // Try to reconnect
                if (connection.reconnect()) {
                    // Verify system is actually up
                    if (verifySystemHealthy(connection)) {
                        systemUp = true
                        break
                    }
                }
            } catch (e: Exception) {
                // Expected during reboot
            }

            Thread.sleep(5000) // Wait 5 seconds before retry
        }

        return if (systemUp) {
            StepResult.Success("System rebooted successfully")
        } else {
            StepResult.Failure("System failed to come back after reboot (timeout: ${timeout}ms)")
        }
    }

    private fun verifySystemHealthy(connection: SSH): Boolean {
        return try {
            // Check system is responsive
            val result = connection.execute("echo 'ping'")
            if (result.output != "ping") return false

            // Check systemd is running
            val systemdResult = connection.execute("systemctl is-system-running")
            val systemdStatus = systemdResult.output.trim()
            systemdStatus in listOf("running", "degraded")

        } catch (e: Exception) {
            false
        }
    }
}
```

---

## Part 3: Connection Mechanisms Extension

### New Connection Types to Implement

1. **SSH** (existing - enhance)
2. **SSH with Key Agent**
3. **SSH with Certificate**
4. **SSH with Bastion/Jump Host**
5. **WinRM** (Windows Remote Management)
6. **Ansible** (via Ansible inventory)
7. **Docker** (direct container execution)
8. **Kubernetes** (kubectl exec)
9. **AWS SSM** (Systems Manager Session Manager)
10. **Azure VM Serial Console**
11. **GCP OS Login**
12. **Local** (localhost execution)

### Connection Interface Design

```kotlin
// File: Core/Framework/src/main/kotlin/net/milosvasic/factory/remote/Connection.kt

interface Connection : AutoCloseable {
    /**
     * Connect to remote system
     */
    fun connect(): ConnectionResult

    /**
     * Check if connected
     */
    fun isConnected(): Boolean

    /**
     * Execute command on remote system
     */
    fun execute(command: String): ExecutionResult

    /**
     * Transfer file to remote system
     */
    fun uploadFile(localPath: String, remotePath: String): TransferResult

    /**
     * Download file from remote system
     */
    fun downloadFile(remotePath: String, localPath: String): TransferResult

    /**
     * Disconnect from remote system
     */
    fun disconnect()

    /**
     * Get connection metadata
     */
    fun getMetadata(): ConnectionMetadata
}

data class ConnectionMetadata(
    val type: ConnectionType,
    val target: String,
    val connectedAt: Long,
    val lastUsed: Long,
    val commandsExecuted: Int
)

enum class ConnectionType {
    SSH,
    SSH_KEY_AGENT,
    SSH_CERTIFICATE,
    SSH_BASTION,
    WINRM,
    ANSIBLE,
    DOCKER,
    KUBERNETES,
    AWS_SSM,
    AZURE_SERIAL,
    GCP_OS_LOGIN,
    LOCAL
}
```

This is comprehensive - I'll create this implementation plan document and continue with the actual implementations in the next steps.

---

**Status**: Implementation plan created. Ready to implement all fixes and enhancements.
