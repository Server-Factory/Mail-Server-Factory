package net.milosvasic.factory.mail.security

import net.milosvasic.factory.mail.BuildInfo
import java.security.SecureRandom
import java.util.*
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * Enterprise-grade security configuration for Mail Server Factory
 */
object SecurityConfig {

    // Encryption settings
    const val AES_KEY_SIZE = 256
    const val GCM_IV_LENGTH = 96
    const val GCM_TAG_LENGTH = 128

    // Password policy
    const val MIN_PASSWORD_LENGTH = 12
    const val MAX_PASSWORD_LENGTH = 128
    const val REQUIRE_UPPERCASE = true
    const val REQUIRE_LOWERCASE = true
    const val REQUIRE_DIGITS = true
    const val REQUIRE_SPECIAL_CHARS = true

    // Session settings
    const val SESSION_TIMEOUT_MINUTES = 30
    const val MAX_LOGIN_ATTEMPTS = 5
    const val LOCKOUT_DURATION_MINUTES = 15

    // Audit settings
    const val ENABLE_AUDIT_LOGGING = true
    const val AUDIT_LOG_RETENTION_DAYS = 90

    // Network security
    const val ENABLE_TLS_ENFORCEMENT = true
    const val ENABLE_HSTS = true
    const val HSTS_MAX_AGE_SECONDS = 31536000 // 1 year

    // API security
    const val ENABLE_RATE_LIMITING = true
    const val RATE_LIMIT_REQUESTS_PER_MINUTE = 100
    const val RATE_LIMIT_BURST_SIZE = 200
    const val ENABLE_CORS = false
    const val CORS_ALLOWED_ORIGINS = ""
    const val ENABLE_API_KEY_AUTH = true
    const val API_KEY_HEADER_NAME = "X-API-Key"

    // TLS/SSL configuration
    const val TLS_PROTOCOL = "TLSv1.3"
    const val ENABLE_CLIENT_CERT_AUTH = false
    const val CERTIFICATE_REVOCATION_CHECK = true
    const val OCSP_ENABLED = true

    // Session management
    const val SESSION_COOKIE_NAME = "MAIL_SESSION"
    const val SESSION_COOKIE_SECURE = true
    const val SESSION_COOKIE_HTTP_ONLY = true
    const val SESSION_COOKIE_SAME_SITE = "Strict"
    const val ENABLE_SESSION_FIXATION_PROTECTION = true
    const val ENABLE_CONCURRENT_SESSION_CONTROL = true
    const val MAX_CONCURRENT_SESSIONS_PER_USER = 3

    // CSRF protection
    const val ENABLE_CSRF_PROTECTION = true
    const val CSRF_TOKEN_HEADER_NAME = "X-CSRF-Token"
    const val CSRF_TOKEN_COOKIE_NAME = "CSRF-TOKEN"

    // Content Security Policy
    const val ENABLE_CSP = true
    const val CSP_DEFAULT_SRC = "'self'"
    const val CSP_SCRIPT_SRC = "'self' 'unsafe-inline'"
    const val CSP_STYLE_SRC = "'self' 'unsafe-inline'"
    const val CSP_IMG_SRC = "'self' data: https:"
    const val CSP_CONNECT_SRC = "'self'"

    // Security headers
    const val ENABLE_SECURITY_HEADERS = true
    const val X_FRAME_OPTIONS = "DENY"
    const val X_CONTENT_TYPE_OPTIONS = "nosniff"
    const val REFERRER_POLICY = "strict-origin-when-cross-origin"

    // Key management
    val secureRandom = SecureRandom()
    private var masterKey: SecretKey? = null
    private val apiKeys = mutableSetOf<String>()
    private val rateLimitCache = mutableMapOf<String, RateLimitInfo>()

    /**
     * Initialize security components
     */
    fun initialize() {
        generateMasterKey()
        SecurityAuditor.initialize()
        SessionManager // Initialize session manager
        TlsConfig.initialize() // Initialize TLS with default settings
    }

    /**
     * Generate or load master encryption key
     */
    private fun generateMasterKey() {
        // In production, this should load from secure key store
        val keyGen = KeyGenerator.getInstance("AES")
        keyGen.init(AES_KEY_SIZE, secureRandom)
        masterKey = keyGen.generateKey()
    }

    /**
     * Get master encryption key
     */
    fun getMasterKey(): SecretKey {
        return masterKey ?: throw SecurityException("Security not initialized")
    }

    /**
     * Generate secure random token
     */
    fun generateSecureToken(length: Int = 32): String {
        val bytes = ByteArray(length)
        secureRandom.nextBytes(bytes)
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
    }

