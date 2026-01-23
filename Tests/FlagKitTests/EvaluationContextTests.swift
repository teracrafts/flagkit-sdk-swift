import XCTest
@testable import FlagKit

final class EvaluationContextTests: XCTestCase {
    func testEmptyContext() {
        let context = EvaluationContext()
        XCTAssertNil(context.userId)
        XCTAssertTrue(context.attributes.isEmpty)
        XCTAssertTrue(context.isEmpty)
    }

    func testContextWithUserId() {
        let context = EvaluationContext(userId: "user-123")
        XCTAssertEqual(context.userId, "user-123")
        XCTAssertFalse(context.isEmpty)
    }

    func testContextWithAttributes() {
        let context = EvaluationContext(attributes: [
            "email": .string("test@example.com"),
            "plan": .string("pro")
        ])
        XCTAssertEqual(context["email"]?.stringValue, "test@example.com")
        XCTAssertEqual(context["plan"]?.stringValue, "pro")
    }

    func testWithUserId() {
        let context = EvaluationContext(attributes: ["email": .string("test@example.com")])
        let newContext = context.withUserId("user-456")

        XCTAssertEqual(newContext.userId, "user-456")
        XCTAssertEqual(newContext["email"]?.stringValue, "test@example.com")
        XCTAssertNil(context.userId) // Original unchanged
    }

    func testWithAttribute() {
        let context = EvaluationContext(userId: "user-123")
        let newContext = context.withAttribute("plan", value: .string("enterprise"))

        XCTAssertEqual(newContext["plan"]?.stringValue, "enterprise")
        XCTAssertNil(context["plan"])
    }

    func testWithAttributes() {
        let context = EvaluationContext(userId: "user-123")
        let newContext = context.withAttributes([
            "plan": .string("pro"),
            "region": .string("us")
        ])

        XCTAssertEqual(newContext["plan"]?.stringValue, "pro")
        XCTAssertEqual(newContext["region"]?.stringValue, "us")
    }

    func testMerge() {
        let context1 = EvaluationContext(
            userId: "user-1",
            attributes: ["email": .string("a@test.com")]
        )
        let context2 = EvaluationContext(
            userId: "user-2",
            attributes: ["plan": .string("pro")]
        )

        let merged = context1.merge(with: context2)

        XCTAssertEqual(merged.userId, "user-2")
        XCTAssertEqual(merged["email"]?.stringValue, "a@test.com")
        XCTAssertEqual(merged["plan"]?.stringValue, "pro")
    }

    func testMergeWithNil() {
        let context = EvaluationContext(userId: "user-1")
        let merged = context.merge(with: nil)

        XCTAssertEqual(merged.userId, "user-1")
    }

    func testStripPrivateAttributes() {
        let context = EvaluationContext(
            userId: "user-123",
            attributes: [
                "email": .string("test@example.com"),
                "_secret": .string("hidden"),
                "_internal": .string("value")
            ]
        )

        let stripped = context.stripPrivateAttributes()

        XCTAssertEqual(stripped.userId, "user-123")
        XCTAssertEqual(stripped["email"]?.stringValue, "test@example.com")
        XCTAssertNil(stripped["_secret"])
        XCTAssertNil(stripped["_internal"])
    }

    func testToDictionary() {
        let context = EvaluationContext(
            userId: "user-123",
            attributes: ["email": .string("test@example.com")]
        )

        let dict = context.toDictionary()

        XCTAssertEqual(dict["userId"] as? String, "user-123")
        XCTAssertNotNil(dict["attributes"])
    }

    func testEquality() {
        let context1 = EvaluationContext(
            userId: "user-123",
            attributes: ["email": .string("test@example.com")]
        )
        let context2 = EvaluationContext(
            userId: "user-123",
            attributes: ["email": .string("test@example.com")]
        )
        let context3 = EvaluationContext(userId: "user-456")

        XCTAssertEqual(context1, context2)
        XCTAssertNotEqual(context1, context3)
    }
}
