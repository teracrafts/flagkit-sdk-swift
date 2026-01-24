import XCTest
@testable import FlagKit

final class PollingManagerTests: XCTestCase {
    func testStartAndStop() async {
        var updateCount = 0

        let manager = PollingManager(
            interval: 0.1,
            onUpdate: { _ in
                updateCount += 1
            }
        )

        await manager.start()

        let isRunning = await manager.running
        XCTAssertTrue(isRunning)

        await manager.stop()

        let isStoppedAfter = await manager.running
        XCTAssertFalse(isStoppedAfter)
    }

    func testManualPoll() async throws {
        var updateCount = 0

        let manager = PollingManager(
            interval: 60, // Long interval since we're polling manually
            onUpdate: { _ in
                updateCount += 1
            }
        )

        // Manually trigger polls
        let result1 = await manager.pollNow()
        XCTAssertTrue(result1, "First poll should succeed")

        let result2 = await manager.pollNow()
        XCTAssertTrue(result2, "Second poll should succeed")

        XCTAssertEqual(updateCount, 2, "Should have polled twice")
    }

    func testDoesNotPollWhenStopped() async throws {
        var updateCount = 0

        let manager = PollingManager(
            interval: 0.05,
            onUpdate: { _ in
                updateCount += 1
            }
        )

        // Don't start, just wait
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(updateCount, 0)
    }

    func testPassesLastUpdateTime() async throws {
        var receivedDates: [Date?] = []

        let manager = PollingManager(
            interval: 60, // Long interval since we're polling manually
            onUpdate: { lastUpdate in
                receivedDates.append(lastUpdate)
            }
        )

        // First poll should have nil lastUpdateTime
        _ = await manager.pollNow()

        // Second poll should have a non-nil lastUpdateTime
        _ = await manager.pollNow()

        XCTAssertEqual(receivedDates.count, 2)
        XCTAssertNil(receivedDates[0], "First update should have nil lastUpdateTime")
        XCTAssertNotNil(receivedDates[1], "Second update should have non-nil lastUpdateTime")
    }
}
