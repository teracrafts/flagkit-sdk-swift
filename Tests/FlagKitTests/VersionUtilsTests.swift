import XCTest
@testable import FlagKit

final class VersionUtilsTests: XCTestCase {

    // MARK: - parseVersion Tests

    func testParseVersion_ValidSemver() {
        let result = parseVersion("1.2.3")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.major, 1)
        XCTAssertEqual(result?.minor, 2)
        XCTAssertEqual(result?.patch, 3)
    }

    func testParseVersion_ZeroVersion() {
        let result = parseVersion("0.0.0")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.major, 0)
        XCTAssertEqual(result?.minor, 0)
        XCTAssertEqual(result?.patch, 0)
    }

    func testParseVersion_LowercaseVPrefix() {
        let result = parseVersion("v1.2.3")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.major, 1)
    }

    func testParseVersion_UppercaseVPrefix() {
        let result = parseVersion("V1.2.3")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.major, 1)
    }

    func testParseVersion_PrereleaseSuffix() {
        let result = parseVersion("1.2.3-beta.1")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.major, 1)
        XCTAssertEqual(result?.minor, 2)
        XCTAssertEqual(result?.patch, 3)
    }

    func testParseVersion_BuildMetadata() {
        let result = parseVersion("1.2.3+build.123")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.patch, 3)
    }

    func testParseVersion_LeadingWhitespace() {
        let result = parseVersion("  1.2.3")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.major, 1)
    }

    func testParseVersion_TrailingWhitespace() {
        let result = parseVersion("1.2.3  ")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.major, 1)
    }

    func testParseVersion_SurroundingWhitespace() {
        let result = parseVersion("  1.2.3  ")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.major, 1)
    }

    func testParseVersion_VPrefixWithWhitespace() {
        let result = parseVersion("  v1.0.0  ")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.major, 1)
    }

    func testParseVersion_EmptyString() {
        XCTAssertNil(parseVersion(""))
    }

    func testParseVersion_WhitespaceOnly() {
        XCTAssertNil(parseVersion("   "))
    }

    func testParseVersion_Invalid() {
        XCTAssertNil(parseVersion("invalid"))
    }

    func testParseVersion_PartialVersion() {
        XCTAssertNil(parseVersion("1.2"))
    }

    func testParseVersion_NonNumeric() {
        XCTAssertNil(parseVersion("a.b.c"))
    }

    func testParseVersion_ExceedsMaxBoundary() {
        XCTAssertNil(parseVersion("1000000000.0.0"))
    }

    func testParseVersion_AtMaxBoundary() {
        let result = parseVersion("999999999.999999999.999999999")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.major, 999999999)
    }

    // MARK: - compareVersions Tests

    func testCompareVersions_Equal() {
        XCTAssertEqual(compareVersions("1.0.0", "1.0.0"), 0)
    }

    func testCompareVersions_EqualWithVPrefix() {
        XCTAssertEqual(compareVersions("v1.0.0", "1.0.0"), 0)
    }

    func testCompareVersions_ALessThanB_Major() {
        XCTAssertLessThan(compareVersions("1.0.0", "2.0.0"), 0)
    }

    func testCompareVersions_ALessThanB_Minor() {
        XCTAssertLessThan(compareVersions("1.0.0", "1.1.0"), 0)
    }

    func testCompareVersions_ALessThanB_Patch() {
        XCTAssertLessThan(compareVersions("1.0.0", "1.0.1"), 0)
    }

    func testCompareVersions_AGreaterThanB() {
        XCTAssertGreaterThan(compareVersions("2.0.0", "1.0.0"), 0)
    }

    func testCompareVersions_InvalidReturnsZero() {
        XCTAssertEqual(compareVersions("invalid", "1.0.0"), 0)
        XCTAssertEqual(compareVersions("1.0.0", "invalid"), 0)
    }

    // MARK: - isVersionLessThan Tests

    func testIsVersionLessThan_True() {
        XCTAssertTrue(isVersionLessThan("1.0.0", "1.0.1"))
        XCTAssertTrue(isVersionLessThan("1.0.0", "1.1.0"))
        XCTAssertTrue(isVersionLessThan("1.0.0", "2.0.0"))
    }

    func testIsVersionLessThan_False() {
        XCTAssertFalse(isVersionLessThan("1.0.0", "1.0.0"))
        XCTAssertFalse(isVersionLessThan("1.1.0", "1.0.0"))
    }

    func testIsVersionLessThan_InvalidReturnsFalse() {
        XCTAssertFalse(isVersionLessThan("invalid", "1.0.0"))
    }

    // MARK: - isVersionAtLeast Tests

    func testIsVersionAtLeast_True() {
        XCTAssertTrue(isVersionAtLeast("1.0.0", "1.0.0"))
        XCTAssertTrue(isVersionAtLeast("1.1.0", "1.0.0"))
        XCTAssertTrue(isVersionAtLeast("2.0.0", "1.0.0"))
    }

    func testIsVersionAtLeast_False() {
        XCTAssertFalse(isVersionAtLeast("1.0.0", "1.0.1"))
        XCTAssertFalse(isVersionAtLeast("1.0.0", "2.0.0"))
    }

    // MARK: - SDK Scenarios

    func testSDK_BelowMinimum() {
        let sdkVersion = "1.0.0"
        let minVersion = "1.1.0"
        XCTAssertTrue(isVersionLessThan(sdkVersion, minVersion))
    }

    func testSDK_AtMinimum() {
        let sdkVersion = "1.1.0"
        let minVersion = "1.1.0"
        XCTAssertFalse(isVersionLessThan(sdkVersion, minVersion))
    }

    func testSDK_ServerVPrefixedResponse() {
        let sdkVersion = "1.0.0"
        let serverMin = "v1.1.0"
        XCTAssertTrue(isVersionLessThan(sdkVersion, serverMin))
    }
}
