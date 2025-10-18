package net.milosvasic.factory.mail.performance

import com.github.benmanes.caffeine.cache.Cache
import com.github.benmanes.caffeine.cache.Caffeine
import net.milosvasic.factory.mail.BuildInfo
import java.time.Duration
import java.util.concurrent.ConcurrentHashMap

/**
 * Enterprise caching manager with multiple cache regions
 */
object CacheManager {

    private val caches = ConcurrentHashMap<String, Cache<Any, Any>>()

    // Cache region names
    const val USER_CACHE = "user"
    const val SESSION_CACHE = "session"
    const val CONFIG_CACHE = "config"
    const val API_RESPONSE_CACHE = "api_response"
    const val DNS_CACHE = "dns"

    /**
     * Initialize caches
     */
    fun initialize() {
        if (!PerformanceConfig.ENABLE_CACHING) return

        // User data cache
        createCache(USER_CACHE, PerformanceConfig.CACHE_MAX_SIZE,
            Duration.ofMinutes(PerformanceConfig.CACHE_EXPIRE_AFTER_WRITE_MINUTES.toLong()),
            Duration.ofMinutes(PerformanceConfig.CACHE_EXPIRE_AFTER_ACCESS_MINUTES.toLong()))

        // Session cache
        createCache(SESSION_CACHE, 1000,
            Duration.ofMinutes(30), // Sessions expire in 30 minutes
            Duration.ofMinutes(10))

        // Configuration cache
        createCache(CONFIG_CACHE, 500,
            Duration.ofHours(1), // Config changes are rare
            Duration.ofMinutes(30))

        // API response cache
        createCache(API_RESPONSE_CACHE, 2000,
            Duration.ofMinutes(5), // Short-lived for API responses
            Duration.ofMinutes(2))

        // DNS cache
        createCache(DNS_CACHE, 1000,
            Duration.ofHours(1), // DNS records change infrequently
            Duration.ofMinutes(30))
    }

    /**
     * Create a cache with specified parameters
     */
    private fun createCache(
        name: String,
        maxSize: Int,
        expireAfterWrite: Duration,
        expireAfterAccess: Duration
    ) {
        val cache = Caffeine.newBuilder()
            .maximumSize(maxSize.toLong())
            .expireAfterWrite(expireAfterWrite)
            .expireAfterAccess(expireAfterAccess)
            .recordStats()
            .build<Any, Any>()

        caches[name] = cache
    }

    /**
     * Get a value from cache
     */
    fun get(cacheName: String, key: Any): Any? {
        return caches[cacheName]?.getIfPresent(key)
    }

    /**
     * Put a value in cache
     */
    fun put(cacheName: String, key: Any, value: Any) {
        caches[cacheName]?.put(key, value)
    }

    /**
     * Remove a value from cache
     */
    fun remove(cacheName: String, key: Any) {
        caches[cacheName]?.invalidate(key)
    }

    /**
     * Clear entire cache
     */
    fun clear(cacheName: String) {
        caches[cacheName]?.invalidateAll()
    }

    /**
     * Clear all caches
     */
    fun clearAll() {
        caches.values.forEach { it.invalidateAll() }
    }

    /**
     * Get cache statistics
     */
    fun getCacheStats(cacheName: String): Map<String, Any>? {
        val cache = caches[cacheName] ?: return null
        val stats = cache.stats()

        return mapOf(
            "hit_count" to stats.hitCount(),
            "miss_count" to stats.missCount(),
            "hit_rate" to stats.hitRate(),
            "eviction_count" to stats.evictionCount(),
            "load_count" to stats.loadCount(),
            "estimated_size" to cache.estimatedSize()
        )
    }

    /**
     * Get all cache statistics
     */
    fun getAllCacheStats(): Map<String, Map<String, Any>> {
        return caches.keys.associateWith { cacheName ->
            getCacheStats(cacheName) ?: emptyMap()
        }
    }

    /**
     * Check if cache contains key
     */
    fun contains(cacheName: String, key: Any): Boolean {
        return caches[cacheName]?.getIfPresent(key) != null
    }

    /**
     * Get or compute value with cache
     */
    fun <K, V> getOrCompute(cacheName: String, key: K, loader: (K) -> V): V? {
        val cache = caches[cacheName] ?: return loader(key)

        return cache.get(key) { k ->
            try {
                loader(k as K)
            } catch (e: Exception) {
                null // Don't cache failures
            }
        } as V?
    }

    /**
     * Get cache size
     */
    fun getCacheSize(cacheName: String): Long {
        return caches[cacheName]?.estimatedSize() ?: 0
    }

    /**
     * Get total cache sizes
     */
    fun getTotalCacheStats(): Map<String, Any> {
        val totalSize = caches.values.sumOf { it.estimatedSize() }
        val totalStats = caches.values.map { it.stats() }

        return mapOf(
            "total_caches" to caches.size,
            "total_entries" to totalSize,
            "total_hit_count" to totalStats.sumOf { it.hitCount() },
            "total_miss_count" to totalStats.sumOf { it.missCount() },
            "average_hit_rate" to if (totalStats.isNotEmpty()) {
                totalStats.map { it.hitRate() }.average()
            } else 0.0
        )
    }

    /**
     * Shutdown cache manager
     */
    fun shutdown() {
        clearAll()
        caches.clear()
    }
}