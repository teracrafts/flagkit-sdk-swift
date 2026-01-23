import XCTest
@testable import FlagKit

final class CircuitBreakerTests: XCTestCase {
    func testInitialState() async {
        let breaker = CircuitBreaker(failureThreshold: 3, resetTimeout: 0.2)

        let isClosed = await breaker.isClosed

        XCTAssertTrue(isClosed)
    }

    func testAllowRequestWhenClosed() async {
        let breaker = CircuitBreaker(failureThreshold: 3, resetTimeout: 0.2)

        let allowed = await breaker.allowRequest()

        XCTAssertTrue(allowed)
    }

    func testOpensAfterThreshold() async {
        let breaker = CircuitBreaker(failureThreshold: 3, resetTimeout: 0.2)

        await breaker.recordFailure()
        await breaker.recordFailure()
        await breaker.recordFailure()

        let isOpen = await breaker.isOpen

        XCTAssertTrue(isOpen)
    }

    func testDoesNotOpenBeforeThreshold() async {
        let breaker = CircuitBreaker(failureThreshold: 3, resetTimeout: 0.2)

        await breaker.recordFailure()
        await breaker.recordFailure()

        let isOpen = await breaker.isOpen
        let isClosed = await breaker.isClosed

        XCTAssertFalse(isOpen)
        XCTAssertTrue(isClosed)
    }

    func testRecordSuccess() async {
        let breaker = CircuitBreaker(failureThreshold: 3, resetTimeout: 0.2)

        await breaker.recordFailure()
        await breaker.recordFailure()
        await breaker.recordSuccess()

        let failureCount = await breaker.getFailureCount()

        XCTAssertEqual(failureCount, 0)
    }

    func testReset() async {
        let breaker = CircuitBreaker(failureThreshold: 3, resetTimeout: 0.2)

        await breaker.recordFailure()
        await breaker.recordFailure()
        await breaker.recordFailure()
        await breaker.reset()

        let isClosed = await breaker.isClosed
        let failureCount = await breaker.getFailureCount()

        XCTAssertTrue(isClosed)
        XCTAssertEqual(failureCount, 0)
    }

    func testHalfOpenAfterTimeout() async throws {
        let breaker = CircuitBreaker(failureThreshold: 3, resetTimeout: 0.1)

        await breaker.recordFailure()
        await breaker.recordFailure()
        await breaker.recordFailure()

        try await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds

        let isHalfOpen = await breaker.isHalfOpen

        XCTAssertTrue(isHalfOpen)
    }

    func testClosesFromHalfOpenOnSuccess() async throws {
        let breaker = CircuitBreaker(failureThreshold: 3, resetTimeout: 0.1)

        await breaker.recordFailure()
        await breaker.recordFailure()
        await breaker.recordFailure()

        try await Task.sleep(nanoseconds: 150_000_000)

        _ = await breaker.isHalfOpen // Trigger transition
        await breaker.recordSuccess()

        let isClosed = await breaker.isClosed

        XCTAssertTrue(isClosed)
    }

    func testOpensFromHalfOpenOnFailure() async throws {
        let breaker = CircuitBreaker(failureThreshold: 3, resetTimeout: 0.1)

        await breaker.recordFailure()
        await breaker.recordFailure()
        await breaker.recordFailure()

        try await Task.sleep(nanoseconds: 150_000_000)

        _ = await breaker.isHalfOpen
        await breaker.recordFailure()

        let isOpen = await breaker.isOpen

        XCTAssertTrue(isOpen)
    }

    func testExecuteSuccess() async throws {
        let breaker = CircuitBreaker(failureThreshold: 3, resetTimeout: 0.2)

        let result = try await breaker.execute {
            return "success"
        }

        XCTAssertEqual(result, "success")
    }

    func testExecuteFailure() async {
        let breaker = CircuitBreaker(failureThreshold: 3, resetTimeout: 0.2)

        do {
            _ = try await breaker.execute {
                throw NSError(domain: "test", code: 1)
            }
            XCTFail("Expected error")
        } catch {
            let failureCount = await breaker.getFailureCount()
            XCTAssertEqual(failureCount, 1)
        }
    }

    func testExecuteWhenOpen() async throws {
        let breaker = CircuitBreaker(failureThreshold: 3, resetTimeout: 30)

        await breaker.recordFailure()
        await breaker.recordFailure()
        await breaker.recordFailure()

        do {
            _ = try await breaker.execute {
                return "success"
            }
            XCTFail("Expected error")
        } catch let error as FlagKitError {
            XCTAssertEqual(error.code, .circuitOpen)
        }
    }
}
