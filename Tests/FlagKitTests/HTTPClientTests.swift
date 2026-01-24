import XCTest
@testable import FlagKit

final class HTTPClientTests: XCTestCase {
    func testGetBaseUrlDefault() {
        let url = HTTPClient.getBaseUrl(localPort: nil)
        XCTAssertEqual(url, "https://api.flagkit.dev/api/v1")
    }

    func testGetBaseUrlWithLocalPort() {
        let url = HTTPClient.getBaseUrl(localPort: 8200)
        XCTAssertEqual(url, "http://localhost:8200/api/v1")
    }

    func testGetBaseUrlWithCustomPort() {
        let url = HTTPClient.getBaseUrl(localPort: 3000)
        XCTAssertEqual(url, "http://localhost:3000/api/v1")
    }

    func testGetBaseUrlWithPort80() {
        let url = HTTPClient.getBaseUrl(localPort: 80)
        XCTAssertEqual(url, "http://localhost:80/api/v1")
    }
}
