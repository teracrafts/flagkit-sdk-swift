import XCTest
@testable import FlagKit

final class FlagStateTests: XCTestCase {
    func testDecodeFlagState() throws {
        let json = """
        {
            "key": "test-flag",
            "value": true,
            "enabled": true,
            "version": 5,
            "flagType": "boolean",
            "lastModified": "2024-01-15T10:30:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let flagState = try decoder.decode(FlagState.self, from: json)

        XCTAssertEqual(flagState.key, "test-flag")
        XCTAssertTrue(flagState.enabled)
        XCTAssertEqual(flagState.version, 5)
        XCTAssertEqual(flagState.flagType, .boolean)
    }

    func testDecodeFlagStateWithStringValue() throws {
        let json = """
        {
            "key": "string-flag",
            "value": "hello world",
            "enabled": true,
            "version": 1,
            "flagType": "string",
            "lastModified": "2024-01-15T10:30:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let flagState = try decoder.decode(FlagState.self, from: json)

        XCTAssertEqual(flagState.key, "string-flag")
        XCTAssertEqual(flagState.value.stringValue, "hello world")
        XCTAssertEqual(flagState.flagType, .string)
    }

    func testDecodeFlagStateWithNumberValue() throws {
        let json = """
        {
            "key": "number-flag",
            "value": 42.5,
            "enabled": true,
            "version": 2,
            "flagType": "number",
            "lastModified": "2024-01-15T10:30:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let flagState = try decoder.decode(FlagState.self, from: json)

        XCTAssertEqual(flagState.key, "number-flag")
        XCTAssertEqual(flagState.value.numberValue!, 42.5, accuracy: 0.001)
        XCTAssertEqual(flagState.flagType, .number)
    }

    func testDecodeFlagStateWithJsonValue() throws {
        let json = """
        {
            "key": "json-flag",
            "value": {"nested": "value", "count": 10},
            "enabled": true,
            "version": 3,
            "flagType": "json",
            "lastModified": "2024-01-15T10:30:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let flagState = try decoder.decode(FlagState.self, from: json)

        XCTAssertEqual(flagState.key, "json-flag")
        XCTAssertEqual(flagState.flagType, .json)

        if case .dictionary(let dict) = flagState.value {
            XCTAssertEqual(dict["nested"]?.stringValue, "value")
            XCTAssertEqual(dict["count"]?.intValue, 10)
        } else {
            XCTFail("Expected dictionary value")
        }
    }

    func testFlagTypeRawValues() {
        XCTAssertEqual(FlagType.boolean.rawValue, "boolean")
        XCTAssertEqual(FlagType.string.rawValue, "string")
        XCTAssertEqual(FlagType.number.rawValue, "number")
        XCTAssertEqual(FlagType.json.rawValue, "json")
    }
}
