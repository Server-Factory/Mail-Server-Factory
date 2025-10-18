package net.milosvasic.factory.mail.security

import net.milosvasic.factory.mail.BuildInfo
import java.io.File
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Enterprise security auditor for comprehensive audit logging
 */
object SecurityAuditor {

    private val auditLog = ConcurrentLinkedQueue<AuditEvent>()
    private val executor = Executors.newScheduledThreadPool(1)
    private val dateFormatter = DateTimeFormatter.ISO_INSTANT
    private var auditFile: File? = null

    /**
     * Audit event types
     */
    enum class EventType {
        AUTHENTICATION_SUCCESS,
        AUTHENTICATION_FAILURE,
        AUTHORIZATION_FAILURE,
        PASSWORD_CHANGE,
        SESSION_START,
        SESSION_END,
        CONFIGURATION_CHANGE,
        SECURITY_VIOLATION,
        ENCRYPTION_OPERATION,
        DECRYPTION_OPERATION,
        KEY_ROTATION,
        RATE_LIMIT_EXCEEDED,
        TLS_CONNECTION,
        API_ACCESS
    }

    /**
     * Audit event data class
     */
    data class AuditEvent(
        val timestamp: Instant = Instant.now(),
        val eventType: EventType,
        val userId: String? = null,
        val ipAddress: String? = null,
        val resource: String? = null,
        val action: String? = null,
        val details: Map<String, Any> = emptyMap(),
        val success: Boolean = true
    )

    /**
     * Initialize the security auditor
     */
    fun initialize() {
        val logDir = File("logs/security").apply { mkdirs() }
        auditFile = File(logDir, "audit-${BuildInfo.version}.log")

        // Start background audit writer
        executor.scheduleAtFixedRate(::writeAuditLog, 30, 30, TimeUnit.SECONDS)

        // Log initialization
        logEvent(AuditEvent(
            eventType = EventType.CONFIGURATION_CHANGE,
            action = "Security auditor initialized",
            details = mapOf("version" to BuildInfo.version)
        ))
    }

    /**
     * Log a security event
     */
    fun logEvent(event: AuditEvent) {
        auditLog.add(event)

        // Immediate write for critical events
        if (event.eventType in listOf(
                EventType.SECURITY_VIOLATION,
                EventType.AUTHENTICATION_FAILURE,
                EventType.AUTHORIZATION_FAILURE
            )) {
            writeAuditLog()
        }
    }

    /**
     * Log authentication success
     */
    fun logAuthenticationSuccess(userId: String, ipAddress: String? = null) {
        logEvent(AuditEvent(
            eventType = EventType.AUTHENTICATION_SUCCESS,
            userId = userId,
            ipAddress = ipAddress,
            success = true
        ))
    }

    /**
     * Log authentication failure
     */
    fun logAuthenticationFailure(userId: String? = null, ipAddress: String? = null, reason: String? = null) {
        logEvent(AuditEvent(
            eventType = EventType.AUTHENTICATION_FAILURE,
            userId = userId,
            ipAddress = ipAddress,
            details = mapOf("reason" to (reason ?: "Unknown")),
            success = false
        ))
    }

    /**
     * Log authorization failure
     */
    fun logAuthorizationFailure(userId: String? = null, resource: String, action: String, ipAddress: String? = null) {
        logEvent(AuditEvent(
            eventType = EventType.AUTHORIZATION_FAILURE,
            userId = userId,
            ipAddress = ipAddress,
            resource = resource,
            action = action,
            success = false
        ))
    }

    /**
     * Log security violation
     */
    fun logSecurityViolation(violation: String, userId: String? = null, ipAddress: String? = null, details: Map<String, Any> = emptyMap()) {
        logEvent(AuditEvent(
            eventType = EventType.SECURITY_VIOLATION,
            userId = userId,
            ipAddress = ipAddress,
            action = violation,
            details = details,
            success = false
        ))
    }

    /**
     * Log configuration change
     */
    fun logConfigurationChange(change: String, userId: String? = null, details: Map<String, Any> = emptyMap()) {
        logEvent(AuditEvent(
            eventType = EventType.CONFIGURATION_CHANGE,
            userId = userId,
            action = change,
            details = details
        ))
    }

    /**
     * Get audit events for a time range
     */
    fun getAuditEvents(startTime: Instant, endTime: Instant = Instant.now()): List<AuditEvent> {
        return auditLog.filter { it.timestamp.isAfter(startTime) && it.timestamp.isBefore(endTime) }
    }

    /**
     * Get audit events for a specific user
     */
    fun getAuditEventsForUser(userId: String): List<AuditEvent> {
        return auditLog.filter { it.userId == userId }
    }

    /**
     * Get audit events by type
     */
    fun getAuditEventsByType(eventType: EventType): List<AuditEvent> {
        return auditLog.filter { it.eventType == eventType }
    }

    /**
     * Clean up old audit events based on retention policy
     */
    fun cleanupOldEvents() {
        val cutoffTime = Instant.now().minusSeconds(SecurityConfig.AUDIT_LOG_RETENTION_DAYS * 24 * 60 * 60L)
        auditLog.removeIf { it.timestamp.isBefore(cutoffTime) }
    }

    /**
     * Write audit log to file
     */
    private fun writeAuditLog() {
        val file = auditFile ?: return

        try {
            val eventsToWrite = mutableListOf<AuditEvent>()
            while (auditLog.isNotEmpty()) {
                auditLog.poll()?.let { eventsToWrite.add(it) }
            }

            if (eventsToWrite.isNotEmpty()) {
                file.appendText(eventsToWrite.joinToString("\n") { formatAuditEvent(it) } + "\n")
            }
        } catch (e: Exception) {
            // Log to console if file writing fails
            println("Failed to write audit log: ${e.message}")
        }
    }

    /**
     * Format audit event for logging
     */
    private fun formatAuditEvent(event: AuditEvent): String {
        val timestamp = dateFormatter.format(event.timestamp)
        val sanitizedDetails = SecurityConfig.sanitizeForLogging(event.details.toString())

        return "[$timestamp] ${event.eventType} | User: ${event.userId ?: "N/A"} | IP: ${event.ipAddress ?: "N/A"} | " +
               "Resource: ${event.resource ?: "N/A"} | Action: ${event.action ?: "N/A"} | " +
               "Success: ${event.success} | Details: $sanitizedDetails"
    }

    /**
     * Shutdown the auditor
     */
    fun shutdown() {
        executor.shutdown()
        try {
            executor.awaitTermination(5, TimeUnit.SECONDS)
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        writeAuditLog() // Final write
    }
}