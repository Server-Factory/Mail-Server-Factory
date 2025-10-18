package net.milosvasic.factory.mail.configuration

import com.typesafe.config.Config
import com.typesafe.config.ConfigFactory
import net.milosvasic.factory.mail.BuildInfo
import net.milosvasic.factory.mail.logging.EnterpriseLogger
import java.io.File
import java.nio.file.*
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.io.path.exists

/**
 * Enterprise configuration management with environment support and hot-reloading
 */
object ConfigurationManager {

    private val configurations = ConcurrentHashMap<String, Config>()
    private val configWatchers = ConcurrentHashMap<String, WatchService>()
    private val configListeners = ConcurrentHashMap<String, MutableList<ConfigurationListener>>()
    private val executor = Executors.newCachedThreadPool()

    // Configuration environments
    enum class Environment {
        DEVELOPMENT, STAGING, PRODUCTION, TEST
    }

    // Configuration listener interface
    fun interface ConfigurationListener {
        fun onConfigurationChanged(newConfig: Config, oldConfig: Config?)
    }

    // Current environment
    private var currentEnvironment = Environment.DEVELOPMENT

    init {
        // Load default configurations
        loadDefaultConfigurations()
    }

    /**
     * Set the current environment
     */
    fun setEnvironment(environment: Environment) {
        currentEnvironment = environment
        EnterpriseLogger.info("Configuration environment set to: $environment")
        reloadAllConfigurations()
    }

    /**
     * Get current environment
     */
    fun getEnvironment(): Environment = currentEnvironment

    /**
     * Load configuration from file with environment support
     */
    fun loadConfiguration(namespace: String, basePath: String = "config"): Config {
        val config = loadConfigWithEnvironment(namespace, basePath)
        configurations[namespace] = config

        // Setup file watching for hot-reloading
        setupConfigWatching(namespace, basePath)

        EnterpriseLogger.info("Loaded configuration: $namespace", mapOf(
            "environment" to currentEnvironment.toString(),
            "base_path" to basePath
        ))

        return config
    }

    /**
     * Get configuration by namespace
     */
    fun getConfiguration(namespace: String): Config? {
        return configurations[namespace]
    }

    /**
     * Get configuration value with type safety
     */
    inline fun <reified T> getConfigValue(namespace: String, path: String, default: T? = null): T? {
        val config = getConfiguration(namespace) ?: return default

        return try {
            when (T::class) {
                String::class -> config.getString(path) as T
                Int::class -> config.getInt(path) as T
                Long::class -> config.getLong(path) as T
                Double::class -> config.getDouble(path) as T
                Boolean::class -> config.getBoolean(path) as T
                List::class -> config.getStringList(path) as T
                else -> {
                    EnterpriseLogger.warn("Unsupported config type: ${T::class}")
                    default
                }
            }
        } catch (e: Exception) {
            EnterpriseLogger.warn("Failed to get config value: $namespace.$path", exception = e)
            default
        }
    }

    /**
     * Update configuration value
     */
    fun setConfigValue(namespace: String, path: String, value: Any) {
        // Note: This is a simplified implementation. In production, you'd want to persist changes.
        EnterpriseLogger.info("Configuration update requested: $namespace.$path = $value")
        // Trigger listeners
        notifyConfigListeners(namespace, getConfiguration(namespace), getConfiguration(namespace))
    }

    /**
     * Register configuration listener
     */
    fun addConfigListener(namespace: String, listener: ConfigurationListener) {
        configListeners.computeIfAbsent(namespace) { mutableListOf() }.add(listener)
    }

    /**
     * Unregister configuration listener
     */
    fun removeConfigListener(namespace: String, listener: ConfigurationListener) {
        configListeners[namespace]?.remove(listener)
    }

    /**
     * Validate configuration
     */
    fun validateConfiguration(namespace: String): List<String> {
        val config = getConfiguration(namespace) ?: return listOf("Configuration not found: $namespace")
        return validateConfig(namespace, config)
    }

    /**
     * Get all configuration namespaces
     */
    fun getConfigurationNamespaces(): Set<String> {
        return configurations.keys
    }

    /**
     * Get configuration summary
     */
    fun getConfigurationSummary(): Map<String, Any> {
        return mapOf(
            "environment" to currentEnvironment.toString(),
            "namespaces" to getConfigurationNamespaces().size,
            "configurations" to configurations.map { (namespace, config) ->
                mapOf(
                    "namespace" to namespace,
                    "keys" to getConfigKeys(config),
                    "last_modified" to getConfigLastModified(namespace)
                )
            },
            "listeners" to configListeners.map { (namespace, listeners) ->
                namespace to listeners.size
            }
        )
    }

    /**
     * Reload configuration
     */
    fun reloadConfiguration(namespace: String, basePath: String = "config") {
        val oldConfig = getConfiguration(namespace)
        val newConfig = loadConfigWithEnvironment(namespace, basePath)
        configurations[namespace] = newConfig

        notifyConfigListeners(namespace, newConfig, oldConfig)

        EnterpriseLogger.info("Reloaded configuration: $namespace")
    }

