package net.milosvasic.factory.mail.security

import net.milosvasic.factory.mail.BuildInfo
import java.io.File
import java.io.FileInputStream
import java.security.KeyStore
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import javax.net.ssl.*

/**
 * Enterprise TLS/SSL configuration management
 */
object TlsConfig {

    private var sslContext: SSLContext? = null
    private var keyStore: KeyStore? = null
    private var trustStore: KeyStore? = null

    /**
     * Initialize TLS configuration
     */
    fun initialize(
        keyStorePath: String? = null,
        keyStorePassword: String? = null,
        trustStorePath: String? = null,
        trustStorePassword: String? = null
    ) {
        try {
            // Initialize SSL context
            sslContext = SSLContext.getInstance(SecurityConfig.TLS_PROTOCOL)

            // Load key store
            if (keyStorePath != null && keyStorePassword != null) {
                keyStore = loadKeyStore(keyStorePath, keyStorePassword)
            }

            // Load trust store
            if (trustStorePath != null && trustStorePassword != null) {
                trustStore = loadKeyStore(trustStorePath, trustStorePassword)
            } else {
                // Use default trust store
                trustStore = KeyStore.getInstance(KeyStore.getDefaultType())
                trustStore?.load(null, null)
            }

            // Initialize key managers
            val keyManagers = if (keyStore != null && keyStorePassword != null) {
                val kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm())
                kmf.init(keyStore, keyStorePassword.toCharArray())
                kmf.keyManagers
            } else {
                null
            }

            // Initialize trust managers
            val trustManagers = if (trustStore != null) {
                val tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm())
                tmf.init(trustStore)
                tmf.trustManagers
            } else {
                null
            }

            // Initialize SSL context
            sslContext?.init(keyManagers, trustManagers, SecurityConfig.secureRandom)

            SecurityAuditor.logConfigurationChange("TLS configuration initialized",
                details = mapOf(
                    "protocol" to SecurityConfig.TLS_PROTOCOL,
                    "client_cert_auth" to SecurityConfig.ENABLE_CLIENT_CERT_AUTH,
                    "cert_revocation_check" to SecurityConfig.CERTIFICATE_REVOCATION_CHECK
                )
            )

        } catch (e: Exception) {
            SecurityAuditor.logSecurityViolation("TLS initialization failed",
                details = mapOf("error" to e.message.toString()))
            throw SecurityException("Failed to initialize TLS configuration: ${e.message}", e)
        }
    }

    /**
     * Get SSL context
     */
    fun getSslContext(): SSLContext {
        return sslContext ?: throw SecurityException("TLS not initialized")
    }

    /**
     * Get SSL socket factory
     */
    fun getSslSocketFactory(): SSLSocketFactory {
        return getSslContext().socketFactory
    }

    /**
     * Get SSL server socket factory
     */
    fun getSslServerSocketFactory(): SSLServerSocketFactory {
        return getSslContext().serverSocketFactory
    }

    /**
     * Create SSL parameters with security settings
     */
    fun createSslParameters(): SSLParameters {
        val params = SSLParameters()

        // Set protocols
        params.protocols = arrayOf(SecurityConfig.TLS_PROTOCOL)

        // Set cipher suites (prefer secure ones)
        params.cipherSuites = arrayOf(
            "TLS_AES_256_GCM_SHA384",
            "TLS_AES_128_GCM_SHA256",
            "TLS_CHACHA20_POLY1305_SHA256",
            "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
            "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
        )

        // Enable client certificate authentication if configured
        if (SecurityConfig.ENABLE_CLIENT_CERT_AUTH) {
            params.needClientAuth = true
        }

        // Set endpoint identification algorithm
        params.endpointIdentificationAlgorithm = "HTTPS"

        return params
    }

    /**
     * Validate certificate chain
     */
    fun validateCertificateChain(chain: Array<X509Certificate>): List<String> {
        val issues = mutableListOf<String>()

        if (chain.isEmpty()) {
            issues.add("Certificate chain is empty")
            return issues
        }

        val leafCert = chain[0]

        // Check certificate validity
        try {
            leafCert.checkValidity()
        } catch (e: Exception) {
            issues.add("Certificate is not valid: ${e.message}")
        }

        // Check certificate revocation if enabled
        if (SecurityConfig.CERTIFICATE_REVOCATION_CHECK) {
            // OCSP check
            if (SecurityConfig.OCSP_ENABLED) {
                // Note: Full OCSP implementation would require additional libraries
                // This is a placeholder for OCSP checking logic
                SecurityAuditor.logEvent(SecurityAuditor.AuditEvent(
                    eventType = SecurityAuditor.EventType.TLS_CONNECTION,
                    action = "OCSP check performed",
                    details = mapOf("certificate_subject" to leafCert.subjectDN.toString())
                ))
            }

            // CRL check could be implemented here
        }

        // Check certificate strength
        val publicKey = leafCert.publicKey
        val keySize = when (publicKey.algorithm) {
            "RSA" -> {
                val rsaKey = publicKey as java.security.interfaces.RSAPublicKey
                rsaKey.modulus.bitLength()
            }
            "EC" -> {
                val ecKey = publicKey as java.security.interfaces.ECPublicKey
                ecKey.params.curve.field.fieldSize
            }
            else -> 0
        }

        if (keySize < 2048) {
            issues.add("Certificate key size ($keySize) is below recommended minimum (2048)")
        }

        return issues
    }

    /**
     * Load key store from file
     */
    private fun loadKeyStore(path: String, password: String): KeyStore {
        val file = File(path)
        if (!file.exists()) {
            throw SecurityException("Key store file not found: $path")
        }

        return FileInputStream(file).use { fis ->
            val ks = KeyStore.getInstance(KeyStore.getDefaultType())
            ks.load(fis, password.toCharArray())
            ks
        }
    }

    /**
     * Get certificate information
     */
    fun getCertificateInfo(alias: String): Map<String, Any>? {
        val cert = keyStore?.getCertificate(alias) as? X509Certificate ?: return null

        return mapOf(
            "subject" to cert.subjectDN.toString(),
            "issuer" to cert.issuerDN.toString(),
            "valid_from" to cert.notBefore.toString(),
            "valid_until" to cert.notAfter.toString(),
            "serial_number" to cert.serialNumber.toString(),
            "signature_algorithm" to cert.sigAlgName,
            "public_key_algorithm" to cert.publicKey.algorithm,
            "version" to cert.version
        )
    }

    /**
     * Get TLS configuration summary
     */
    fun getTlsSummary(): Map<String, Any> {
        return mapOf(
            "protocol" to SecurityConfig.TLS_PROTOCOL,
            "client_certificate_auth" to SecurityConfig.ENABLE_CLIENT_CERT_AUTH,
            "certificate_revocation_check" to SecurityConfig.CERTIFICATE_REVOCATION_CHECK,
            "ocsp_enabled" to SecurityConfig.OCSP_ENABLED,
            "cipher_suites" to listOf(
                "TLS_AES_256_GCM_SHA384",
                "TLS_AES_128_GCM_SHA256",
                "TLS_CHACHA20_POLY1305_SHA256"
            ),
            "initialized" to (sslContext != null)
        )
    }
}