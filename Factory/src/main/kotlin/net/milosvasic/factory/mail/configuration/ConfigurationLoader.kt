package net.milosvasic.factory.mail.configuration

import net.milosvasic.factory.mail.logging.EnterpriseLogger
import java.io.File

/**
 * Configuration loader utility for bootstrapping application configuration
 */
object ConfigurationLoader {

    /**
     * Load all application configurations
     */
    fun loadAllConfigurations() {
        try {
            // Ensure config directory exists
            val configDir = File("config")
            if (!configDir.exists()) {
                configDir.mkdirs()
                createDefaultConfigurations()
            }

            // Load core configurations
            ConfigurationManager.loadConfiguration("application")
            ConfigurationManager.loadConfiguration("security")
            ConfigurationManager.loadConfiguration("database")
            ConfigurationManager.loadConfiguration("monitoring")
            ConfigurationManager.loadConfiguration("performance")

            // Validate all configurations
            validateAllConfigurations()

            EnterpriseLogger.info("All configurations loaded successfully")

        } catch (e: Exception) {
            EnterpriseLogger.error("Failed to load configurations", exception = e)
            throw ConfigurationException("Configuration loading failed", e)
        }
    }

    /**
     * Validate all loaded configurations
     */
    fun validateAllConfigurations(): ValidationResult {
        val results = mutableMapOf<String, List<String>>()
        var hasErrors = false

        ConfigurationManager.getConfigurationNamespaces().forEach { namespace ->
            val issues = ConfigurationManager.validateConfiguration(namespace)
            results[namespace] = issues
            if (issues.isNotEmpty()) {
                hasErrors = true
                issues.forEach { issue ->
                    EnterpriseLogger.warn("Configuration validation issue in $namespace: $issue")
                }
            }
        }

        return ValidationResult(!hasErrors, results)
    }

    /**
     * Get configuration status
     */
    fun getConfigurationStatus(): Map<String, Any> {
        val namespaces = ConfigurationManager.getConfigurationNamespaces()
        val validation = validateAllConfigurations()

        return mapOf(
            "loaded_namespaces" to namespaces.size,
            "namespaces" to namespaces,
            "validation_passed" to validation.isValid,
            "validation_issues" to validation.issues,
            "environment" to ConfigurationManager.getEnvironment().toString(),
            "summary" to ConfigurationManager.getConfigurationSummary()
        )
    }

    /**
     * Create default configuration files if they don't exist
     */
    private fun createDefaultConfigurations() {
        createDefaultApplicationConfig()
        createDefaultSecurityConfig()
        createDefaultDatabaseConfig()
        createDefaultMonitoringConfig()
        createDefaultPerformanceConfig()

        EnterpriseLogger.info("Created default configuration files")
    }

    /**
     * Create default application configuration
     */
    private fun createDefaultApplicationConfig() {
        val config = """
            application {
              name = "Mail Server Factory"
              version = "1.0.0"
              description = "Enterprise-grade mail server configuration tool"

              server {
                host = "localhost"
                port = 8080
                ssl {
                  enabled = false
                  port = 8443
                }
              }

              logging {
                level = "INFO"
                file {
                  enabled = true
                  path = "logs/application.log"
                  maxSize = "10MB"
                  maxFiles = 5
                }
              }
            }

            database {
              driver = "postgresql"
              host = "localhost"
              port = 5432
              name = "mail_factory"
              username = "mail_user"
              password = "change_me"

              pool {
                minSize = 5
                maxSize = 20
                connectionTimeout = 30000
              }
            }
        """.trimIndent()

        File("config/application.conf").writeText(config)
    }

    /**
     * Create default security configuration
     */
    private fun createDefaultSecurityConfig() {
        val config = """
            security {
              password {
                minLength = 12
                maxLength = 128
                requireUppercase = true
                requireLowercase = true
                requireDigits = true
                requireSpecialChars = true
              }

              session {
                timeout = 1800
                maxConcurrentSessions = 3
              }

              tls {
                enforced = true
                protocols = ["TLSv1.3", "TLSv1.2"]
              }

              audit {
                enabled = true
                retentionDays = 90
              }
            }
        """.trimIndent()

        File("config/security.conf").writeText(config)
    }

    /**
     * Create default database configuration
     */
    private fun createDefaultDatabaseConfig() {
        val config = """
            database {
              driver = "postgresql"
              host = "localhost"
              port = 5432
              name = "mail_factory"
              username = "mail_user"
              password = "change_me"

              pool {
                minSize = 5
                maxSize = 20
                connectionTimeout = 30000
                idleTimeout = 600000
                maxLifetime = 1800000
              }

              migrations {
                enabled = true
                path = "db/migrations"
              }
            }
        """.trimIndent()

        File("config/database.conf").writeText(config)
    }

    /**
     * Create default monitoring configuration
     */
    private fun createDefaultMonitoringConfig() {
        val config = """
            monitoring {
              enabled = true

              metrics {
                enabled = true
                exporter = "prometheus"
                port = 9090
                path = "/metrics"
              }

              logging {
                level = "INFO"
                structured = true
                file {
                  enabled = true
                  path = "logs/monitoring.log"
                }
              }

              health {
                enabled = true
                checks {
                  system = true
                  database = true
                  security = true
                  performance = true
                }
              }
            }
        """.trimIndent()

        File("config/monitoring.conf").writeText(config)
    }

    /**
     * Create default performance configuration
     */
    private fun createDefaultPerformanceConfig() {
        val config = """
            performance {
              caching {
                enabled = true
                maxSize = 10000
                expireAfterWrite = 1800
                expireAfterAccess = 600
              }

              threading {
                defaultPoolSize = 10
                maxPoolSize = 50
                keepAliveTime = 300
              }

              memory {
                heapSize = 2048
                metaspaceSize = 512
                gcTuning = true
              }

              io {
                async = true
                threadPoolSize = 20
                bufferSize = 65536
              }
            }
        """.trimIndent()

        File("config/performance.conf").writeText(config)
    }

    /**
     * Validation result data class
     */
    data class ValidationResult(
        val isValid: Boolean,
        val issues: Map<String, List<String>>
    )

    /**
     * Configuration exception
     */
    class ConfigurationException(message: String, cause: Throwable? = null) : Exception(message, cause)
}