    /**
     * Validate password strength
     */
    fun validatePasswordStrength(password: String): PasswordValidationResult {
        val issues = mutableListOf<String>()

        if (password.length < MIN_PASSWORD_LENGTH) {
            issues.add("Password must be at least $MIN_PASSWORD_LENGTH characters long")
        }

        if (password.length > MAX_PASSWORD_LENGTH) {
            issues.add("Password must not exceed $MAX_PASSWORD_LENGTH characters")
        }

        if (REQUIRE_UPPERCASE && !password.any { it.isUpperCase() }) {
            issues.add("Password must contain at least one uppercase letter")
        }

        if (REQUIRE_LOWERCASE && !password.any { it.isLowerCase() }) {
            issues.add("Password must contain at least one lowercase letter")
        }

        if (REQUIRE_DIGITS && !password.any { it.isDigit() }) {
            issues.add("Password must contain at least one digit")
        }

        if (REQUIRE_SPECIAL_CHARS && !password.any { !it.isLetterOrDigit() }) {
            issues.add("Password must contain at least one special character")
        }

        // Check for common weak patterns
        val weakPatterns = listOf(
            "password", "123456", "qwerty", "admin", "root",
            password.lowercase(), password.reversed()
        )

        if (weakPatterns.any { password.lowercase().contains(it) }) {
            issues.add("Password contains common weak patterns")
        }

        return if (issues.isEmpty()) {
            PasswordValidationResult.Valid
        } else {
            PasswordValidationResult.Invalid(issues)
        }
    }

    /**
     * Encrypt sensitive data
     */
    fun encryptData(data: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val iv = ByteArray(GCM_IV_LENGTH / 8)
        secureRandom.nextBytes(iv)

        val spec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
        cipher.init(Cipher.ENCRYPT_MODE, getMasterKey(), spec)

        val encrypted = cipher.doFinal(data.toByteArray(Charsets.UTF_8))
        val combined = iv + encrypted

        return Base64.getEncoder().encodeToString(combined)
    }

    /**
     * Decrypt sensitive data
     */
    fun decryptData(encryptedData: String): String {
        val combined = Base64.getDecoder().decode(encryptedData)
        val iv = combined.copyOfRange(0, GCM_IV_LENGTH / 8)
        val encrypted = combined.copyOfRange(GCM_IV_LENGTH / 8, combined.size)

        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val spec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
        cipher.init(Cipher.DECRYPT_MODE, getMasterKey(), spec)

        val decrypted = cipher.doFinal(encrypted)
        return String(decrypted, Charsets.UTF_8)
    }

    /**
     * Sanitize data for logging (remove sensitive information)
     */
    fun sanitizeForLogging(data: String): String {
        // Remove passwords, tokens, keys, etc.
        return data.replace(Regex("password[\"\\s]*[:=][\"\\s]*[^\\s,\"]+"), "password=***")
                .replace(Regex("token[\"\\s]*[:=][\"\\s]*[^\\s,\"]+"), "token=***")
                .replace(Regex("key[\"\\s]*[:=][\"\\s]*[^\\s,\"]+"), "key=***")
                .replace(Regex("secret[\"\\s]*[:=][\"\\s]*[^\\s,\"]+"), "secret=***")
    }

    /**
     * Check rate limit for a client
     */
    fun checkRateLimit(clientId: String): Boolean {
        if (!ENABLE_RATE_LIMITING) return true

        val now = System.currentTimeMillis()
        val windowStart = now - 60000 // 1 minute window

        val limitInfo = rateLimitCache[clientId] ?: RateLimitInfo()

        // Clean old requests outside the window
        limitInfo.requests.removeIf { it < windowStart }

        return if (limitInfo.requests.size < RATE_LIMIT_REQUESTS_PER_MINUTE) {
            limitInfo.requests.add(now)
            rateLimitCache[clientId] = limitInfo
            true
        } else {
            SecurityAuditor.logSecurityViolation("Rate limit exceeded", ipAddress = clientId)
            false
        }
    }

    /**
     * Validate API key
     */
    fun validateApiKey(apiKey: String?): Boolean {
        if (!ENABLE_API_KEY_AUTH) return true
        return apiKey != null && apiKeys.contains(apiKey)
    }

    /**
     * Add API key
     */
    fun addApiKey(apiKey: String) {
        apiKeys.add(apiKey)
        SecurityAuditor.logConfigurationChange("API key added", details = mapOf("key_hash" to apiKey.hashCode().toString()))
    }

