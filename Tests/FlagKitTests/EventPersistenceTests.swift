import XCTest
@testable import FlagKit

final class EventPersistenceTests: XCTestCase {
    var tempDirectory: String!

    override func setUp() {
        super.setUp()
        tempDirectory = NSTemporaryDirectory().appending("flagkit-test-\(UUID().uuidString)")
    }

    override func tearDown() {
        super.tearDown()
        // Clean up temp directory
        try? FileManager.default.removeItem(atPath: tempDirectory)
    }

    // MARK: - Basic Persistence Tests

    func testPersistAndRecoverEvents() async throws {
        let persistence = EventPersistence(
            storagePath: tempDirectory,
            maxEvents: 1000,
            flushInterval: 0.1
        )

        try await persistence.start()

        // Persist some events
        let event1 = AnalyticsEvent(
            eventType: "test_event_1",
            eventData: ["key": "value1"],
            userId: "user1"
        )
        let event2 = AnalyticsEvent(
            eventType: "test_event_2",
            eventData: ["key": "value2"],
            userId: "user2"
        )

        try await persistence.persist(event1, withId: "evt_1")
        try await persistence.persist(event2, withId: "evt_2")

        // Flush to disk
        try await persistence.flush()

        // Recover events
        let recoveredEvents = try await persistence.recover()

        XCTAssertEqual(recoveredEvents.count, 2)
        XCTAssertEqual(recoveredEvents[0].eventType, "test_event_1")
        XCTAssertEqual(recoveredEvents[1].eventType, "test_event_2")

        await persistence.stop()
    }

    func testMarkEventsAsSent() async throws {
        let persistence = EventPersistence(
            storagePath: tempDirectory,
            maxEvents: 1000,
            flushInterval: 0.1
        )

        try await persistence.start()

        // Persist events
        let event = AnalyticsEvent(
            eventType: "test_event",
            eventData: ["key": "value"]
        )
        try await persistence.persist(event, withId: "evt_1")
        try await persistence.flush()

        // Mark as sent
        try await persistence.markSent(["evt_1"])

        // Recover should return empty (sent events are not recovered)
        let recoveredEvents = try await persistence.recover()
        XCTAssertEqual(recoveredEvents.count, 0)

        await persistence.stop()
    }

    func testRecoverSendingEvents() async throws {
        // Simulates crash during send - events marked as "sending" should be recovered
        let persistence = EventPersistence(
            storagePath: tempDirectory,
            maxEvents: 1000,
            flushInterval: 0.1
        )

        try await persistence.start()

        // Persist and mark as sending
        let event = AnalyticsEvent(
            eventType: "test_event",
            eventData: ["key": "value"]
        )
        try await persistence.persist(event, withId: "evt_1")
        try await persistence.flush()
        try await persistence.markSending(["evt_1"])

        // Recover should return the event (simulates crash recovery)
        let recoveredEvents = try await persistence.recover()
        XCTAssertEqual(recoveredEvents.count, 1)
        XCTAssertEqual(recoveredEvents[0].eventType, "test_event")

        await persistence.stop()
    }

    func testCleanup() async throws {
        let persistence = EventPersistence(
            storagePath: tempDirectory,
            maxEvents: 1000,
            flushInterval: 0.1
        )

        try await persistence.start()

        // Persist events and mark some as sent
        for i in 1...5 {
            let event = AnalyticsEvent(
                eventType: "test_event_\(i)",
                eventData: ["index": i]
            )
            try await persistence.persist(event, withId: "evt_\(i)")
        }
        try await persistence.flush()

        // Mark some as sent
        try await persistence.markSent(["evt_1", "evt_2", "evt_3"])

        // Cleanup should remove sent events
        try await persistence.cleanup()

        // Recover should only return pending events
        let recoveredEvents = try await persistence.recover()
        XCTAssertEqual(recoveredEvents.count, 2)

        await persistence.stop()
    }

    func testMaxEventsLimit() async throws {
        let maxEvents = 5
        let persistence = EventPersistence(
            storagePath: tempDirectory,
            maxEvents: maxEvents,
            flushInterval: 0.1
        )

        try await persistence.start()

        // Persist more events than the limit
        for i in 1...10 {
            let event = AnalyticsEvent(
                eventType: "test_event_\(i)",
                eventData: ["index": i]
            )
            try await persistence.persist(event, withId: "evt_\(i)")
        }
        try await persistence.flush()

        // Cleanup should enforce the limit
        try await persistence.cleanup()

        // Recover should return at most maxEvents
        let recoveredEvents = try await persistence.recover()
        XCTAssertLessThanOrEqual(recoveredEvents.count, maxEvents)

        await persistence.stop()
    }

