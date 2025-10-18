package net.milosvasic.factory.mail.monitoring

import net.milosvasic.factory.mail.BuildInfo
import net.milosvasic.factory.mail.performance.CacheManager
import net.milosvasic.factory.mail.performance.PerformanceMonitor
import net.milosvasic.factory.mail.security.SecurityAuditor
import net.milosvasic.factory.mail.security.SessionManager
import java.io.IOException
import java.net.InetSocketAddress
import java.time.Instant
import java.util.concurrent.Executors
import com.sun.net.httpserver.HttpServer
import com.sun.net.httpserver.HttpHandler
import com.sun.net.httpserver.HttpExchange

/**
 * Metrics exporter for Prometheus and other monitoring systems
 */
object MetricsExporter {

    private var server: HttpServer? = null
    private val executor = Executors.newCachedThreadPool()

    // Metrics endpoint
    const val METRICS_PORT = 9090
    const val METRICS_PATH = "/metrics"

    /**
     * Start metrics server
     */
    fun start(port: Int = METRICS_PORT) {
        try {
            server = HttpServer.create(InetSocketAddress(port), 0)
            server?.executor = executor
            server?.createContext(METRICS_PATH, MetricsHandler())
            server?.start()

            println("Metrics server started on port $port")
        } catch (e: IOException) {
            println("Failed to start metrics server: ${e.message}")
        }
    }

    /**
     * Stop metrics server
     */
    fun stop() {
        server?.stop(5)
        executor.shutdown()
    }

    /**
     * Metrics HTTP handler
     */
    private class MetricsHandler : HttpHandler {
        override fun handle(exchange: HttpExchange) {
            try {
                if (exchange.requestMethod != "GET") {
                    exchange.sendResponseHeaders(405, -1)
                    return
                }

                val metrics = generateMetrics()
                val response = metrics.toByteArray(Charsets.UTF_8)

                exchange.responseHeaders.set("Content-Type", "text/plain; charset=utf-8")
                exchange.sendResponseHeaders(200, response.size.toLong())

                exchange.responseBody.use { it.write(response) }
            } catch (e: Exception) {
                exchange.sendResponseHeaders(500, -1)
            }
        }
    }

