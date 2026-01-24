import XCTest
@testable import FlagKit

final class CacheTests: XCTestCase {
    func testSetAndGet() async {
        let cache = Cache<String>(ttl: 60, maxSize: 10)

        await cache.set("key1", value: "value1")
        let result = await cache.get("key1")

        XCTAssertEqual(result, "value1")
    }

    func testGetMissingKey() async {
        let cache = Cache<String>(ttl: 60, maxSize: 10)
        let result = await cache.get("nonexistent")

        XCTAssertNil(result)
    }

    func testHas() async {
        let cache = Cache<String>(ttl: 60, maxSize: 10)

        await cache.set("key1", value: "value1")

        let hasKey1 = await cache.has("key1")
        let hasKey2 = await cache.has("nonexistent")

        XCTAssertTrue(hasKey1)
        XCTAssertFalse(hasKey2)
    }

    func testDelete() async {
        let cache = Cache<String>(ttl: 60, maxSize: 10)

        await cache.set("key1", value: "value1")
        let deleted = await cache.delete("key1")
        let result = await cache.get("key1")

        XCTAssertTrue(deleted)
        XCTAssertNil(result)
    }

    func testDeleteMissingKey() async {
        let cache = Cache<String>(ttl: 60, maxSize: 10)
        let deleted = await cache.delete("nonexistent")

        XCTAssertFalse(deleted)
    }

    func testClear() async {
        let cache = Cache<String>(ttl: 60, maxSize: 10)

        await cache.set("key1", value: "value1")
        await cache.set("key2", value: "value2")
        await cache.clear()

        let count = await cache.count

        XCTAssertEqual(count, 0)
    }

    func testCount() async {
        let cache = Cache<String>(ttl: 60, maxSize: 10)

        let count0 = await cache.count
        await cache.set("key1", value: "value1")
        let count1 = await cache.count
        await cache.set("key2", value: "value2")
        let count2 = await cache.count

        XCTAssertEqual(count0, 0)
        XCTAssertEqual(count1, 1)
        XCTAssertEqual(count2, 2)
    }

    func testKeys() async {
        let cache = Cache<String>(ttl: 60, maxSize: 10)

        await cache.set("key1", value: "value1")
        await cache.set("key2", value: "value2")

        let keys = await cache.getAllKeys()

        XCTAssertEqual(Set(keys), Set(["key1", "key2"]))
    }

    func testToDictionary() async {
        let cache = Cache<String>(ttl: 60, maxSize: 10)

        await cache.set("key1", value: "value1")
        await cache.set("key2", value: "value2")

        let dict = await cache.toDictionary()

        XCTAssertEqual(dict, ["key1": "value1", "key2": "value2"])
    }

    func testSetMany() async {
        let cache = Cache<String>(ttl: 60, maxSize: 10)

        await cache.setMany(["key1": "value1", "key2": "value2"])

        let value1 = await cache.get("key1")
        let value2 = await cache.get("key2")

        XCTAssertEqual(value1, "value1")
        XCTAssertEqual(value2, "value2")
    }

    func testGetStaleValue() async throws {
        let cache = Cache<String>(ttl: 0.1, maxSize: 10)

        await cache.set("key1", value: "value1")

        // Wait for expiration
        try await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds

        // Stale value should be available even after expiration
        // Note: We check stale value BEFORE calling get(), because get() removes expired entries
        let staleValue = await cache.getStaleValue("key1")
        XCTAssertEqual(staleValue, "value1")

        // Now regular get should return nil and remove the entry
        let expiredValue = await cache.get("key1")
        XCTAssertNil(expiredValue)

        // After get() was called, the entry is removed
        let staleValueAfter = await cache.getStaleValue("key1")
        XCTAssertNil(staleValueAfter)
    }

    func testIsStale() async throws {
        let cache = Cache<String>(ttl: 0.1, maxSize: 10)

        await cache.set("key1", value: "value1")

        // Initially not stale
        let notStale = await cache.isStale("key1")
        XCTAssertFalse(notStale)

        // Wait for expiration
        try await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds

        // Now should be stale
        let isStale = await cache.isStale("key1")
        XCTAssertTrue(isStale)
    }

    func testGetStats() async {
        let cache = Cache<String>(ttl: 60, maxSize: 100)

        await cache.set("key1", value: "value1")
        await cache.set("key2", value: "value2")

        let stats = await cache.getStats()

        XCTAssertEqual(stats.size, 2)
        XCTAssertEqual(stats.validCount, 2)
        XCTAssertEqual(stats.staleCount, 0)
        XCTAssertEqual(stats.maxSize, 100)
    }

    func testTTLExpiration() async throws {
        let cache = Cache<String>(ttl: 0.1, maxSize: 10)

        await cache.set("key1", value: "value1")

        let initialValue = await cache.get("key1")
        XCTAssertEqual(initialValue, "value1")

        try await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds

        let expiredValue = await cache.get("key1")
        XCTAssertNil(expiredValue)
    }

    func testLRUEviction() async {
        let cache = Cache<String>(ttl: 60, maxSize: 3)

        await cache.set("key1", value: "value1")
        await cache.set("key2", value: "value2")
        await cache.set("key3", value: "value3")

        // Add new entry, should evict one of the existing entries
        await cache.set("key4", value: "value4")

        let value1 = await cache.get("key1")
        let value2 = await cache.get("key2")
        let value3 = await cache.get("key3")
        let value4 = await cache.get("key4")

        // One of the original entries should be evicted
        let existingValues = [value1, value2, value3].compactMap { $0 }
        XCTAssertEqual(existingValues.count, 2, "One entry should have been evicted")
        XCTAssertEqual(value4, "value4", "New entry should exist")
    }
}
