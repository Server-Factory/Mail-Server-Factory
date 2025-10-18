package net.milosvasic.factory.mail.monitoring

import net.milosvasic.factory.mail.BuildInfo
import net.milosvasic.factory.mail.performance.PerformanceMonitor
import net.milosvasic.factory.mail.security.SecurityAuditor
import java.time.Instant
import java.util.concurrent.*

/**
 * Enterprise monitoring service for comprehensive system observability
 */
object MonitoringService {

    private val scheduler = Executors.newScheduledThreadPool(2)
    private val monitoringTasks = ConcurrentHashMap<String, ScheduledFuture<*>>()
    private val healthChecks = ConcurrentHashMap<String, HealthCheck>()

    // Monitoring intervals
    const val PERFORMANCE_MONITORING_INTERVAL_SECONDS = 30
    const val HEALTH_CHECK_INTERVAL_SECONDS = 60
    const val LOG_ROTATION_INTERVAL_HOURS = 24

    /**
     * Health check interface
     */
    interface HealthCheck {
        fun check(): HealthStatus
        fun getName(): String
    }

    /**
     * Health status data class
     */
    data class HealthStatus(
        val status: Status,
        val message: String? = null,
        val details: Map<String, Any> = emptyMap(),
        val timestamp: Instant = Instant.now()
    ) {
        enum class Status {
            HEALTHY, WARNING, CRITICAL, UNKNOWN
        }
    }

    /**
     * Initialize monitoring service
     */
    fun initialize() {
        // Register default health checks
        registerHealthCheck(SystemHealthCheck())
        registerHealthCheck(SecurityHealthCheck())
        registerHealthCheck(PerformanceHealthCheck())

        // Start monitoring tasks
        startPerformanceMonitoring()
        startHealthCheckMonitoring()
        startLogRotation()
    }

    /**
     * Register a health check
     */
    fun registerHealthCheck(check: HealthCheck) {
        healthChecks[check.getName()] = check
    }

    /**
     * Unregister a health check
     */
    fun unregisterHealthCheck(name: String) {
        healthChecks.remove(name)
    }

    /**
     * Get health status for all checks
     */
    fun getHealthStatus(): Map<String, HealthStatus> {
        return healthChecks.mapValues { it.value.check() }
    }

    /**
     * Get overall system health
     */
    fun getOverallHealth(): HealthStatus.Status {
        val statuses = getHealthStatus().values.map { it.status }

        return when {
            statuses.any { it == HealthStatus.Status.CRITICAL } -> HealthStatus.Status.CRITICAL
            statuses.any { it == HealthStatus.Status.WARNING } -> HealthStatus.Status.WARNING
            statuses.all { it == HealthStatus.Status.HEALTHY } -> HealthStatus.Status.HEALTHY
            else -> HealthStatus.Status.UNKNOWN
        }
    }

    /**
     * Get comprehensive monitoring report
     */
    fun getMonitoringReport(): Map<String, Any> {
        return mapOf(
            "timestamp" to Instant.now(),
            "version" to BuildInfo.version,
            "overall_health" to getOverallHealth(),
            "health_checks" to getHealthStatus(),
            "performance" to PerformanceMonitor.getPerformanceReport(),
            "security_audit" to mapOf(
                "total_events" to SecurityAuditor.getAuditEvents(Instant.now().minusSeconds(3600)).size, // Last hour
                "recent_events" to SecurityAuditor.getAuditEvents(Instant.now().minusSeconds(300)) // Last 5 minutes
                    .take(10) // Last 10 events
                    .map { mapOf(
                        "type" to it.eventType,
                        "user" to it.userId,
                        "timestamp" to it.timestamp,
                        "success" to it.success
                    )}
            ),
            "system_info" to mapOf(
                "uptime_seconds" to PerformanceMonitor.getSystemInfo()["uptime_seconds"],
                "java_version" to System.getProperty("java.version"),
                "os" to "${System.getProperty("os.name")} ${System.getProperty("os.version")}"
            )
        )
    }

    /**
     * Start performance monitoring
     */
    private fun startPerformanceMonitoring() {
        val task = scheduler.scheduleAtFixedRate({
            try {
                val report = PerformanceMonitor.getPerformanceReport()
                // In production, this would send to monitoring system (Prometheus, DataDog, etc.)
                logMonitoringData("performance", report)
            } catch (e: Exception) {
                println("Performance monitoring error: ${e.message}")
            }
        }, 0, PERFORMANCE_MONITORING_INTERVAL_SECONDS.toLong(), TimeUnit.SECONDS)

        monitoringTasks["performance"] = task
    }

