import Foundation

/// Cache entry with metadata for TTL and access tracking.
public struct CacheEntry<Value: Sendable>: Sendable {
    /// The cached value.
    public let value: Value

    /// When the entry was fetched.
    public let fetchedAt: Date

    /// When the entry expires.
    public let expiresAt: Date

    /// When the entry was last accessed.
    public var lastAccessedAt: Date

    /// Whether the entry is expired.
    public var isExpired: Bool {
        Date() > expiresAt
    }

    /// Creates a new cache entry.
    public init(value: Value, fetchedAt: Date = Date(), expiresAt: Date, lastAccessedAt: Date = Date()) {
        self.value = value
        self.fetchedAt = fetchedAt
        self.expiresAt = expiresAt
        self.lastAccessedAt = lastAccessedAt
    }
}

/// Cache statistics for monitoring and debugging.
public struct CacheStats: Sendable {
    /// Total number of entries.
    public let size: Int

    /// Number of valid (non-expired) entries.
    public let validCount: Int

    /// Number of stale (expired but available) entries.
    public let staleCount: Int

    /// Maximum allowed entries.
    public let maxSize: Int
}

/// Thread-safe in-memory cache with TTL, LRU eviction, and stale value support.
public actor Cache<Value: Sendable> {
    private var entries: [String: CacheEntry<Value>] = [:]
    private let ttl: TimeInterval
    private let maxSize: Int

    /// Creates a new cache.
    /// - Parameters:
    ///   - ttl: Time to live in seconds. Default: 300 (5 minutes).
    ///   - maxSize: Maximum number of entries. Default: 1000.
    public init(ttl: TimeInterval = 300, maxSize: Int = 1000) {
        self.ttl = ttl
        self.maxSize = maxSize
    }

    /// Gets a value from the cache if it exists and is not expired.
    /// - Parameter key: The cache key.
    /// - Returns: The cached value, or nil if not found or expired.
    public func get(_ key: String) -> Value? {
        guard var entry = entries[key] else { return nil }

        if entry.isExpired {
            entries.removeValue(forKey: key)
            return nil
        }

        entry.lastAccessedAt = Date()
        entries[key] = entry
        return entry.value
    }

    /// Gets a cache entry with full metadata.
    /// - Parameter key: The cache key.
    /// - Returns: The cache entry, or nil if not found.
    public func getEntry(_ key: String) -> CacheEntry<Value>? {
        return entries[key]
    }

    /// Gets a value even if it's expired (stale).
    /// Useful as a fallback when network is unavailable.
    /// - Parameter key: The cache key.
    /// - Returns: The cached value regardless of expiration, or nil if not found.
    public func getStaleValue(_ key: String) -> Value? {
        return entries[key]?.value
    }

    /// Checks if a cached entry is stale (expired but still available).
    /// - Parameter key: The cache key.
    /// - Returns: True if the entry exists and is expired.
    public func isStale(_ key: String) -> Bool {
        guard let entry = entries[key] else { return false }
        return entry.isExpired
    }

    /// Sets a value in the cache.
    /// - Parameters:
    ///   - key: The cache key.
    ///   - value: The value to cache.
    ///   - customTtl: Optional custom TTL for this entry.
    public func set(_ key: String, value: Value, ttl customTtl: TimeInterval? = nil) {
        evictIfNeeded()

        let now = Date()
        let entry = CacheEntry(
            value: value,
            fetchedAt: now,
            expiresAt: now.addingTimeInterval(customTtl ?? ttl),
            lastAccessedAt: now
        )
        entries[key] = entry
    }

    /// Sets multiple values in the cache.
    /// - Parameters:
    ///   - dict: Dictionary of keys to values.
    ///   - customTtl: Optional custom TTL for these entries.
    public func setMany(_ dict: [String: Value], ttl customTtl: TimeInterval? = nil) {
        for (key, value) in dict {
            set(key, value: value, ttl: customTtl)
        }
    }

    /// Checks if a key exists in the cache (not expired).
    /// - Parameter key: The cache key.
    /// - Returns: True if the key exists and is not expired.
    public func has(_ key: String) -> Bool {
        guard let entry = entries[key] else { return false }

        if entry.isExpired {
            entries.removeValue(forKey: key)
            return false
        }

        return true
    }

    /// Deletes a value from the cache.
    /// - Parameter key: The cache key.
    /// - Returns: True if the key was found and deleted.
    @discardableResult
    public func delete(_ key: String) -> Bool {
        entries.removeValue(forKey: key) != nil
    }

    /// Clears all entries from the cache.
    public func clear() {
        entries.removeAll()
    }

    /// Returns the number of valid (non-expired) entries.
    public var count: Int {
        cleanupExpired()
        return entries.count
    }

    /// Returns the total number of entries including stale ones.
    public var totalCount: Int {
        return entries.count
    }

    /// Returns all keys of valid entries.
    public func getAllKeys() -> [String] {
        cleanupExpired()
        return Array(entries.keys)
    }

    /// Returns all keys including stale entries.
    public func getAllKeysIncludingStale() -> [String] {
        return Array(entries.keys)
    }

    /// Returns all valid (non-expired) values.
    public func getAllValid() -> [Value] {
        let now = Date()
        return entries.values
            .filter { now <= $0.expiresAt }
            .map { $0.value }
    }

    /// Returns all values including stale ones.
    public func getAll() -> [Value] {
        return entries.values.map { $0.value }
    }

    /// Returns all values as a dictionary (valid entries only).
    public func toDictionary() -> [String: Value] {
        cleanupExpired()
        return entries.mapValues { $0.value }
    }

    /// Gets cache statistics.
    public func getStats() -> CacheStats {
        let now = Date()
        var validCount = 0
        var staleCount = 0

        for entry in entries.values {
            if now <= entry.expiresAt {
                validCount += 1
            } else {
                staleCount += 1
            }
        }

        return CacheStats(
            size: entries.count,
            validCount: validCount,
            staleCount: staleCount,
            maxSize: maxSize
        )
    }

    /// Exports cache data for persistence.
    /// - Returns: Dictionary of keys to cache entries.
    public func export() -> [String: CacheEntry<Value>] {
        return entries
    }

    /// Imports cache data from persistence.
    /// Only imports non-expired entries.
    /// - Parameter data: Dictionary of keys to cache entries.
    public func importData(_ data: [String: CacheEntry<Value>]) {
        let now = Date()
        for (key, entry) in data {
            if now <= entry.expiresAt {
                entries[key] = entry
            }
        }
    }

    // MARK: - Private Methods

    private func cleanupExpired() {
        entries = entries.filter { !$0.value.isExpired }
    }

    private func evictIfNeeded() {
        guard entries.count >= maxSize else { return }

        cleanupExpired()
        guard entries.count >= maxSize else { return }

        // LRU eviction - remove least recently accessed entry
        if let lruKey = entries.min(by: { $0.value.lastAccessedAt < $1.value.lastAccessedAt })?.key {
            entries.removeValue(forKey: lruKey)
        }
    }
}

