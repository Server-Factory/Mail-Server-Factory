package net.milosvasic.factory.mail.logging

import net.milosvasic.factory.mail.BuildInfo
import net.milosvasic.factory.mail.monitoring.MonitoringService
import java.io.File
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.logging.*

/**
 * Enterprise logging system with structured logging and monitoring integration
 */
object EnterpriseLogger {

    private val logger = Logger.getLogger("MailServerFactory")
    private val logQueue = ConcurrentLinkedQueue<LogEntry>()
    private val executor = Executors.newScheduledThreadPool(1)
    private val dateFormatter = DateTimeFormatter.ISO_INSTANT

    // Log levels
    enum class LogLevel {
        TRACE, DEBUG, INFO, WARN, ERROR, FATAL
    }

    // Log entry data class
    data class LogEntry(
        val timestamp: Instant = Instant.now(),
        val level: LogLevel,
        val message: String,
        val logger: String,
        val thread: String = Thread.currentThread().name,
        val exception: Throwable? = null,
        val context: Map<String, Any> = emptyMap()
    )

    init {
        setupLogging()
        startLogProcessor()
    }

    /**
     * Setup logging configuration
     */
    private fun setupLogging() {
        // Remove default handlers
        logger.useParentHandlers = false

        // Create logs directory
        val logDir = File("logs").apply { mkdirs() }

        // File handler for all logs
        val fileHandler = FileHandler("${logDir.absolutePath}/mail-factory-%g.log", 10 * 1024 * 1024, 5, true)
        fileHandler.formatter = StructuredFormatter()
        logger.addHandler(fileHandler)

        // Console handler for INFO and above
        val consoleHandler = ConsoleHandler().apply {
            level = Level.INFO
            formatter = SimpleFormatter()
        }
        logger.addHandler(consoleHandler)

        logger.level = Level.ALL
    }

    /**
     * Log a message with structured data
     */
    fun log(level: LogLevel, message: String, context: Map<String, Any> = emptyMap(), exception: Throwable? = null) {
        val entry = LogEntry(
            level = level,
            message = message,
            logger = logger.name,
            exception = exception,
            context = context
        )

        logQueue.add(entry)

        // Immediate logging for errors and above
        if (level >= LogLevel.ERROR) {
            processLogEntry(entry)
        }
    }

    /**
     * Convenience methods for different log levels
     */
    fun trace(message: String, context: Map<String, Any> = emptyMap()) =
        log(LogLevel.TRACE, message, context)

    fun debug(message: String, context: Map<String, Any> = emptyMap()) =
        log(LogLevel.DEBUG, message, context)

    fun info(message: String, context: Map<String, Any> = emptyMap()) =
        log(LogLevel.INFO, message, context)

    fun warn(message: String, context: Map<String, Any> = emptyMap(), exception: Throwable? = null) =
        log(LogLevel.WARN, message, context, exception)

    fun error(message: String, context: Map<String, Any> = emptyMap(), exception: Throwable? = null) =
        log(LogLevel.ERROR, message, context, exception)

    fun fatal(message: String, context: Map<String, Any> = emptyMap(), exception: Throwable? = null) =
        log(LogLevel.FATAL, message, context, exception)

    /**
     * Log security events
     */
    fun logSecurityEvent(event: String, userId: String? = null, ipAddress: String? = null, success: Boolean = true) {
        log(LogLevel.INFO, "Security event: $event", mapOf(
            "event_type" to "security",
            "user_id" to (userId ?: "unknown"),
            "ip_address" to (ipAddress ?: "unknown"),
            "success" to success
        ))
    }

    /**
     * Log performance metrics
     */
    fun logPerformance(operation: String, durationMs: Long, context: Map<String, Any> = emptyMap()) {
        val level = when {
            durationMs > 5000 -> LogLevel.WARN // Very slow
            durationMs > 1000 -> LogLevel.INFO // Slow
            else -> LogLevel.DEBUG // Normal
        }

        log(level, "Performance: $operation completed in ${durationMs}ms", context + mapOf(
            "operation" to operation,
            "duration_ms" to durationMs,
            "event_type" to "performance"
        ))
    }