    /**
     * Start health check monitoring
     */
    private fun startHealthCheckMonitoring() {
        val task = scheduler.scheduleAtFixedRate({
            try {
                val healthStatus = getOverallHealth()
                if (healthStatus != HealthStatus.Status.HEALTHY) {
                    val report = getMonitoringReport()
                    logMonitoringData("health_check", mapOf(
                        "status" to healthStatus,
                        "report" to report
                    ))
                }
            } catch (e: Exception) {
                println("Health check monitoring error: ${e.message}")
            }
        }, 0, HEALTH_CHECK_INTERVAL_SECONDS.toLong(), TimeUnit.SECONDS)

        monitoringTasks["health_check"] = task
    }

    /**
     * Start log rotation
     */
    private fun startLogRotation() {
        val task = scheduler.scheduleAtFixedRate({
            try {
                SecurityAuditor.cleanupOldEvents()
                // Additional log rotation logic could be added here
                logMonitoringData("log_rotation", mapOf(
                    "timestamp" to Instant.now(),
                    "action" to "cleaned_old_audit_events"
                ))
            } catch (e: Exception) {
                println("Log rotation error: ${e.message}")
            }
        }, 1, LOG_ROTATION_INTERVAL_HOURS.toLong(), TimeUnit.HOURS)

        monitoringTasks["log_rotation"] = task
    }

    /**
     * Log monitoring data (placeholder for actual logging system)
     */
    private fun logMonitoringData(type: String, data: Map<String, Any>) {
        // In production, this would integrate with ELK stack, Splunk, etc.
        println("MONITORING [$type]: ${data.size} metrics collected")
    }

    /**
     * Shutdown monitoring service
     */
    fun shutdown() {
        monitoringTasks.values.forEach { it.cancel(true) }
        monitoringTasks.clear()
        scheduler.shutdown()

        try {
            if (!scheduler.awaitTermination(5, TimeUnit.SECONDS)) {
                scheduler.shutdownNow()
            }
        } catch (e: InterruptedException) {
            scheduler.shutdownNow()
            Thread.currentThread().interrupt()
        }
    }

    /**
     * System health check
     */
    private class SystemHealthCheck : HealthCheck {
        override fun getName() = "system"

        override fun check(): HealthStatus {
            return try {
                val systemInfo = PerformanceMonitor.getSystemInfo()
                val uptime = systemInfo["uptime_seconds"] as Long

                when {
                    uptime < 300 -> HealthStatus(HealthStatus.Status.WARNING, "System recently started")
                    else -> HealthStatus(HealthStatus.Status.HEALTHY, "System operating normally")
                }
            } catch (e: Exception) {
                HealthStatus(HealthStatus.Status.CRITICAL, "System health check failed: ${e.message}")
            }
        }
    }

    /**
     * Security health check
     */
    private class SecurityHealthCheck : HealthCheck {
        override fun getName() = "security"

        override fun check(): HealthStatus {
            return try {
                val recentEvents = SecurityAuditor.getAuditEvents(Instant.now().minusSeconds(3600)) // Last hour
                val failedAuthentications = recentEvents.count {
                    it.eventType == SecurityAuditor.EventType.AUTHENTICATION_FAILURE
                }

                when {
                    failedAuthentications > 10 -> HealthStatus(
                        HealthStatus.Status.CRITICAL,
                        "High number of authentication failures: $failedAuthentications"
                    )
                    failedAuthentications > 5 -> HealthStatus(
                        HealthStatus.Status.WARNING,
                        "Elevated authentication failures: $failedAuthentications"
                    )
                    else -> HealthStatus(HealthStatus.Status.HEALTHY, "Security status normal")
                }
            } catch (e: Exception) {
                HealthStatus(HealthStatus.Status.WARNING, "Security health check error: ${e.message}")
            }
        }
    }

    /**
     * Performance health check
     */
    private class PerformanceHealthCheck : HealthCheck {
        override fun getName() = "performance"

        override fun check(): HealthStatus {
            return try {
                val memory = PerformanceMonitor.getMemoryUsage()
                val heapUsagePercent = memory["heap_usage_percent"] as Int
                val threads = PerformanceMonitor.getThreadInfo()
                val threadCount = threads["thread_count"] as Int

                val issues = mutableListOf<String>()

                if (heapUsagePercent > 90) {
                    issues.add("Critical memory usage: ${heapUsagePercent}%")
                } else if (heapUsagePercent > 80) {
                    issues.add("High memory usage: ${heapUsagePercent}%")
                }

                if (threadCount > 200) {
                    issues.add("High thread count: $threadCount")
                }

                when {
                    issues.any { it.contains("Critical") } -> HealthStatus(
                        HealthStatus.Status.CRITICAL,
                        issues.joinToString("; ")
                    )
                    issues.isNotEmpty() -> HealthStatus(
                        HealthStatus.Status.WARNING,
                        issues.joinToString("; ")
                    )
                    else -> HealthStatus(HealthStatus.Status.HEALTHY, "Performance optimal")
                }
            } catch (e: Exception) {
                HealthStatus(HealthStatus.Status.WARNING, "Performance health check error: ${e.message}")
            }
        }
    }
}