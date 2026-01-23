import XCTest
@testable import FlagKit

final class OptionsTests: XCTestCase {
    func testDefaultValues() {
        let options = FlagKitOptions(apiKey: "sdk_test_key")

        XCTAssertEqual(options.apiKey, "sdk_test_key")
        XCTAssertEqual(options.pollingInterval, 30)
        XCTAssertEqual(options.cacheTTL, 300)
        XCTAssertEqual(options.maxCacheSize, 1000)
        XCTAssertTrue(options.cacheEnabled)
        XCTAssertEqual(options.eventBatchSize, 10)
        XCTAssertEqual(options.eventFlushInterval, 30)
        XCTAssertTrue(options.eventsEnabled)
        XCTAssertEqual(options.timeout, 10)
        XCTAssertEqual(options.retryAttempts, 3)
        XCTAssertEqual(options.circuitBreakerThreshold, 5)
        XCTAssertEqual(options.circuitBreakerResetTimeout, 30)
        XCTAssertFalse(options.isLocal)
    }

    func testCustomValues() {
        let options = FlagKitOptions(
            apiKey: "sdk_custom_key",
            pollingInterval: 60,
            cacheTTL: 600,
            cacheEnabled: false
        )

        XCTAssertEqual(options.pollingInterval, 60)
        XCTAssertEqual(options.cacheTTL, 600)
        XCTAssertFalse(options.cacheEnabled)
    }

    func testValidateEmptyApiKey() {
        let options = FlagKitOptions(apiKey: "")

        XCTAssertThrowsError(try options.validate()) { error in
            guard let flagKitError = error as? FlagKitError else {
                XCTFail("Expected FlagKitError")
                return
            }
            XCTAssertEqual(flagKitError.code, .configInvalidApiKey)
        }
    }

    func testValidateInvalidApiKeyPrefix() {
        let options = FlagKitOptions(apiKey: "invalid_key")

        XCTAssertThrowsError(try options.validate()) { error in
            guard let flagKitError = error as? FlagKitError else {
                XCTFail("Expected FlagKitError")
                return
            }
            XCTAssertEqual(flagKitError.code, .configInvalidApiKey)
            XCTAssertTrue(flagKitError.message.contains("Invalid API key format"))
        }
    }

    func testValidateValidApiKeyPrefixes() {
        let prefixes = ["sdk_", "srv_", "cli_"]

        for prefix in prefixes {
            let options = FlagKitOptions(apiKey: "\(prefix)test_key")
            XCTAssertNoThrow(try options.validate())
        }
    }

    func testValidateNonPositivePollingInterval() {
        let options = FlagKitOptions(apiKey: "sdk_test", pollingInterval: 0)

        XCTAssertThrowsError(try options.validate()) { error in
            guard let flagKitError = error as? FlagKitError else {
                XCTFail("Expected FlagKitError")
                return
            }
            XCTAssertEqual(flagKitError.code, .configInvalidPollingInterval)
        }
    }

    func testValidateNonPositiveCacheTTL() {
        let options = FlagKitOptions(apiKey: "sdk_test", cacheTTL: -1)

        XCTAssertThrowsError(try options.validate()) { error in
            guard let flagKitError = error as? FlagKitError else {
                XCTFail("Expected FlagKitError")
                return
            }
            XCTAssertEqual(flagKitError.code, .configInvalidCacheTtl)
        }
    }

    func testBuilder() {
        let options = FlagKitOptions.Builder(apiKey: "sdk_test")
            .pollingInterval(60)
            .cacheTTL(600)
            .cacheEnabled(false)
            .eventsEnabled(false)
            .build()

        XCTAssertEqual(options.apiKey, "sdk_test")
        XCTAssertEqual(options.pollingInterval, 60)
        XCTAssertEqual(options.cacheTTL, 600)
        XCTAssertFalse(options.cacheEnabled)
        XCTAssertFalse(options.eventsEnabled)
    }

    func testIsLocalOption() {
        let options = FlagKitOptions(apiKey: "sdk_test_key", isLocal: true)

        XCTAssertTrue(options.isLocal)
    }

    func testIsLocalBuilder() {
        let options = FlagKitOptions.Builder(apiKey: "sdk_test")
            .isLocal(true)
            .build()

        XCTAssertTrue(options.isLocal)
    }

    func testIsLocalDefaultFalse() {
        let options = FlagKitOptions.Builder(apiKey: "sdk_test")
            .build()

        XCTAssertFalse(options.isLocal)
    }
}
