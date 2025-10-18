package net.milosvasic.factory.mail.performance

import net.milosvasic.factory.mail.BuildInfo
import java.lang.management.ManagementFactory
import java.lang.management.MemoryMXBean
import java.lang.management.ThreadMXBean
import java.time.Instant
import java.util.concurrent.atomic.AtomicLong

/**
 * Enterprise performance monitoring and metrics collection
 */
object PerformanceMonitor {

    private val memoryMXBean: MemoryMXBean = ManagementFactory.getMemoryMXBean()
    private val threadMXBean: ThreadMXBean = ManagementFactory.getThreadMXBean()
    private val runtimeMXBean = ManagementFactory.getRuntimeMXBean()
    private val osMXBean = ManagementFactory.getOperatingSystemMXBean()

    // Metrics counters
    private val requestCount = AtomicLong(0)
    private val errorCount = AtomicLong(0)
    private val responseTimeSum = AtomicLong(0)
    private val activeConnections = AtomicLong(0)

    // Performance thresholds
    const val HIGH_CPU_THRESHOLD = 80.0
    const val HIGH_MEMORY_THRESHOLD = 85.0
    const val HIGH_THREAD_THRESHOLD = 100
    const val SLOW_RESPONSE_THRESHOLD_MS = 1000L

    /**
     * Record a request
     */
    fun recordRequest(responseTimeMs: Long) {
        requestCount.incrementAndGet()
        responseTimeSum.addAndGet(responseTimeMs)

        if (responseTimeMs > SLOW_RESPONSE_THRESHOLD_MS) {
            // Log slow requests
            println("SLOW REQUEST: ${responseTimeMs}ms")
        }
    }

    /**
     * Record an error
     */
    fun recordError() {
        errorCount.incrementAndGet()
    }

    /**
     * Record active connection
     */
    fun recordConnectionChange(delta: Int) {
        activeConnections.addAndGet(delta.toLong())
    }

    /**
     * Get current memory usage
     */
    fun getMemoryUsage(): Map<String, Any> {
        val heapUsage = memoryMXBean.heapMemoryUsage
        val nonHeapUsage = memoryMXBean.nonHeapMemoryUsage

        return mapOf(
            "heap_used_mb" to heapUsage.used / 1024 / 1024,
            "heap_committed_mb" to heapUsage.committed / 1024 / 1024,
            "heap_max_mb" to heapUsage.max / 1024 / 1024,
            "heap_usage_percent" to if (heapUsage.max > 0) {
                (heapUsage.used.toDouble() / heapUsage.max.toDouble() * 100).toInt()
            } else 0,
            "non_heap_used_mb" to nonHeapUsage.used / 1024 / 1024,
            "non_heap_committed_mb" to nonHeapUsage.committed / 1024 / 1024
        )
    }

    /**
     * Get thread information
     */
    fun getThreadInfo(): Map<String, Any> {
        return mapOf(
            "thread_count" to threadMXBean.threadCount,
            "daemon_thread_count" to threadMXBean.daemonThreadCount,
            "peak_thread_count" to threadMXBean.peakThreadCount,
            "total_started_thread_count" to threadMXBean.totalStartedThreadCount
        )
    }

    /**
     * Get system information
     */
    fun getSystemInfo(): Map<String, Any> {
        return mapOf(
            "os_name" to System.getProperty("os.name"),
            "os_version" to System.getProperty("os.version"),
            "os_arch" to System.getProperty("os.arch"),
            "java_version" to System.getProperty("java.version"),
            "java_vendor" to System.getProperty("java.vendor"),
            "jvm_name" to runtimeMXBean.vmName,
            "jvm_version" to runtimeMXBean.vmVersion,
            "processors" to Runtime.getRuntime().availableProcessors(),
            "uptime_seconds" to runtimeMXBean.uptime / 1000,
            "start_time" to Instant.ofEpochMilli(runtimeMXBean.startTime)
        )
    }

    /**
     * Get CPU usage (approximate)
     */
    fun getCpuUsage(): Map<String, Any> {
        val osBean = osMXBean as com.sun.management.OperatingSystemMXBean
        return mapOf(
            "process_cpu_load" to (osBean.processCpuLoad * 100).toInt(),
            "system_cpu_load" to (osBean.systemCpuLoad * 100).toInt(),
            "system_load_average" to osBean.systemLoadAverage
        )
    }

    /**
     * Get application metrics
     */
    fun getApplicationMetrics(): Map<String, Any> {
        val totalRequests = requestCount.get()
        val totalErrors = errorCount.get()
        val totalResponseTime = responseTimeSum.get()

        return mapOf(
            "total_requests" to totalRequests,
            "total_errors" to totalErrors,
            "active_connections" to activeConnections.get(),
            "error_rate_percent" to if (totalRequests > 0) {
                (totalErrors.toDouble() / totalRequests.toDouble() * 100).toInt()
            } else 0,
            "average_response_time_ms" to if (totalRequests > 0) {
                totalResponseTime / totalRequests
            } else 0,
            "requests_per_second" to getRequestsPerSecond()
        )
    }

    /**
     * Get performance health status
     */
    fun getHealthStatus(): Map<String, Any> {
        val memory = getMemoryUsage()
        val threads = getThreadInfo()
        val cpu = getCpuUsage()
        val metrics = getApplicationMetrics()

        val issues = mutableListOf<String>()

        // Check memory usage
        val heapUsagePercent = memory["heap_usage_percent"] as Int
        if (heapUsagePercent > HIGH_MEMORY_THRESHOLD) {
            issues.add("High memory usage: ${heapUsagePercent}%")
        }

        // Check thread count
        val threadCount = threads["thread_count"] as Int
        if (threadCount > HIGH_THREAD_THRESHOLD) {
            issues.add("High thread count: $threadCount")
        }

        // Check CPU usage
        val cpuLoad = cpu["process_cpu_load"] as Int
        if (cpuLoad > HIGH_CPU_THRESHOLD) {
            issues.add("High CPU usage: ${cpuLoad}%")
        }

        // Check error rate
        val errorRate = metrics["error_rate_percent"] as Int
        if (errorRate > 5) { // More than 5% errors
            issues.add("High error rate: ${errorRate}%")
        }

        return mapOf(
            "status" to if (issues.isEmpty()) "HEALTHY" else "WARNING",
            "issues" to issues,
            "timestamp" to Instant.now(),
            "version" to BuildInfo.version
        )
    }

    /**
     * Get comprehensive performance report
     */
    fun getPerformanceReport(): Map<String, Any> {
        return mapOf(
            "timestamp" to Instant.now(),
            "version" to BuildInfo.version,
            "memory" to getMemoryUsage(),
            "threads" to getThreadInfo(),
            "system" to getSystemInfo(),
            "cpu" to getCpuUsage(),
            "application" to getApplicationMetrics(),
            "cache" to CacheManager.getTotalCacheStats(),
            "health" to getHealthStatus()
        )
    }

    /**
     * Reset metrics counters
     */
    fun resetMetrics() {
        requestCount.set(0)
        errorCount.set(0)
        responseTimeSum.set(0)
        activeConnections.set(0)
    }

    /**
     * Calculate requests per second (approximate)
     */
    private fun getRequestsPerSecond(): Double {
        val uptimeSeconds = runtimeMXBean.uptime / 1000.0
        val totalRequests = requestCount.get()
        return if (uptimeSeconds > 0) totalRequests / uptimeSeconds else 0.0
    }
}