package net.milosvasic.factory.mail.performance

import java.util.concurrent.*

/**
 * Enterprise performance configuration and optimization settings
 */
object PerformanceConfig {

    // Thread pool configurations
    const val DEFAULT_THREAD_POOL_SIZE = 10
    const val MAX_THREAD_POOL_SIZE = 50
    const val THREAD_KEEP_ALIVE_TIME_MINUTES = 5
    const val QUEUE_CAPACITY = 1000

    // Database connection pool
    const val DB_MAX_POOL_SIZE = 20
    const val DB_MIN_IDLE_CONNECTIONS = 5
    const val DB_CONNECTION_TIMEOUT_MS = 30000L
    const val DB_IDLE_TIMEOUT_MS = 600000L // 10 minutes
    const val DB_MAX_LIFETIME_MS = 1800000L // 30 minutes

    // Caching configurations
    const val ENABLE_CACHING = true
    const val CACHE_MAX_SIZE = 10000
    const val CACHE_EXPIRE_AFTER_WRITE_MINUTES = 30
    const val CACHE_EXPIRE_AFTER_ACCESS_MINUTES = 10

    // Memory management
    const val JVM_HEAP_SIZE_MB = 2048
    const val JVM_METASPACE_SIZE_MB = 512
    const val ENABLE_GC_TUNING = true

    // I/O optimizations
    const val ENABLE_ASYNC_IO = true
    const val IO_THREAD_POOL_SIZE = 20
    const val BUFFER_SIZE_KB = 64

    // Network optimizations
    const val HTTP_CONNECTION_TIMEOUT_MS = 10000
    const val HTTP_READ_TIMEOUT_MS = 30000
    const val HTTP_MAX_CONNECTIONS_PER_ROUTE = 20
    const val HTTP_MAX_TOTAL_CONNECTIONS = 200

    // Monitoring and metrics
    const val ENABLE_METRICS = true
    const val METRICS_REPORT_INTERVAL_SECONDS = 60
    const val ENABLE_JMX = true

    // Circuit breaker
    const val CIRCUIT_BREAKER_FAILURE_THRESHOLD = 5
    const val CIRCUIT_BREAKER_TIMEOUT_SECONDS = 60
    const val CIRCUIT_BREAKER_SUCCESS_THRESHOLD = 3

    // Rate limiting (per second)
    const val GLOBAL_RATE_LIMIT_PER_SECOND = 1000
    const val API_RATE_LIMIT_PER_SECOND = 100

    // Compression
    const val ENABLE_COMPRESSION = true
    const val COMPRESSION_LEVEL = 6 // 1-9, 6 is good balance

    // Connection pooling
    private val threadPoolExecutor = ThreadPoolExecutor(
        DEFAULT_THREAD_POOL_SIZE,
        MAX_THREAD_POOL_SIZE,
        THREAD_KEEP_ALIVE_TIME_MINUTES.toLong(),
        TimeUnit.MINUTES,
        LinkedBlockingQueue(QUEUE_CAPACITY),
        ThreadPoolExecutor.CallerRunsPolicy()
    )

    private val ioExecutor = Executors.newFixedThreadPool(IO_THREAD_POOL_SIZE)

    /**
     * Get the main thread pool executor
     */
    fun getThreadPoolExecutor(): ThreadPoolExecutor {
        return threadPoolExecutor
    }

    /**
     * Get the I/O thread pool executor
     */
    fun getIoExecutor(): ExecutorService {
        return ioExecutor
    }

    /**
     * Create a cached thread pool for short-lived tasks
     */
    fun createCachedThreadPool(): ExecutorService {
        return Executors.newCachedThreadPool()
    }

    /**
     * Create a scheduled thread pool for periodic tasks
     */
    fun createScheduledThreadPool(corePoolSize: Int = 4): ScheduledExecutorService {
        return Executors.newScheduledThreadPool(corePoolSize)
    }

    /**
     * Get JVM performance arguments
     */
    fun getJvmArgs(): List<String> {
        return if (ENABLE_GC_TUNING) {
            listOf(
                "-Xmx${JVM_HEAP_SIZE_MB}m",
                "-XX:MaxMetaspaceSize=${JVM_METASPACE_SIZE_MB}m",
                "-XX:+UseG1GC",
                "-XX:MaxGCPauseMillis=200",
                "-XX:G1HeapRegionSize=16m",
                "-XX:+UseStringDeduplication",
                "-XX:+OptimizeStringConcat",
                "-Djava.security.egd=file:/dev/./urandom" // Faster random number generation
            )
        } else {
            listOf(
                "-Xmx${JVM_HEAP_SIZE_MB}m",
                "-XX:MaxMetaspaceSize=${JVM_METASPACE_SIZE_MB}m"
            )
        }
    }

