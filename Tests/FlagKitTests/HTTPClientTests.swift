import XCTest
@testable import FlagKit

final class HTTPClientTests: XCTestCase {
    func testGetBaseUrlDefault() {
        setenv("FLAGKIT_MODE", "", 1)
        let url = HTTPClient.getBaseUrl()
        XCTAssertEqual(url, "https://api.flagkit.dev/api/v1")
    }

    func testGetBaseUrlWithLocalMode() {
        setenv("FLAGKIT_MODE", "local", 1)
        let url = HTTPClient.getBaseUrl()
        XCTAssertEqual(url, "https://api.flagkit.on/api/v1")
    }

    func testGetBaseUrlWithBetaMode() {
        setenv("FLAGKIT_MODE", "beta", 1)
        let url = HTTPClient.getBaseUrl()
        XCTAssertEqual(url, "https://api.beta.flagkit.dev/api/v1")
    }

    func testGetBaseUrlTrimsWhitespace() {
        setenv("FLAGKIT_MODE", " local ", 1)
        let url = HTTPClient.getBaseUrl()
        XCTAssertEqual(url, "https://api.flagkit.on/api/v1")
    }

    func testGetBaseUrlFallsThroughForUnknownMode() {
        setenv("FLAGKIT_MODE", "staging", 1)
        let url = HTTPClient.getBaseUrl()
        XCTAssertEqual(url, "https://api.flagkit.dev/api/v1")
    }
}
