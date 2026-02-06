import Foundation

// MARK: - Semantic Version

/// Represents a parsed semantic version.
public struct SemanticVersion: Sendable, Equatable, Comparable {
    /// Major version number.
    public let major: Int

    /// Minor version number.
    public let minor: Int

    /// Patch version number.
    public let patch: Int

    /// Creates a new semantic version.
    /// - Parameters:
    ///   - major: Major version number.
    ///   - minor: Minor version number.
    ///   - patch: Patch version number.
    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }
}

// MARK: - Version Parsing

/// Maximum allowed value for version components (defensive limit).
private let maxVersionComponent = 999_999_999

/// Parses a semantic version string into components.
/// Supports formats like "1.0.0", "v1.0.0", "1.2.3-beta".
/// Pre-release suffixes are ignored for comparison purposes.
/// - Parameter version: The version string to parse.
/// - Returns: A SemanticVersion if valid, nil otherwise.
public func parseVersion(_ version: String) -> SemanticVersion? {
    // Trim whitespace
    let trimmed = version.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else {
        return nil
    }

    // Strip leading 'v' or 'V' if present
    var normalized = trimmed
    if normalized.hasPrefix("v") || normalized.hasPrefix("V") {
        normalized = String(normalized.dropFirst())
    }

    // Match semver pattern (allows pre-release suffix but ignores it)
    // Pattern: major.minor.patch (with optional suffix)
    let pattern = #"^(\d+)\.(\d+)\.(\d+)"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(
              in: normalized,
              range: NSRange(normalized.startIndex..., in: normalized)
          ) else {
        return nil
    }

    guard match.numberOfRanges >= 4 else {
        return nil
    }

    guard let majorRange = Range(match.range(at: 1), in: normalized),
          let minorRange = Range(match.range(at: 2), in: normalized),
          let patchRange = Range(match.range(at: 3), in: normalized),
          let major = Int(normalized[majorRange]),
          let minor = Int(normalized[minorRange]),
          let patch = Int(normalized[patchRange]) else {
        return nil
    }

    // Validate components are within reasonable bounds
    guard major >= 0 && major <= maxVersionComponent &&
          minor >= 0 && minor <= maxVersionComponent &&
          patch >= 0 && patch <= maxVersionComponent else {
        return nil
    }

    return SemanticVersion(major: major, minor: minor, patch: patch)
}

// MARK: - Version Comparison

/// Compares two semantic version strings.
/// - Parameters:
///   - a: First version string.
///   - b: Second version string.
/// - Returns:
///   - Negative if a < b
///   - Zero if a == b or either version is invalid
///   - Positive if a > b
public func compareVersions(_ a: String, _ b: String) -> Int {
    guard let parsedA = parseVersion(a),
          let parsedB = parseVersion(b) else {
        return 0
    }

    if parsedA < parsedB {
        return -1
    } else if parsedA == parsedB {
        return 0
    } else {
        return 1
    }
}

/// Checks if version a is less than version b.
/// - Parameters:
///   - a: First version string.
///   - b: Second version string.
/// - Returns: True if a < b, false otherwise (including when either version is invalid).
public func isVersionLessThan(_ a: String, _ b: String) -> Bool {
    return compareVersions(a, b) < 0
}

/// Checks if version a is greater than or equal to version b.
/// - Parameters:
///   - a: First version string.
///   - b: Second version string.
/// - Returns: True if a >= b, false otherwise (including when either version is invalid).
public func isVersionAtLeast(_ a: String, _ b: String) -> Bool {
    return compareVersions(a, b) >= 0
}
