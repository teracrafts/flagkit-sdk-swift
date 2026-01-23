import XCTest
@testable import FlagKit

final class ErrorCodeTests: XCTestCase {
    func testErrorCodeValues() {
        XCTAssertEqual(ErrorCode.initFailed.rawValue, "INIT_FAILED")
        XCTAssertEqual(ErrorCode.initAlreadyInitialized.rawValue, "INIT_ALREADY_INITIALIZED")
        XCTAssertEqual(ErrorCode.authInvalidKey.rawValue, "AUTH_INVALID_KEY")
        XCTAssertEqual(ErrorCode.networkError.rawValue, "NETWORK_ERROR")
        XCTAssertEqual(ErrorCode.circuitOpen.rawValue, "CIRCUIT_OPEN")
        XCTAssertEqual(ErrorCode.evalFlagNotFound.rawValue, "EVAL_FLAG_NOT_FOUND")
    }

    func testRecoverableErrors() {
        XCTAssertTrue(ErrorCode.networkError.isRecoverable)
        XCTAssertTrue(ErrorCode.networkTimeout.isRecoverable)
        XCTAssertTrue(ErrorCode.circuitOpen.isRecoverable)
        XCTAssertTrue(ErrorCode.cacheExpired.isRecoverable)
    }

    func testNonRecoverableErrors() {
        XCTAssertFalse(ErrorCode.initFailed.isRecoverable)
        XCTAssertFalse(ErrorCode.authInvalidKey.isRecoverable)
        XCTAssertFalse(ErrorCode.configInvalidApiKey.isRecoverable)
    }
}
