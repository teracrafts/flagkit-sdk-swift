import XCTest
@testable import FlagKit

final class EventQueueTests: XCTestCase {
    func testEnqueueEvent() async {
        var flushedEvents: [[String: Any]] = []

        let queue = EventQueue(
            batchSize: 10,
            flushInterval: 60,
            onFlush: { events in
                flushedEvents = events
            }
        )

        let event: [String: Any] = [
            "type": "test_event",
            "timestamp": "2024-01-01T00:00:00Z"
        ]

        await queue.enqueue(event)

        let count = await queue.count
        XCTAssertEqual(count, 1)
    }

    func testFlushWhenBatchSizeReached() async throws {
        var flushCount = 0
        var lastFlushedEvents: [[String: Any]] = []

        let queue = EventQueue(
            batchSize: 3,
            flushInterval: 60,
            onFlush: { events in
                flushCount += 1
                lastFlushedEvents = events
            }
        )

        await queue.start()

        for i in 1...3 {
            await queue.enqueue(["type": "event_\(i)"])
        }

        // Give time for flush to complete
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(flushCount, 1)
        XCTAssertEqual(lastFlushedEvents.count, 3)

        await queue.stop()
    }

    func testManualFlush() async throws {
        var flushedEvents: [[String: Any]] = []

        let queue = EventQueue(
            batchSize: 100,
            flushInterval: 60,
            onFlush: { events in
                flushedEvents = events
            }
        )

        await queue.enqueue(["type": "event_1"])
        await queue.enqueue(["type": "event_2"])

        await queue.flush()

        XCTAssertEqual(flushedEvents.count, 2)

        let pending = await queue.count
        XCTAssertEqual(pending, 0)
    }

    func testStopFlushesRemaining() async throws {
        var flushedEvents: [[String: Any]] = []

        let queue = EventQueue(
            batchSize: 100,
            flushInterval: 60,
            onFlush: { events in
                flushedEvents = events
            }
        )

        await queue.start()
        await queue.enqueue(["type": "event_1"])
        await queue.stop()

        XCTAssertEqual(flushedEvents.count, 1)
    }
}
