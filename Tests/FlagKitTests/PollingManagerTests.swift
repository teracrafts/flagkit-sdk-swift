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

    func testPollsAtInterval() async throws {
        var updateCount = 0

        let manager = PollingManager(
            interval: 0.05,
            onUpdate: { _ in
                updateCount += 1
            }
        )

        await manager.start()

        // Wait for a few polls
        try await Task.sleep(nanoseconds: 200_000_000)

        await manager.stop()

        // Should have polled at least twice
        XCTAssertGreaterThanOrEqual(updateCount, 2)
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
            interval: 0.05,
            onUpdate: { lastUpdate in
                receivedDates.append(lastUpdate)
            }
        )

        await manager.start()

        try await Task.sleep(nanoseconds: 150_000_000)

        await manager.stop()

        // First call should have nil, subsequent should have dates
        XCTAssertGreaterThanOrEqual(receivedDates.count, 2)
        XCTAssertNil(receivedDates.first!)

        if receivedDates.count > 1 {
            XCTAssertNotNil(receivedDates[1])
        }
    }
}