    /**
     * Log business events
     */
    fun logBusinessEvent(event: String, entity: String, entityId: String? = null, context: Map<String, Any> = emptyMap()) {
        log(LogLevel.INFO, "Business event: $event", context + mapOf(
            "event_type" to "business",
            "business_event" to event,
            "entity" to entity,
            "entity_id" to (entityId ?: "unknown")
        ))
    }

    /**
     * Start background log processor
     */
    private fun startLogProcessor() {
        executor.scheduleAtFixedRate(::processLogQueue, 1, 1, TimeUnit.SECONDS)
    }

    /**
     * Process queued log entries
     */
    private fun processLogQueue() {
        val entriesToProcess = mutableListOf<LogEntry>()
        while (logQueue.isNotEmpty()) {
            logQueue.poll()?.let { entriesToProcess.add(it) }
        }

        entriesToProcess.forEach { processLogEntry(it) }
    }

    /**
     * Process a single log entry
     */
    private fun processLogEntry(entry: LogEntry) {
        val julLevel = when (entry.level) {
            LogLevel.TRACE -> Level.FINEST
            LogLevel.DEBUG -> Level.FINE
            LogLevel.INFO -> Level.INFO
            LogLevel.WARN -> Level.WARNING
            LogLevel.ERROR -> Level.SEVERE
            LogLevel.FATAL -> Level.SEVERE
        }

        // Create log record
        val record = LogRecord(julLevel, entry.message).apply {
            loggerName = entry.logger
            threadID = entry.thread.hashCode()
            if (entry.exception != null) {
                thrown = entry.exception
            }
            // Add structured data as parameters
            parameters = arrayOf(entry.context, entry.timestamp)
        }

        logger.log(record)

        // Send to monitoring if it's an error or performance issue
        if (entry.level >= LogLevel.ERROR) {
            MonitoringService.getMonitoringReport() // This would trigger monitoring alerts
        }
    }

    /**
     * Get recent log entries
     */
    fun getRecentLogs(level: LogLevel? = null, limit: Int = 100): List<LogEntry> {
        // In a real implementation, this would query a log storage system
        // For now, return empty list as logs are written asynchronously
        return emptyList()
    }

    /**
     * Shutdown logger
     */
    fun shutdown() {
        executor.shutdown()
        try {
            executor.awaitTermination(5, TimeUnit.SECONDS)
        } catch (e: InterruptedException) {
            executor.shutdownNow()
            Thread.currentThread().interrupt()
        }

        // Process remaining logs
        processLogQueue()

        // Close handlers
        logger.handlers.forEach { it.close() }
    }

    /**
     * Structured log formatter
     */
    private class StructuredFormatter : Formatter() {
        override fun format(record: LogRecord): String {
            val timestamp = dateFormatter.format(Instant.ofEpochMilli(record.millis))
            val level = record.level.name
            val logger = record.loggerName ?: "unknown"
            val thread = record.threadID
            val message = record.message

            val context = record.parameters?.getOrNull(0) as? Map<*, *>
            val instant = record.parameters?.getOrNull(1) as? Instant

            val contextStr = context?.entries?.joinToString(", ") { "${it.key}=${it.value}" } ?: ""

            val sb = StringBuilder()
            sb.append("[$timestamp] $level [$logger] [$thread] $message")
            if (contextStr.isNotEmpty()) {
                sb.append(" {$contextStr}")
            }
            if (record.thrown != null) {
                sb.append(" ${formatThrowable(record.thrown)}")
            }
            sb.append("\n")

            return sb.toString()
        }

        private fun formatThrowable(throwable: Throwable): String {
            val sb = StringBuilder()
            sb.append(throwable.javaClass.simpleName).append(": ").append(throwable.message)
            throwable.stackTrace.take(5).forEach { element ->
                sb.append("\n    at $element")
            }
            if (throwable.cause != null) {
                sb.append("\nCaused by: ").append(formatThrowable(throwable.cause!!))
            }
            return sb.toString()
        }
    }
}