    /**
     * Generate Prometheus-compatible metrics
     */
    private fun generateMetrics(): String {
        val sb = StringBuilder()

        // Add header comments
        sb.append("# Mail Server Factory Metrics\n")
        sb.append("# Generated at ${Instant.now()}\n")
        sb.append("# Version: ${BuildInfo.version}\n\n")

        // System metrics
        val systemInfo = PerformanceMonitor.getSystemInfo()
        sb.append("# HELP mail_factory_uptime_seconds System uptime in seconds\n")
        sb.append("# TYPE mail_factory_uptime_seconds gauge\n")
        sb.append("mail_factory_uptime_seconds ${(systemInfo["uptime_seconds"] as? Long ?: 0)}\n\n")

        sb.append("# HELP mail_factory_processors_available Number of available processors\n")
        sb.append("# TYPE mail_factory_processors_available gauge\n")
        sb.append("mail_factory_processors_available ${(systemInfo["processors"] as? Int ?: 0)}\n\n")

        // Memory metrics
        val memory = PerformanceMonitor.getMemoryUsage()
        sb.append("# HELP mail_factory_heap_used_bytes JVM heap memory used in bytes\n")
        sb.append("# TYPE mail_factory_heap_used_bytes gauge\n")
        sb.append("mail_factory_heap_used_bytes ${(memory["heap_used_mb"] as? Long ?: 0) * 1024 * 1024}\n\n")

        sb.append("# HELP mail_factory_heap_committed_bytes JVM heap memory committed in bytes\n")
        sb.append("# TYPE mail_factory_heap_committed_bytes gauge\n")
        sb.append("mail_factory_heap_committed_bytes ${(memory["heap_committed_mb"] as? Long ?: 0) * 1024 * 1024}\n\n")

        sb.append("# HELP mail_factory_heap_max_bytes JVM heap memory max in bytes\n")
        sb.append("# TYPE mail_factory_heap_max_bytes gauge\n")
        sb.append("mail_factory_heap_max_bytes ${(memory["heap_max_mb"] as? Long ?: 0) * 1024 * 1024}\n\n")

        // Thread metrics
        val threads = PerformanceMonitor.getThreadInfo()
        sb.append("# HELP mail_factory_threads_current Current number of threads\n")
        sb.append("# TYPE mail_factory_threads_current gauge\n")
        sb.append("mail_factory_threads_current ${(threads["thread_count"] as? Int ?: 0)}\n\n")

        sb.append("# HELP mail_factory_threads_daemon Number of daemon threads\n")
        sb.append("# TYPE mail_factory_threads_daemon gauge\n")
        sb.append("mail_factory_threads_daemon ${(threads["daemon_thread_count"] as? Int ?: 0)}\n\n")

        sb.append("# HELP mail_factory_threads_peak Peak number of threads\n")
        sb.append("# TYPE mail_factory_threads_peak gauge\n")
        sb.append("mail_factory_threads_peak ${(threads["peak_thread_count"] as? Int ?: 0)}\n\n")

        // Application metrics
        val appMetrics = PerformanceMonitor.getApplicationMetrics()
        sb.append("# HELP mail_factory_requests_total Total number of requests\n")
        sb.append("# TYPE mail_factory_requests_total counter\n")
        sb.append("mail_factory_requests_total ${(appMetrics["total_requests"] as? Long ?: 0)}\n\n")

        sb.append("# HELP mail_factory_errors_total Total number of errors\n")
        sb.append("# TYPE mail_factory_errors_total counter\n")
        sb.append("mail_factory_errors_total ${(appMetrics["total_errors"] as? Long ?: 0)}\n\n")

        sb.append("# HELP mail_factory_connections_active Number of active connections\n")
        sb.append("# TYPE mail_factory_connections_active gauge\n")
        sb.append("mail_factory_connections_active ${(appMetrics["active_connections"] as? Long ?: 0)}\n\n")

        sb.append("# HELP mail_factory_response_time_average_ms Average response time in milliseconds\n")
        sb.append("# TYPE mail_factory_response_time_average_ms gauge\n")
        sb.append("mail_factory_response_time_average_ms ${(appMetrics["average_response_time_ms"] as? Long ?: 0)}\n\n")

        // Cache metrics
        val cacheStats = CacheManager.getTotalCacheStats()
        sb.append("# HELP mail_factory_cache_total_entries Total entries across all caches\n")
        sb.append("# TYPE mail_factory_cache_total_entries gauge\n")
        sb.append("mail_factory_cache_total_entries ${(cacheStats["total_entries"] as? Long ?: 0)}\n\n")

        sb.append("# HELP mail_factory_cache_hit_rate_average Average cache hit rate\n")
        sb.append("# TYPE mail_factory_cache_hit_rate_average gauge\n")
        sb.append("mail_factory_cache_hit_rate_average ${((cacheStats["average_hit_rate"] as? Double ?: 0.0) * 100).toInt()}\n\n")

        // Security metrics
        val auditEvents = SecurityAuditor.getAuditEvents(Instant.now().minusSeconds(3600)) // Last hour
        val authFailures = auditEvents.count { it.eventType == SecurityAuditor.EventType.AUTHENTICATION_FAILURE }
        val securityViolations = auditEvents.count { it.eventType == SecurityAuditor.EventType.SECURITY_VIOLATION }

        sb.append("# HELP mail_factory_security_auth_failures_total Authentication failures in the last hour\n")
        sb.append("# TYPE mail_factory_security_auth_failures_total gauge\n")
        sb.append("mail_factory_security_auth_failures_total $authFailures\n\n")

        sb.append("# HELP mail_factory_security_violations_total Security violations in the last hour\n")
        sb.append("# TYPE mail_factory_security_violations_total gauge\n")
        sb.append("mail_factory_security_violations_total $securityViolations\n\n")

        // Session metrics
        val sessionStats = SessionManager.getSessionStats()
        sb.append("# HELP mail_factory_sessions_active Number of active sessions\n")
        sb.append("# TYPE mail_factory_sessions_active gauge\n")
        sb.append("mail_factory_sessions_active ${(sessionStats["active_sessions"] as? Int ?: 0)}\n\n")

        sb.append("# HELP mail_factory_sessions_total Total number of sessions\n")
        sb.append("# TYPE mail_factory_sessions_total gauge\n")
        sb.append("mail_factory_sessions_total ${(sessionStats["total_sessions"] as? Int ?: 0)}\n\n")

        // Health status
        val healthStatus = MonitoringService.getOverallHealth()
        val healthValue = when (healthStatus) {
            MonitoringService.HealthStatus.Status.HEALTHY -> 1
            MonitoringService.HealthStatus.Status.WARNING -> 2
            MonitoringService.HealthStatus.Status.CRITICAL -> 3
            MonitoringService.HealthStatus.Status.UNKNOWN -> 0
        }

        sb.append("# HELP mail_factory_health_status Overall system health (1=healthy, 2=warning, 3=critical, 0=unknown)\n")
        sb.append("# TYPE mail_factory_health_status gauge\n")
        sb.append("mail_factory_health_status $healthValue\n\n")

        // Build info
        sb.append("# HELP mail_factory_build_info Build information\n")
        sb.append("# TYPE mail_factory_build_info gauge\n")
        sb.append("mail_factory_build_info{version=\"${BuildInfo.version}\",build=\"${BuildInfo.versionCode}\"} 1\n\n")

        return sb.toString()
    }
}