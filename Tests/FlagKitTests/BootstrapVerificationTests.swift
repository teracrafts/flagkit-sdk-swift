import XCTest
@testable import FlagKit

final class BootstrapVerificationTests: XCTestCase {

    // MARK: - BootstrapConfig Tests

    func testBootstrapConfig_InitWithFlags() {
        let flags: [String: Any] = ["flags": [["key": "test-flag", "value": true]]]
        let config = BootstrapConfig(flags: flags)

        XCTAssertNotNil(config.flags["flags"])
        XCTAssertNil(config.signature)
        XCTAssertNil(config.timestamp)
    }

    func testBootstrapConfig_InitWithSignatureAndTimestamp() {
        let flags: [String: Any] = ["flags": [["key": "test-flag", "value": true]]]
        let signature = "abc123"
        let timestamp: Int64 = 1700000000000

        let config = BootstrapConfig(flags: flags, signature: signature, timestamp: timestamp)

        XCTAssertEqual(config.signature, signature)
        XCTAssertEqual(config.timestamp, timestamp)
    }

    // MARK: - BootstrapVerificationConfig Tests

    func testBootstrapVerificationConfig_DefaultValues() {
        let config = BootstrapVerificationConfig()

        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.maxAge, 86_400_000) // 24 hours
        XCTAssertEqual(config.onFailure, .warn)
    }

    func testBootstrapVerificationConfig_CustomValues() {
        let config = BootstrapVerificationConfig(
            enabled: false,
            maxAge: 3_600_000, // 1 hour
            onFailure: .error
        )

        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.maxAge, 3_600_000)
        XCTAssertEqual(config.onFailure, .error)
    }

    // MARK: - canonicalizeObject Tests

    func testCanonicalizeObject_ProducesConsistentOutput() {
        let obj1: [String: Any] = ["b": 2, "a": 1]
        let obj2: [String: Any] = ["a": 1, "b": 2]

        let canonical1 = canonicalizeObject(obj1)
        let canonical2 = canonicalizeObject(obj2)

        XCTAssertEqual(canonical1, canonical2)
    }

    func testCanonicalizeObject_HandlesNestedObjects() {
        let obj: [String: Any] = [
            "outer": [
                "inner": "value",
                "another": 123
            ] as [String: Any]
        ]

        let canonical = canonicalizeObject(obj)

        XCTAssertFalse(canonical.isEmpty)
        XCTAssertTrue(canonical.contains("outer"))
        XCTAssertTrue(canonical.contains("inner"))
    }

    func testCanonicalizeObject_HandlesArrays() {
        let obj: [String: Any] = [
            "flags": [
                ["key": "flag-1", "value": true],
                ["key": "flag-2", "value": false]
            ] as [[String: Any]]
        ]

        let canonical = canonicalizeObject(obj)

        XCTAssertFalse(canonical.isEmpty)
        XCTAssertTrue(canonical.contains("flag-1"))
        XCTAssertTrue(canonical.contains("flag-2"))
    }

    // MARK: - constantTimeCompare Tests

    func testConstantTimeCompare_EqualStrings() {
        XCTAssertTrue(constantTimeCompare("hello", "hello"))
        XCTAssertTrue(constantTimeCompare("", ""))
        XCTAssertTrue(constantTimeCompare("a1b2c3", "a1b2c3"))
    }

    func testConstantTimeCompare_DifferentStrings() {
        XCTAssertFalse(constantTimeCompare("hello", "world"))
        XCTAssertFalse(constantTimeCompare("hello", "Hello"))
        XCTAssertFalse(constantTimeCompare("abc", "abd"))
    }

    func testConstantTimeCompare_DifferentLengths() {
        XCTAssertFalse(constantTimeCompare("hello", "hell"))
        XCTAssertFalse(constantTimeCompare("hi", "hello"))
        XCTAssertFalse(constantTimeCompare("", "a"))
    }

    // MARK: - verifyBootstrapSignature Tests

    func testVerifyBootstrapSignature_ValidSignatureAccepted() {
        let apiKey = "sdk_test123456"
        let flags: [String: Any] = ["flags": [["key": "test-flag", "value": true]]]
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)

        // Create signed bootstrap
        let signedBootstrap = createSignedBootstrap(flags: flags, apiKey: apiKey, timestamp: timestamp)

        let config = BootstrapVerificationConfig(enabled: true, maxAge: 86_400_000, onFailure: .error)
        let result = verifyBootstrapSignature(bootstrap: signedBootstrap, apiKey: apiKey, config: config)

        XCTAssertTrue(result.valid)
        XCTAssertNil(result.error)
    }

    func testVerifyBootstrapSignature_InvalidSignatureRejected() {
        let apiKey = "sdk_test123456"
        let flags: [String: Any] = ["flags": [["key": "test-flag", "value": true]]]
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)

        // Create bootstrap with invalid signature
        let invalidBootstrap = BootstrapConfig(
            flags: flags,
            signature: "invalid_signature_that_should_not_match",
            timestamp: timestamp
        )

        let config = BootstrapVerificationConfig(enabled: true, maxAge: 86_400_000, onFailure: .error)
        let result = verifyBootstrapSignature(bootstrap: invalidBootstrap, apiKey: apiKey, config: config)

        XCTAssertFalse(result.valid)
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error?.contains("Invalid bootstrap signature") ?? false)
    }

    func testVerifyBootstrapSignature_WrongKeyRejected() {
        let apiKey = "sdk_test123456"
        let wrongKey = "sdk_different_key"
        let flags: [String: Any] = ["flags": [["key": "test-flag", "value": true]]]

        // Create signed bootstrap with original key
        let signedBootstrap = createSignedBootstrap(flags: flags, apiKey: apiKey)

        // Try to verify with different key
        let config = BootstrapVerificationConfig(enabled: true, maxAge: 86_400_000, onFailure: .error)
        let result = verifyBootstrapSignature(bootstrap: signedBootstrap, apiKey: wrongKey, config: config)

        XCTAssertFalse(result.valid)
    }

    func testVerifyBootstrapSignature_ExpiredTimestampRejected() {
        let apiKey = "sdk_test123456"
        let flags: [String: Any] = ["flags": [["key": "test-flag", "value": true]]]
        // Create timestamp 2 days ago
        let oldTimestamp = Int64(Date().timeIntervalSince1970 * 1000) - (2 * 86_400_000)

        let signedBootstrap = createSignedBootstrap(flags: flags, apiKey: apiKey, timestamp: oldTimestamp)

        // Max age of 24 hours
        let config = BootstrapVerificationConfig(enabled: true, maxAge: 86_400_000, onFailure: .error)
        let result = verifyBootstrapSignature(bootstrap: signedBootstrap, apiKey: apiKey, config: config)

        XCTAssertFalse(result.valid)
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error?.contains("expired") ?? false)
    }

    func testVerifyBootstrapSignature_FutureTimestampRejected() {
        let apiKey = "sdk_test123456"
        let flags: [String: Any] = ["flags": [["key": "test-flag", "value": true]]]
        // Create timestamp 2 hours in the future (beyond allowed clock skew)
        let futureTimestamp = Int64(Date().timeIntervalSince1970 * 1000) + (2 * 3_600_000)

        let signedBootstrap = createSignedBootstrap(flags: flags, apiKey: apiKey, timestamp: futureTimestamp)

        let config = BootstrapVerificationConfig(enabled: true, maxAge: 86_400_000, onFailure: .error)
        let result = verifyBootstrapSignature(bootstrap: signedBootstrap, apiKey: apiKey, config: config)

        XCTAssertFalse(result.valid)
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error?.contains("future") ?? false)
    }

    func testVerifyBootstrapSignature_NoSignatureFailsWhenRequired() {
        let apiKey = "sdk_test123456"
        let flags: [String: Any] = ["flags": [["key": "test-flag", "value": true]]]

        // Bootstrap without signature
        let unsignedBootstrap = BootstrapConfig(flags: flags, signature: nil, timestamp: nil)

        let config = BootstrapVerificationConfig(enabled: true, maxAge: 86_400_000, onFailure: .error)
        let result = verifyBootstrapSignature(bootstrap: unsignedBootstrap, apiKey: apiKey, config: config)

        XCTAssertFalse(result.valid)
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error?.contains("No signature") ?? false)
    }

    func testVerifyBootstrapSignature_DisabledVerificationAlwaysSucceeds() {
        let apiKey = "sdk_test123456"
        let flags: [String: Any] = ["flags": [["key": "test-flag", "value": true]]]

        // Bootstrap with invalid signature
        let invalidBootstrap = BootstrapConfig(
            flags: flags,
            signature: "invalid",
            timestamp: nil
        )

        // Verification disabled
        let config = BootstrapVerificationConfig(enabled: false, maxAge: 86_400_000, onFailure: .error)
        let result = verifyBootstrapSignature(bootstrap: invalidBootstrap, apiKey: apiKey, config: config)

        XCTAssertTrue(result.valid)
        XCTAssertNil(result.error)
    }

    // MARK: - Legacy Format Tests

    func testLegacyBootstrapFormat_WorksWithoutVerification() {
        // Legacy format: just flags without signature
        let legacyBootstrap: [String: Any] = [
            "flags": [
                ["key": "feature-1", "value": true, "enabled": true, "version": 1],
                ["key": "feature-2", "value": "variant-a", "enabled": true, "version": 2]
            ]
        ]

        // With verification disabled, legacy format should work
        let config = BootstrapVerificationConfig(enabled: false)

        // Create a BootstrapConfig from legacy format
        let bootstrapConfig = BootstrapConfig(flags: legacyBootstrap, signature: nil, timestamp: nil)

        let result = verifyBootstrapSignature(
            bootstrap: bootstrapConfig,
            apiKey: "sdk_test123",
            config: config
        )

        XCTAssertTrue(result.valid)
    }

    // MARK: - createSignedBootstrap Tests

    func testCreateSignedBootstrap_CreatesValidConfig() {
        let flags: [String: Any] = ["flags": [["key": "test-flag", "value": true]]]
        let apiKey = "sdk_test123456"
        let timestamp: Int64 = 1700000000000

        let signedBootstrap = createSignedBootstrap(flags: flags, apiKey: apiKey, timestamp: timestamp)

        XCTAssertNotNil(signedBootstrap.signature)
        XCTAssertEqual(signedBootstrap.timestamp, timestamp)
        XCTAssertEqual(signedBootstrap.signature?.count, 64) // SHA256 hex = 64 chars
    }

    func testCreateSignedBootstrap_UsesCurrentTimestampByDefault() {
        let flags: [String: Any] = ["flags": [["key": "test-flag", "value": true]]]
        let apiKey = "sdk_test123456"
        let beforeTime = Int64(Date().timeIntervalSince1970 * 1000)

        let signedBootstrap = createSignedBootstrap(flags: flags, apiKey: apiKey)

        let afterTime = Int64(Date().timeIntervalSince1970 * 1000)

        XCTAssertNotNil(signedBootstrap.timestamp)
        XCTAssertGreaterThanOrEqual(signedBootstrap.timestamp!, beforeTime)
        XCTAssertLessThanOrEqual(signedBootstrap.timestamp!, afterTime)
    }

    func testCreateSignedBootstrap_RoundTripsWithVerification() {
        let flags: [String: Any] = ["flags": [["key": "test-flag", "value": true]]]
        let apiKey = "sdk_test123456"

        // Create signed bootstrap
        let signedBootstrap = createSignedBootstrap(flags: flags, apiKey: apiKey)

        // Verify it
        let config = BootstrapVerificationConfig(enabled: true, maxAge: 86_400_000, onFailure: .error)
        let result = verifyBootstrapSignature(bootstrap: signedBootstrap, apiKey: apiKey, config: config)

        XCTAssertTrue(result.valid)
    }

    // MARK: - onFailure Behavior Tests

    func testBootstrapVerificationFailureAction_WarnValue() {
        let action = BootstrapVerificationFailureAction.warn
        XCTAssertEqual(action.rawValue, "warn")
    }

    func testBootstrapVerificationFailureAction_ErrorValue() {
        let action = BootstrapVerificationFailureAction.error
        XCTAssertEqual(action.rawValue, "error")
    }

    func testBootstrapVerificationFailureAction_IgnoreValue() {
        let action = BootstrapVerificationFailureAction.ignore
        XCTAssertEqual(action.rawValue, "ignore")
    }

    // MARK: - FlagKitOptions Integration Tests

    func testFlagKitOptions_BootstrapVerificationDefault() {
        let options = FlagKitOptions(apiKey: "sdk_test123")

        // Default is disabled
        XCTAssertFalse(options.bootstrapVerification.enabled)
    }

    func testFlagKitOptions_BootstrapVerificationCustom() {
        let verificationConfig = BootstrapVerificationConfig(
            enabled: true,
            maxAge: 3_600_000,
            onFailure: .error
        )

        let options = FlagKitOptions(
            apiKey: "sdk_test123",
            bootstrapVerification: verificationConfig
        )

        XCTAssertTrue(options.bootstrapVerification.enabled)
        XCTAssertEqual(options.bootstrapVerification.maxAge, 3_600_000)
        XCTAssertEqual(options.bootstrapVerification.onFailure, .error)
    }

    func testFlagKitOptions_Builder_BootstrapVerification() {
        let verificationConfig = BootstrapVerificationConfig(
            enabled: true,
            maxAge: 7_200_000,
            onFailure: .warn
        )

        let options = FlagKitOptions.Builder(apiKey: "sdk_test123")
            .bootstrapVerification(verificationConfig)
            .build()

        XCTAssertTrue(options.bootstrapVerification.enabled)
        XCTAssertEqual(options.bootstrapVerification.maxAge, 7_200_000)
        XCTAssertEqual(options.bootstrapVerification.onFailure, .warn)
    }

    // MARK: - SecurityError Tests

    func testSecurityError_BootstrapVerificationFailed() {
        let error = SecurityError.bootstrapVerificationFailed("test reason")
        XCTAssertTrue(error.errorDescription?.contains("test reason") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Bootstrap verification failed") ?? false)
    }

    // MARK: - BootstrapVerificationResult Tests

    func testBootstrapVerificationResult_Success() {
        let result = BootstrapVerificationResult.success

        XCTAssertTrue(result.valid)
        XCTAssertNil(result.error)
    }

    func testBootstrapVerificationResult_Failure() {
        let result = BootstrapVerificationResult.failure("test error")

        XCTAssertFalse(result.valid)
        XCTAssertEqual(result.error, "test error")
    }

    // MARK: - Edge Case Tests

    func testVerifyBootstrapSignature_EmptyFlags() {
        let apiKey = "sdk_test123456"
        let flags: [String: Any] = [:]

        let signedBootstrap = createSignedBootstrap(flags: flags, apiKey: apiKey)
        let config = BootstrapVerificationConfig(enabled: true, maxAge: 86_400_000, onFailure: .error)
        let result = verifyBootstrapSignature(bootstrap: signedBootstrap, apiKey: apiKey, config: config)

        XCTAssertTrue(result.valid)
    }

    func testVerifyBootstrapSignature_ComplexFlags() {
        let apiKey = "sdk_test123456"
        let flags: [String: Any] = [
            "flags": [
                [
                    "key": "complex-flag",
                    "value": [
                        "nested": [
                            "deep": "value",
                            "number": 123,
                            "boolean": true,
                            "array": [1, 2, 3]
                        ] as [String: Any]
                    ] as [String: Any],
                    "enabled": true,
                    "version": 5,
                    "metadata": [
                        "created": "2024-01-01",
                        "tags": ["production", "beta"]
                    ] as [String: Any]
                ] as [String: Any]
            ]
        ]

        let signedBootstrap = createSignedBootstrap(flags: flags, apiKey: apiKey)
        let config = BootstrapVerificationConfig(enabled: true, maxAge: 86_400_000, onFailure: .error)
        let result = verifyBootstrapSignature(bootstrap: signedBootstrap, apiKey: apiKey, config: config)

        XCTAssertTrue(result.valid)
    }

    func testVerifyBootstrapSignature_TamperedDataRejected() {
        let apiKey = "sdk_test123456"
        let originalFlags: [String: Any] = ["flags": [["key": "test-flag", "value": true]]]

        // Create signed bootstrap
        let signedBootstrap = createSignedBootstrap(flags: originalFlags, apiKey: apiKey)

        // Tamper with the data
        let tamperedFlags: [String: Any] = ["flags": [["key": "test-flag", "value": false]]]
        let tamperedBootstrap = BootstrapConfig(
            flags: tamperedFlags,
            signature: signedBootstrap.signature,
            timestamp: signedBootstrap.timestamp
        )

        let config = BootstrapVerificationConfig(enabled: true, maxAge: 86_400_000, onFailure: .error)
        let result = verifyBootstrapSignature(bootstrap: tamperedBootstrap, apiKey: apiKey, config: config)

        XCTAssertFalse(result.valid)
    }
}