    // MARK: - Buffer Tests

    func testBufferFlushOnSize() async throws {
        let persistence = EventPersistence(
            config: EventPersistenceConfig(
                storagePath: tempDirectory,
                maxEvents: 1000,
                flushInterval: 60.0, // Long interval
                bufferSize: 3 // Small buffer
            )
        )

        try await persistence.start()

        // Add events up to buffer size
        for i in 1...3 {
            let event = AnalyticsEvent(
                eventType: "test_event_\(i)",
                eventData: ["index": i]
            )
            try await persistence.persist(event, withId: "evt_\(i)")
        }

        // Buffer should have auto-flushed
        let bufferedCount = await persistence.bufferedCount
        XCTAssertEqual(bufferedCount, 0)

        // Events should be recoverable
        let recoveredEvents = try await persistence.recover()
        XCTAssertEqual(recoveredEvents.count, 3)

        await persistence.stop()
    }

    // MARK: - File Locking Tests

    func testConcurrentAccess() async throws {
        let persistence = EventPersistence(
            storagePath: tempDirectory,
            maxEvents: 1000,
            flushInterval: 0.1
        )

        try await persistence.start()

        // Simulate concurrent writes
        await withTaskGroup(of: Void.self) { group in
            for i in 1...20 {
                group.addTask {
                    let event = AnalyticsEvent(
                        eventType: "concurrent_event_\(i)",
                        eventData: ["index": i]
                    )
                    try? await persistence.persist(event, withId: "evt_\(i)")
                }
            }
        }

        try await persistence.flush()

        // All events should be recoverable without corruption
        let recoveredEvents = try await persistence.recover()
        XCTAssertEqual(recoveredEvents.count, 20)

        await persistence.stop()
    }

    // MARK: - Error Handling Tests

    func testRecoverFromEmptyDirectory() async throws {
        let persistence = EventPersistence(
            storagePath: tempDirectory,
            maxEvents: 1000,
            flushInterval: 0.1
        )

        try await persistence.start()

        // Recover from empty storage should return empty array
        let recoveredEvents = try await persistence.recover()
        XCTAssertEqual(recoveredEvents.count, 0)

        await persistence.stop()
    }

    func testPersistWithEventData() async throws {
        let persistence = EventPersistence(
            storagePath: tempDirectory,
            maxEvents: 1000,
            flushInterval: 0.1
        )

        try await persistence.start()

        // Persist event with complex data
        let eventData: [String: Any] = [
            "string": "value",
            "number": 42,
            "bool": true,
            "array": [1, 2, 3],
            "nested": ["key": "nested_value"]
        ]
        let event = AnalyticsEvent(
            eventType: "complex_event",
            eventData: eventData,
            userId: "user123",
            sessionId: "session456"
        )

        try await persistence.persist(event, withId: "evt_complex")
        try await persistence.flush()

        // Recover and verify data
        let recoveredEvents = try await persistence.recover()
        XCTAssertEqual(recoveredEvents.count, 1)

        let recovered = recoveredEvents[0]
        XCTAssertEqual(recovered.eventType, "complex_event")
        XCTAssertEqual(recovered.userId, "user123")
        XCTAssertEqual(recovered.sessionId, "session456")
        XCTAssertNotNil(recovered.eventData)

        if let data = recovered.eventData {
            XCTAssertEqual(data["string"] as? String, "value")
            XCTAssertEqual(data["number"] as? Int, 42)
            XCTAssertEqual(data["bool"] as? Bool, true)
        }

        await persistence.stop()
    }

    // MARK: - Integration with EventQueue Tests

    func testEventQueueWithPersistence() async throws {
        var sentEvents: [[String: Any]] = []

        let config = EventQueueConfig(
            batchSize: 5,
            flushInterval: 60,
            persistEvents: true,
            eventStoragePath: tempDirectory,
            maxPersistedEvents: 1000,
            persistenceFlushInterval: 0.1
        )

        let queue = EventQueue(config: config) { events in
            sentEvents = events
        }

        await queue.start()

        // Add events
        for i in 1...5 {
            await queue.enqueue(["type": "test_event_\(i)"])
        }

        // Wait for flush
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(sentEvents.count, 5)

        await queue.stop()
    }
}
