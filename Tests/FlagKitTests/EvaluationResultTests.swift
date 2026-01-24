import XCTest
@testable import FlagKit

final class EvaluationResultTests: XCTestCase {
    func testDefaultResult() {
        let result = EvaluationResult.defaultResult(
            key: "test-flag",
            defaultValue: .bool(false),
            reason: .flagNotFound
        )

        XCTAssertEqual(result.flagKey, "test-flag")
        XCTAssertEqual(result.value, .bool(false))
        XCTAssertFalse(result.enabled)
        XCTAssertEqual(result.reason, .flagNotFound)
        XCTAssertEqual(result.version, 0)
    }

    func testBoolValueTrue() {
        let result = EvaluationResult(
            flagKey: "bool-flag",
            value: .bool(true),
            enabled: true,
            reason: .cached,
            version: 1
        )

        XCTAssertTrue(result.boolValue)
    }

    func testBoolValueFalse() {
        let result = EvaluationResult(
            flagKey: "bool-flag",
            value: .bool(false),
            enabled: true,
            reason: .cached,
            version: 1
        )

        XCTAssertFalse(result.boolValue)
    }

    func testStringValue() {
        let result = EvaluationResult(
            flagKey: "string-flag",
            value: .string("hello"),
            enabled: true,
            reason: .server,
            version: 2
        )

        XCTAssertEqual(result.stringValue, "hello")
    }

    func testNumberValue() {
        let result = EvaluationResult(
            flagKey: "number-flag",
            value: .double(3.14),
            enabled: true,
            reason: .cached,
            version: 1
        )

        XCTAssertEqual(result.numberValue, 3.14, accuracy: 0.001)
    }

    func testIntValue() {
        let result = EvaluationResult(
            flagKey: "int-flag",
            value: .int(42),
            enabled: true,
            reason: .cached,
            version: 1
        )

        XCTAssertEqual(result.intValue, 42)
    }

    func testJsonValue() {
        let dict: [String: FlagValue] = [
            "enabled": .bool(true),
            "count": .int(5)
        ]
        let result = EvaluationResult(
            flagKey: "json-flag",
            value: .dictionary(dict),
            enabled: true,
            reason: .cached,
            version: 1
        )

        let json = result.jsonValue
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["enabled"] as? Bool, true)
        XCTAssertEqual(json?["count"] as? Int, 5)
    }

    func testEvaluationReasons() {
        XCTAssertEqual(EvaluationReason.cached.rawValue, "CACHED")
        XCTAssertEqual(EvaluationReason.server.rawValue, "SERVER")
        XCTAssertEqual(EvaluationReason.bootstrap.rawValue, "BOOTSTRAP")
        XCTAssertEqual(EvaluationReason.default.rawValue, "DEFAULT")
        XCTAssertEqual(EvaluationReason.error.rawValue, "ERROR")
        XCTAssertEqual(EvaluationReason.flagNotFound.rawValue, "FLAG_NOT_FOUND")
    }

    func testDefaultReason() {
        let defaultResult = EvaluationResult.defaultResult(
            key: "flag",
            defaultValue: .bool(true),
            reason: .default
        )
        XCTAssertEqual(defaultResult.reason, .default)

        let cachedResult = EvaluationResult(
            flagKey: "flag",
            value: .bool(true),
            enabled: true,
            reason: .cached,
            version: 1
        )
        XCTAssertNotEqual(cachedResult.reason, .default)
    }
}
