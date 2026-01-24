import XCTest
@testable import FlagKit

final class FlagValueTests: XCTestCase {
    func testBoolValue() {
        let value = FlagValue.bool(true)
        XCTAssertEqual(value.boolValue, true)
    }

    func testBoolValueFalse() {
        let value = FlagValue.bool(false)
        XCTAssertEqual(value.boolValue, false)
    }

    func testStringValue() {
        let value = FlagValue.string("hello")
        XCTAssertEqual(value.stringValue, "hello")
    }

    func testIntValue() {
        let value = FlagValue.int(42)
        XCTAssertEqual(value.intValue, 42)
    }

    func testDoubleValue() {
        let value = FlagValue.double(3.14)
        XCTAssertEqual(value.numberValue!, 3.14, accuracy: 0.001)
    }

    func testDictionaryValue() {
        let dict: [String: FlagValue] = [
            "key": .string("value"),
            "count": .int(10)
        ]
        let value = FlagValue.dictionary(dict)

        if case .dictionary(let result) = value {
            XCTAssertEqual(result["key"]?.stringValue, "value")
            XCTAssertEqual(result["count"]?.intValue, 10)
        } else {
            XCTFail("Expected dictionary")
        }
    }

    func testArrayValue() {
        let arr: [FlagValue] = [.string("a"), .string("b"), .int(3)]
        let value = FlagValue.array(arr)

        if case .array(let result) = value {
            XCTAssertEqual(result.count, 3)
            XCTAssertEqual(result[0].stringValue, "a")
            XCTAssertEqual(result[1].stringValue, "b")
            XCTAssertEqual(result[2].intValue, 3)
        } else {
            XCTFail("Expected array")
        }
    }

    func testNullValue() {
        let value = FlagValue.null
        if case .null = value {
            // Value is null
        } else {
            XCTFail("Expected null value")
        }
    }

    func testFromBool() {
        let value = FlagValue.from(true)
        XCTAssertEqual(value.boolValue, true)
    }

    func testFromString() {
        let value = FlagValue.from("test")
        XCTAssertEqual(value.stringValue, "test")
    }

    func testFromInt() {
        let value = FlagValue.from(123)
        XCTAssertEqual(value.intValue, 123)
    }

    func testFromDouble() {
        let value = FlagValue.from(1.5)
        XCTAssertEqual(value.numberValue!, 1.5, accuracy: 0.001)
    }

    func testEquatable() {
        XCTAssertEqual(FlagValue.bool(true), FlagValue.bool(true))
        XCTAssertNotEqual(FlagValue.bool(true), FlagValue.bool(false))
        XCTAssertEqual(FlagValue.string("a"), FlagValue.string("a"))
        XCTAssertNotEqual(FlagValue.string("a"), FlagValue.string("b"))
        XCTAssertEqual(FlagValue.int(1), FlagValue.int(1))
        XCTAssertNotEqual(FlagValue.int(1), FlagValue.int(2))
    }
}