    /**
     * Reload all configurations
     */
    fun reloadAllConfigurations() {
        configurations.keys.forEach { namespace ->
            reloadConfiguration(namespace)
        }
    }

    /**
     * Shutdown configuration manager
     */
    fun shutdown() {
        configWatchers.values.forEach { it.close() }
        configWatchers.clear()
        executor.shutdown()

        try {
            executor.awaitTermination(5, TimeUnit.SECONDS)
        } catch (e: InterruptedException) {
            executor.shutdownNow()
            Thread.currentThread().interrupt()
        }
    }

    /**
     * Load configuration with environment fallback
     */
    private fun loadConfigWithEnvironment(namespace: String, basePath: String): Config {
        val configDir = File(basePath)

        // Try environment-specific config first
        val envConfigFile = File(configDir, "$namespace-${currentEnvironment.toString().lowercase()}.conf")
        val defaultConfigFile = File(configDir, "$namespace.conf")

        val configs = mutableListOf<Config>()

        // Load default config first (if exists)
        if (defaultConfigFile.exists()) {
            configs.add(ConfigFactory.parseFile(defaultConfigFile))
        }

        // Load environment-specific config (if exists)
        if (envConfigFile.exists()) {
            configs.add(ConfigFactory.parseFile(envConfigFile))
        }

        // Add system properties and environment variables
        configs.add(ConfigFactory.systemProperties())
        configs.add(ConfigFactory.systemEnvironment())

        // Merge all configs (later configs override earlier ones)
        return configs.reduce { acc, config -> config.withFallback(acc) }
            .resolve()
    }

    /**
     * Setup file watching for hot-reloading
     */
    private fun setupConfigWatching(namespace: String, basePath: String) {
        try {
            val configDir = Paths.get(basePath)
            if (!configDir.exists()) return

            val watchService = FileSystems.getDefault().newWatchService()
            configDir.register(watchService,
                StandardWatchEventKinds.ENTRY_MODIFY,
                StandardWatchEventKinds.ENTRY_CREATE,
                StandardWatchEventKinds.ENTRY_DELETE)

            configWatchers[namespace] = watchService

            // Start watching in background
            executor.submit {
                watchConfigFiles(namespace, watchService, configDir)
            }
        } catch (e: Exception) {
            EnterpriseLogger.warn("Failed to setup config watching for $namespace", exception = e)
        }
    }

    /**
     * Watch configuration files for changes
     */
    private fun watchConfigFiles(namespace: String, watchService: WatchService, configDir: Path) {
        try {
            while (true) {
                val key = watchService.take()
                var configChanged = false

                for (event in key.pollEvents()) {
                    val changed = event.context() as Path
                    if (changed.toString().startsWith("$namespace")) {
                        configChanged = true
                        EnterpriseLogger.debug("Config file changed: $changed")
                    }
                }

                if (configChanged) {
                    // Debounce rapid changes
                    Thread.sleep(500)
                    reloadConfiguration(namespace, configDir.toString())
                }

                key.reset()
            }
        } catch (e: ClosedWatchServiceException) {
            // Watch service was closed
        } catch (e: Exception) {
            EnterpriseLogger.error("Error watching config files for $namespace", exception = e)
        }
    }

    /**
     * Notify configuration listeners
     */
    private fun notifyConfigListeners(namespace: String, newConfig: Config?, oldConfig: Config?) {
        configListeners[namespace]?.forEach { listener ->
            try {
                listener.onConfigurationChanged(newConfig ?: ConfigFactory.empty(), oldConfig)
            } catch (e: Exception) {
                EnterpriseLogger.error("Error notifying config listener", exception = e)
            }
        }
    }

    /**
     * Load default configurations
     */
    private fun loadDefaultConfigurations() {
        // Load core configurations
        loadConfiguration("application")
        loadConfiguration("security")
        loadConfiguration("database")
        loadConfiguration("monitoring")
        loadConfiguration("performance")
    }

    /**
     * Validate configuration content
     */
    private fun validateConfig(namespace: String, config: Config): List<String> {
        val issues = mutableListOf<String>()

        when (namespace) {
            "security" -> {
                // Validate security configuration
                if (config.hasPath("password.minLength") &&
                    config.getInt("password.minLength") < 8) {
                    issues.add("Password minimum length should be at least 8")
                }
            }
            "database" -> {
                // Validate database configuration
                if (config.hasPath("pool.maxSize") &&
                    config.getInt("pool.maxSize") > 100) {
                    issues.add("Database pool max size should not exceed 100")
                }
            }
            "performance" -> {
                // Validate performance configuration
                if (config.hasPath("threadPool.maxSize") &&
                    config.getInt("threadPool.maxSize") < 1) {
                    issues.add("Thread pool max size should be at least 1")
                }
            }
        }

        return issues
    }

    /**
     * Get configuration keys
     */
    private fun getConfigKeys(config: Config): List<String> {
        return config.entrySet().map { it.key }
    }

    /**
     * Get configuration last modified time
     */
    private fun getConfigLastModified(namespace: String): Instant? {
        // This would track actual file modification times in a real implementation
        return Instant.now()
    }
}