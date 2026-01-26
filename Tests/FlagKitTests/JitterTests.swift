import XCTest
@testable import FlagKit

final class JitterTests: XCTestCase {
    // MARK: - EvaluationJitterConfig Tests

    func testDefaultJitterConfig() {
        let config = EvaluationJitterConfig()

        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.minMs, 5)
        XCTAssertEqual(config.maxMs, 15)
    }

    func testCustomJitterConfig() {
        let config = EvaluationJitterConfig(enabled: true, minMs: 10, maxMs: 50)

        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.minMs, 10)
        XCTAssertEqual(config.maxMs, 50)
    }

    func testJitterConfigInOptions() {
        let jitterConfig = EvaluationJitterConfig(enabled: true, minMs: 5, maxMs: 20)
        let options = FlagKitOptions(
            apiKey: "sdk_test_key",
            evaluationJitter: jitterConfig
        )

        XCTAssertTrue(options.evaluationJitter.enabled)
        XCTAssertEqual(options.evaluationJitter.minMs, 5)
        XCTAssertEqual(options.evaluationJitter.maxMs, 20)
    }

    func testJitterConfigInBuilder() {
        let jitterConfig = EvaluationJitterConfig(enabled: true, minMs: 8, maxMs: 25)
        let options = FlagKitOptions.Builder(apiKey: "sdk_test_key")
            .evaluationJitter(jitterConfig)
            .build()

        XCTAssertTrue(options.evaluationJitter.enabled)
        XCTAssertEqual(options.evaluationJitter.minMs, 8)
        XCTAssertEqual(options.evaluationJitter.maxMs, 25)
    }

    func testDefaultOptionsHasJitterDisabled() {
        let options = FlagKitOptions(apiKey: "sdk_test_key")

        XCTAssertFalse(options.evaluationJitter.enabled)
    }

    func testBuilderDefaultHasJitterDisabled() {
        let options = FlagKitOptions.Builder(apiKey: "sdk_test_key")
            .build()

        XCTAssertFalse(options.evaluationJitter.enabled)
        XCTAssertEqual(options.evaluationJitter.minMs, 5)
        XCTAssertEqual(options.evaluationJitter.maxMs, 15)
    }

    func testJitterConfigSendable() {
        // Verify EvaluationJitterConfig conforms to Sendable
        let config = EvaluationJitterConfig(enabled: true, minMs: 5, maxMs: 15)

        // This test compiles only if EvaluationJitterConfig is Sendable
        Task {
            let _ = config
        }
    }

    // MARK: - Jitter Timing Tests

    func testJitterNotAppliedWhenDisabled() async {
        // Create options with jitter disabled (default) and use bootstrap to avoid network calls
        let bootstrapData: [String: Any] = [
            "flags": [
                [
                    "key": "test_flag",
                    "value": ["type": "boolean", "value": true],
                    "enabled": true,
                    "version": 1
                ]
            ]
        ]
        let options = FlagKitOptions(
            apiKey: "sdk_test_key",
            cacheEnabled: true,
            eventsEnabled: false,
            bootstrap: bootstrapData
        )

        let client = FlagKitClient(options: options)
        try? await client.initialize()

        // Warm up the cache with the first call
        _ = await client.evaluate(key: "test_flag", defaultValue: .bool(false))

        // Measure time for cached evaluation without jitter
        let startTime = Date()
        _ = await client.evaluate(key: "test_flag", defaultValue: .bool(false))
        let elapsed = Date().timeIntervalSince(startTime)

        // Without jitter, cached evaluation should be very fast (less than 50ms)
        XCTAssertLessThan(elapsed, 0.05, "Cached evaluation without jitter should be fast")

        await client.close()
    }

    func testJitterAppliedWhenEnabled() async {
        // Create options with jitter enabled and use bootstrap to avoid network calls
        let bootstrapData: [String: Any] = [
            "flags": [
                [
                    "key": "test_flag",
                    "value": ["type": "boolean", "value": true],
                    "enabled": true,
                    "version": 1
                ]
            ]
        ]
        let jitterConfig = EvaluationJitterConfig(enabled: true, minMs: 50, maxMs: 100)
        let options = FlagKitOptions(
            apiKey: "sdk_test_key",
            cacheEnabled: true,
            eventsEnabled: false,
            bootstrap: bootstrapData,
            evaluationJitter: jitterConfig
        )

        let client = FlagKitClient(options: options)
        try? await client.initialize()

        // Warm up the cache
        _ = await client.evaluate(key: "test_flag", defaultValue: .bool(false))

        // Measure time for cached evaluation with jitter
        let startTime = Date()
        _ = await client.evaluate(key: "test_flag", defaultValue: .bool(false))
        let elapsed = Date().timeIntervalSince(startTime)

        // With jitter enabled (min 50ms), evaluation should take at least ~50ms
        XCTAssertGreaterThanOrEqual(elapsed, 0.04, "Evaluation with jitter should have delay")

        await client.close()
    }

    func testJitterTimingWithinRange() async {
        // Create options with specific jitter range and use bootstrap
        let minMs = 30
        let maxMs = 60
        let bootstrapData: [String: Any] = [
            "flags": [
                [
                    "key": "test_flag",
                    "value": ["type": "boolean", "value": true],
                    "enabled": true,
                    "version": 1
                ]
            ]
        ]
        let jitterConfig = EvaluationJitterConfig(enabled: true, minMs: minMs, maxMs: maxMs)
        let options = FlagKitOptions(
            apiKey: "sdk_test_key",
            cacheEnabled: true,
            eventsEnabled: false,
            bootstrap: bootstrapData,
            evaluationJitter: jitterConfig
        )

        let client = FlagKitClient(options: options)
        try? await client.initialize()

        // Warm up the cache
        _ = await client.evaluate(key: "test_flag", defaultValue: .bool(false))

        // Run multiple evaluations to verify timing is within range
        for _ in 0..<3 {
            let startTime = Date()
            _ = await client.evaluate(key: "test_flag", defaultValue: .bool(false))
            let elapsedMs = Date().timeIntervalSince(startTime) * 1000

            // Allow margin for execution overhead
            // Jitter should add at least minMs delay (with some tolerance)
            XCTAssertGreaterThanOrEqual(elapsedMs, Double(minMs) * 0.8, "Jitter should add at least minimum delay")
            // Should not exceed maxMs by too much (add 50ms for overhead)
            XCTAssertLessThan(elapsedMs, Double(maxMs) + 50, "Jitter should not exceed maximum by much")
        }

        await client.close()
    }
}