    /**
     * Remove API key
     */
    fun removeApiKey(apiKey: String) {
        apiKeys.remove(apiKey)
        SecurityAuditor.logConfigurationChange("API key removed", details = mapOf("key_hash" to apiKey.hashCode().toString()))
    }

    /**
     * Generate CSRF token
     */
    fun generateCsrfToken(): String {
        return generateSecureToken(32)
    }

    /**
     * Validate CSRF token
     */
    fun validateCsrfToken(sessionToken: String?, requestToken: String?): Boolean {
        if (!ENABLE_CSRF_PROTECTION) return true
        return sessionToken != null && requestToken != null && sessionToken == requestToken
    }

    /**
     * Get Content Security Policy header value
     */
    fun getCspHeaderValue(): String {
        if (!ENABLE_CSP) return ""

        return "default-src $CSP_DEFAULT_SRC; " +
               "script-src $CSP_SCRIPT_SRC; " +
               "style-src $CSP_STYLE_SRC; " +
               "img-src $CSP_IMG_SRC; " +
               "connect-src $CSP_CONNECT_SRC"
    }

    /**
     * Get security headers map
     */
    fun getSecurityHeaders(): Map<String, String> {
        if (!ENABLE_SECURITY_HEADERS) return emptyMap()

        return mapOf(
            "X-Frame-Options" to X_FRAME_OPTIONS,
            "X-Content-Type-Options" to X_CONTENT_TYPE_OPTIONS,
            "Referrer-Policy" to REFERRER_POLICY,
            "Strict-Transport-Security" to "max-age=$HSTS_MAX_AGE_SECONDS; includeSubDomains; preload"
        )
    }

    /**
     * Validate TLS configuration
     */
    fun validateTlsConfiguration(): List<String> {
        val issues = mutableListOf<String>()

        if (TLS_PROTOCOL != "TLSv1.3" && TLS_PROTOCOL != "TLSv1.2") {
            issues.add("TLS protocol should be TLSv1.3 or TLSv1.2")
        }

        if (ENABLE_CLIENT_CERT_AUTH && !CERTIFICATE_REVOCATION_CHECK) {
            issues.add("Certificate revocation checking should be enabled when client certificates are required")
        }

        return issues
    }

    /**
     * Get security configuration summary
     */
    fun getSecuritySummary(): Map<String, Any> {
        return mapOf(
            "encryption" to mapOf(
                "algorithm" to "AES-$AES_KEY_SIZE-GCM",
                "key_size" to AES_KEY_SIZE,
                "iv_length" to GCM_IV_LENGTH,
                "tag_length" to GCM_TAG_LENGTH
            ),
            "password_policy" to mapOf(
                "min_length" to MIN_PASSWORD_LENGTH,
                "max_length" to MAX_PASSWORD_LENGTH,
                "require_uppercase" to REQUIRE_UPPERCASE,
                "require_lowercase" to REQUIRE_LOWERCASE,
                "require_digits" to REQUIRE_DIGITS,
                "require_special_chars" to REQUIRE_SPECIAL_CHARS
            ),
            "session_security" to mapOf(
                "timeout_minutes" to SESSION_TIMEOUT_MINUTES,
                "max_attempts" to MAX_LOGIN_ATTEMPTS,
                "lockout_duration" to LOCKOUT_DURATION_MINUTES,
                "secure_cookie" to SESSION_COOKIE_SECURE,
                "http_only" to SESSION_COOKIE_HTTP_ONLY,
                "same_site" to SESSION_COOKIE_SAME_SITE
            ),
            "api_security" to mapOf(
                "rate_limiting" to ENABLE_RATE_LIMITING,
                "requests_per_minute" to RATE_LIMIT_REQUESTS_PER_MINUTE,
                "cors_enabled" to ENABLE_CORS,
                "api_key_auth" to ENABLE_API_KEY_AUTH,
                "csrf_protection" to ENABLE_CSRF_PROTECTION
            ),
            "network_security" to mapOf(
                "tls_enforcement" to ENABLE_TLS_ENFORCEMENT,
                "hsts" to ENABLE_HSTS,
                "client_cert_auth" to ENABLE_CLIENT_CERT_AUTH,
                "csp" to ENABLE_CSP
            ),
            "audit" to mapOf(
                "enabled" to ENABLE_AUDIT_LOGGING,
                "retention_days" to AUDIT_LOG_RETENTION_DAYS
            )
        )
    }
}

/**
 * Rate limiting information
 */
data class RateLimitInfo(
    val requests: MutableList<Long> = mutableListOf()
)

/**
 * Password validation result
 */
sealed class PasswordValidationResult {
    object Valid : PasswordValidationResult()
    data class Invalid(val issues: List<String>) : PasswordValidationResult()
}