    /**
     * Get performance configuration summary
     */
    fun getPerformanceSummary(): Map<String, Any> {
        return mapOf(
            "threading" to mapOf(
                "default_pool_size" to DEFAULT_THREAD_POOL_SIZE,
                "max_pool_size" to MAX_THREAD_POOL_SIZE,
                "keep_alive_minutes" to THREAD_KEEP_ALIVE_TIME_MINUTES,
                "queue_capacity" to QUEUE_CAPACITY,
                "io_threads" to IO_THREAD_POOL_SIZE
            ),
            "database" to mapOf(
                "max_pool_size" to DB_MAX_POOL_SIZE,
                "min_idle" to DB_MIN_IDLE_CONNECTIONS,
                "connection_timeout_ms" to DB_CONNECTION_TIMEOUT_MS,
                "idle_timeout_ms" to DB_IDLE_TIMEOUT_MS,
                "max_lifetime_ms" to DB_MAX_LIFETIME_MS
            ),
            "caching" to mapOf(
                "enabled" to ENABLE_CACHING,
                "max_size" to CACHE_MAX_SIZE,
                "expire_write_minutes" to CACHE_EXPIRE_AFTER_WRITE_MINUTES,
                "expire_access_minutes" to CACHE_EXPIRE_AFTER_ACCESS_MINUTES
            ),
            "memory" to mapOf(
                "heap_size_mb" to JVM_HEAP_SIZE_MB,
                "metaspace_size_mb" to JVM_METASPACE_SIZE_MB,
                "gc_tuning" to ENABLE_GC_TUNING
            ),
            "network" to mapOf(
                "connection_timeout_ms" to HTTP_CONNECTION_TIMEOUT_MS,
                "read_timeout_ms" to HTTP_READ_TIMEOUT_MS,
                "max_per_route" to HTTP_MAX_CONNECTIONS_PER_ROUTE,
                "max_total" to HTTP_MAX_TOTAL_CONNECTIONS
            ),
            "monitoring" to mapOf(
                "metrics_enabled" to ENABLE_METRICS,
                "metrics_interval_seconds" to METRICS_REPORT_INTERVAL_SECONDS,
                "jmx_enabled" to ENABLE_JMX
            ),
            "circuit_breaker" to mapOf(
                "failure_threshold" to CIRCUIT_BREAKER_FAILURE_THRESHOLD,
                "timeout_seconds" to CIRCUIT_BREAKER_TIMEOUT_SECONDS,
                "success_threshold" to CIRCUIT_BREAKER_SUCCESS_THRESHOLD
            ),
            "rate_limiting" to mapOf(
                "global_per_second" to GLOBAL_RATE_LIMIT_PER_SECOND,
                "api_per_second" to API_RATE_LIMIT_PER_SECOND
            ),
            "compression" to mapOf(
                "enabled" to ENABLE_COMPRESSION,
                "level" to COMPRESSION_LEVEL
            )
        )
    }

    /**
     * Validate performance configuration
     */
    fun validateConfiguration(): List<String> {
        val issues = mutableListOf<String>()

        if (MAX_THREAD_POOL_SIZE < DEFAULT_THREAD_POOL_SIZE) {
            issues.add("Max thread pool size cannot be less than default pool size")
        }

        if (DB_MAX_POOL_SIZE < DB_MIN_IDLE_CONNECTIONS) {
            issues.add("Database max pool size cannot be less than minimum idle connections")
        }

        if (JVM_HEAP_SIZE_MB < 512) {
            issues.add("JVM heap size should be at least 512MB for enterprise applications")
        }

        if (COMPRESSION_LEVEL !in 1..9) {
            issues.add("Compression level must be between 1 and 9")
        }

        return issues
    }

    /**
     * Shutdown all thread pools
     */
    fun shutdown() {
        threadPoolExecutor.shutdown()
        ioExecutor.shutdown()

        try {
            if (!threadPoolExecutor.awaitTermination(5, TimeUnit.SECONDS)) {
                threadPoolExecutor.shutdownNow()
            }
            if (!ioExecutor.awaitTermination(5, TimeUnit.SECONDS)) {
                ioExecutor.shutdownNow()
            }
        } catch (e: InterruptedException) {
            threadPoolExecutor.shutdownNow()
            ioExecutor.shutdownNow()
            Thread.currentThread().interrupt()
        }
    }
}