// MARK: - Encrypted Persistent Cache

import CryptoKit

/// Encrypted cache entry for persistence.
public struct EncryptedCacheEntry: Codable, Sendable {
    /// The encrypted value (base64 encoded).
    public let encryptedValue: String
    /// When the entry was fetched.
    public let fetchedAt: Date
    /// When the entry expires.
    public let expiresAt: Date
    /// When the entry was last accessed.
    public var lastAccessedAt: Date

    /// Whether the entry is expired.
    public var isExpired: Bool {
        Date() > expiresAt
    }
}

/// Thread-safe encrypted cache for persistent storage with AES-GCM encryption.
/// Uses PBKDF2 to derive encryption key from API key.
public actor EncryptedCache {
    private var entries: [String: EncryptedCacheEntry] = [:]
    private let ttl: TimeInterval
    private let maxSize: Int
    private let encryptionKey: SymmetricKey
    private let storageURL: URL?

    /// Creates a new encrypted cache.
    /// - Parameters:
    ///   - apiKey: The API key used to derive the encryption key.
    ///   - ttl: Time to live in seconds. Default: 300 (5 minutes).
    ///   - maxSize: Maximum number of entries. Default: 1000.
    ///   - storageURL: Optional URL for persistent storage.
    /// - Throws: SecurityError.keyDerivationFailed if key derivation fails.
    public init(
        apiKey: String,
        ttl: TimeInterval = 300,
        maxSize: Int = 1000,
        storageURL: URL? = nil
    ) throws {
        self.ttl = ttl
        self.maxSize = maxSize
        self.encryptionKey = try CacheEncryption.deriveKey(from: apiKey)
        self.storageURL = storageURL
    }

    /// Gets a decrypted value from the cache.
    /// - Parameters:
    ///   - key: The cache key.
    ///   - type: The type to decode to.
    /// - Returns: The decrypted value, or nil if not found, expired, or decryption fails.
    public func get<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        guard var entry = entries[key] else { return nil }

        if entry.isExpired {
            entries.removeValue(forKey: key)
            return nil
        }

        entry.lastAccessedAt = Date()
        entries[key] = entry

        do {
            return try CacheEncryption.decryptJSON(entry.encryptedValue, as: type, with: encryptionKey)
        } catch {
            // Remove corrupted entry
            entries.removeValue(forKey: key)
            return nil
        }
    }

    /// Gets a decrypted string value from the cache.
    /// - Parameter key: The cache key.
    /// - Returns: The decrypted string, or nil if not found or expired.
    public func getString(_ key: String) -> String? {
        guard var entry = entries[key] else { return nil }

        if entry.isExpired {
            entries.removeValue(forKey: key)
            return nil
        }

        entry.lastAccessedAt = Date()
        entries[key] = entry

        do {
            return try CacheEncryption.decryptString(entry.encryptedValue, with: encryptionKey)
        } catch {
            entries.removeValue(forKey: key)
            return nil
        }
    }

    /// Gets a stale (expired but available) value.
    /// - Parameters:
    ///   - key: The cache key.
    ///   - type: The type to decode to.
    /// - Returns: The decrypted value regardless of expiration, or nil if not found.
    public func getStaleValue<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        guard let entry = entries[key] else { return nil }
        return try? CacheEncryption.decryptJSON(entry.encryptedValue, as: type, with: encryptionKey)
    }

    /// Sets an encrypted value in the cache.
    /// - Parameters:
    ///   - key: The cache key.
    ///   - value: The value to encrypt and cache.
    ///   - customTtl: Optional custom TTL for this entry.
    /// - Throws: SecurityError if encryption fails.
    public func set<T: Encodable>(_ key: String, value: T, ttl customTtl: TimeInterval? = nil) throws {
        evictIfNeeded()

        let encrypted = try CacheEncryption.encryptJSON(value, with: encryptionKey)
        let now = Date()
        let entry = EncryptedCacheEntry(
            encryptedValue: encrypted,
            fetchedAt: now,
            expiresAt: now.addingTimeInterval(customTtl ?? ttl),
            lastAccessedAt: now
        )
        entries[key] = entry
    }

    /// Sets an encrypted string value in the cache.
    /// - Parameters:
    ///   - key: The cache key.
    ///   - value: The string value to encrypt and cache.
    ///   - customTtl: Optional custom TTL for this entry.
    /// - Throws: SecurityError if encryption fails.
    public func setString(_ key: String, value: String, ttl customTtl: TimeInterval? = nil) throws {
        evictIfNeeded()

        let encrypted = try CacheEncryption.encryptString(value, with: encryptionKey)
        let now = Date()
        let entry = EncryptedCacheEntry(
            encryptedValue: encrypted,
            fetchedAt: now,
            expiresAt: now.addingTimeInterval(customTtl ?? ttl),
            lastAccessedAt: now
        )
        entries[key] = entry
    }

    /// Checks if a key exists in the cache (not expired).
    public func has(_ key: String) -> Bool {
        guard let entry = entries[key] else { return false }

        if entry.isExpired {
            entries.removeValue(forKey: key)
            return false
        }

        return true
    }

    /// Deletes a value from the cache.
    @discardableResult
    public func delete(_ key: String) -> Bool {
        entries.removeValue(forKey: key) != nil
    }

    /// Clears all entries from the cache.
    public func clear() {
        entries.removeAll()
    }

    /// Returns the number of valid (non-expired) entries.
    public var count: Int {
        cleanupExpired()
        return entries.count
    }

    /// Returns all keys of valid entries.
    public func getAllKeys() -> [String] {
        cleanupExpired()
        return Array(entries.keys)
    }

    /// Gets cache statistics.
    public func getStats() -> CacheStats {
        let now = Date()
        var validCount = 0
        var staleCount = 0

        for entry in entries.values {
            if now <= entry.expiresAt {
                validCount += 1
            } else {
                staleCount += 1
            }
        }

        return CacheStats(
            size: entries.count,
            validCount: validCount,
            staleCount: staleCount,
            maxSize: maxSize
        )
    }

    /// Persists the encrypted cache to storage.
    /// - Throws: If persistence fails.
    public func persist() throws {
        guard let url = storageURL else { return }
        let data = try JSONEncoder().encode(entries)
        try data.write(to: url, options: .atomic)
    }

    /// Loads the encrypted cache from storage.
    /// - Throws: If loading fails.
    public func load() throws {
        guard let url = storageURL else { return }
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let data = try Data(contentsOf: url)
        let loaded = try JSONDecoder().decode([String: EncryptedCacheEntry].self, from: data)

        // Only import non-expired entries
        let now = Date()
        for (key, entry) in loaded {
            if now <= entry.expiresAt {
                entries[key] = entry
            }
        }
    }

    // MARK: - Private Methods

    private func cleanupExpired() {
        entries = entries.filter { !$0.value.isExpired }
    }

    private func evictIfNeeded() {
        guard entries.count >= maxSize else { return }

        cleanupExpired()
        guard entries.count >= maxSize else { return }

        // LRU eviction
        if let lruKey = entries.min(by: { $0.value.lastAccessedAt < $1.value.lastAccessedAt })?.key {
            entries.removeValue(forKey: lruKey)
        }
    }
}
