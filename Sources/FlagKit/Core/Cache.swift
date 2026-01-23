import Foundation

/// Thread-safe in-memory cache with TTL and LRU eviction.
public actor Cache<Value: Sendable> {
    private struct Entry {
        let value: Value
        let expiresAt: Date
        var lastAccessedAt: Date

        var isExpired: Bool {
            Date() > expiresAt
        }
    }

    private var entries: [String: Entry] = [:]
    private let ttl: TimeInterval
    private let maxSize: Int

    /// Creates a new cache.
    /// - Parameters:
    ///   - ttl: Time to live in seconds.
    ///   - maxSize: Maximum number of entries.
    public init(ttl: TimeInterval = 300, maxSize: Int = 1000) {
        self.ttl = ttl
        self.maxSize = maxSize
    }

    /// Gets a value from the cache.
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

    /// Sets a value in the cache.
    public func set(_ key: String, value: Value) {
        evictIfNeeded()

        let entry = Entry(
            value: value,
            expiresAt: Date().addingTimeInterval(ttl),
            lastAccessedAt: Date()
        )
        entries[key] = entry
    }

    /// Checks if a key exists in the cache.
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

    /// Clears all entries.
    public func clear() {
        entries.removeAll()
    }

    /// Returns the number of entries.
    public var count: Int {
        cleanupExpired()
        return entries.count
    }

    /// Returns all keys.
    public var keys: [String] {
        cleanupExpired()
        return Array(entries.keys)
    }

    /// Returns all values as a dictionary.
    public func toDictionary() -> [String: Value] {
        cleanupExpired()
        return entries.mapValues { $0.value }
    }

    /// Sets multiple values.
    public func setAll(_ dict: [String: Value]) {
        for (key, value) in dict {
            set(key, value: value)
        }
    }

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
