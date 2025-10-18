package net.milosvasic.factory.mail.security

import net.milosvasic.factory.mail.BuildInfo
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Enterprise session management for secure user sessions
 */
object SessionManager {

    private val sessions = ConcurrentHashMap<String, Session>()
    private val userSessions = ConcurrentHashMap<String, MutableSet<String>>()
    private val executor = Executors.newSingleThreadScheduledExecutor()

    /**
     * User session data class
     */
    data class Session(
        val sessionId: String,
        val userId: String,
        val ipAddress: String?,
        val userAgent: String?,
        val createdAt: Instant = Instant.now(),
        var lastActivity: Instant = Instant.now(),
        var csrfToken: String = SecurityConfig.generateCsrfToken(),
        var isActive: Boolean = true
    )

    init {
        // Start session cleanup task
        executor.scheduleWithFixedDelay(::cleanupExpiredSessions, 5, 5, TimeUnit.MINUTES)
    }

    /**
     * Create a new session for user
     */
    fun createSession(userId: String, ipAddress: String? = null, userAgent: String? = null): String {
        val sessionId = SecurityConfig.generateSecureToken()

        // Check concurrent session limit
        if (SecurityConfig.ENABLE_CONCURRENT_SESSION_CONTROL) {
            val userSessionIds = userSessions.getOrPut(userId) { mutableSetOf() }

            if (userSessionIds.size >= SecurityConfig.MAX_CONCURRENT_SESSIONS_PER_USER) {
                // Remove oldest session
                val oldestSessionId = userSessionIds.minByOrNull { sessions[it]?.createdAt ?: Instant.MIN }
                oldestSessionId?.let {
                    invalidateSession(it)
                    userSessionIds.remove(it)
                }
            }
        }

        val session = Session(sessionId, userId, ipAddress, userAgent)
        sessions[sessionId] = session

        userSessions.getOrPut(userId) { mutableSetOf() }.add(sessionId)

        SecurityAuditor.logEvent(SecurityAuditor.AuditEvent(
            eventType = SecurityAuditor.EventType.SESSION_START,
            userId = userId,
            ipAddress = ipAddress,
            details = mapOf("user_agent" to (userAgent ?: "Unknown"))
        ))

        return sessionId
    }

    /**
     * Validate session and update activity
     */
    fun validateSession(sessionId: String): Session? {
        val session = sessions[sessionId] ?: return null

        if (!session.isActive) return null

        // Check session timeout
        val now = Instant.now()
        val timeoutDuration = java.time.Duration.ofMinutes(SecurityConfig.SESSION_TIMEOUT_MINUTES.toLong())

        if (session.lastActivity.plus(timeoutDuration).isBefore(now)) {
            invalidateSession(sessionId)
            return null
        }

        // Update last activity
        session.lastActivity = now
        sessions[sessionId] = session

        return session
    }

    /**
     * Get session by ID
     */
    fun getSession(sessionId: String): Session? {
        return sessions[sessionId]
    }

    /**
     * Invalidate a specific session
     */
    fun invalidateSession(sessionId: String) {
        val session = sessions.remove(sessionId)
        if (session != null) {
            userSessions[session.userId]?.remove(sessionId)

            SecurityAuditor.logEvent(SecurityAuditor.AuditEvent(
                eventType = SecurityAuditor.EventType.SESSION_END,
                userId = session.userId,
                ipAddress = session.ipAddress,
                details = mapOf("reason" to "invalidated")
            ))
        }
    }

    /**
     * Invalidate all sessions for a user
     */
    fun invalidateUserSessions(userId: String) {
        val sessionIds = userSessions[userId] ?: emptySet()
        sessionIds.forEach { sessionId ->
            sessions.remove(sessionId)
            SecurityAuditor.logEvent(SecurityAuditor.AuditEvent(
                eventType = SecurityAuditor.EventType.SESSION_END,
                userId = userId,
                details = mapOf("reason" to "user_sessions_invalidated")
            ))
        }
        userSessions.remove(userId)
    }

    /**
     * Get active sessions for a user
     */
    fun getUserSessions(userId: String): List<Session> {
        return userSessions[userId]?.mapNotNull { sessions[it] } ?: emptyList()
    }

    /**
     * Get all active sessions (admin function)
     */
    fun getAllSessions(): List<Session> {
        return sessions.values.toList()
    }

    /**
     * Update session CSRF token
     */
    fun updateCsrfToken(sessionId: String): String? {
        val session = sessions[sessionId] ?: return null
        session.csrfToken = SecurityConfig.generateCsrfToken()
        sessions[sessionId] = session
        return session.csrfToken
    }

    /**
     * Validate session CSRF token
     */
    fun validateCsrfToken(sessionId: String, token: String): Boolean {
        val session = sessions[sessionId] ?: return false
        return session.csrfToken == token
    }

    /**
     * Get session statistics
     */
    fun getSessionStats(): Map<String, Any> {
        val now = Instant.now()
        val activeSessions = sessions.values.filter { it.isActive }
        val expiredSessions = sessions.values.filter { !it.isActive }

        return mapOf(
            "total_sessions" to sessions.size,
            "active_sessions" to activeSessions.size,
            "expired_sessions" to expiredSessions.size,
            "unique_users" to userSessions.size,
            "average_session_age_minutes" to activeSessions.map {
                java.time.Duration.between(it.createdAt, now).toMinutes()
            }.average()
        )
    }

    /**
     * Cleanup expired sessions
     */
    private fun cleanupExpiredSessions() {
        val now = Instant.now()
        val timeoutDuration = java.time.Duration.ofMinutes(SecurityConfig.SESSION_TIMEOUT_MINUTES.toLong())

        val expiredSessionIds = sessions.entries
            .filter { (_, session) ->
                session.lastActivity.plus(timeoutDuration).isBefore(now)
            }
            .map { it.key }

        expiredSessionIds.forEach { sessionId ->
            val session = sessions[sessionId]
            if (session != null) {
                session.isActive = false
                sessions[sessionId] = session
                userSessions[session.userId]?.remove(sessionId)

                SecurityAuditor.logEvent(SecurityAuditor.AuditEvent(
                    eventType = SecurityAuditor.EventType.SESSION_END,
                    userId = session.userId,
                    ipAddress = session.ipAddress,
                    details = mapOf("reason" to "expired")
                ))
            }
        }
    }

    /**
     * Shutdown session manager
     */
    fun shutdown() {
        executor.shutdown()
        try {
            executor.awaitTermination(5, TimeUnit.SECONDS)
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
        }
    }
}