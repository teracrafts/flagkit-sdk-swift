import Foundation

// MARK: - Error Sanitization Configuration

/// Configuration for error message sanitization.
public struct ErrorSanitizationConfig: Sendable {
    /// Whether error sanitization is enabled.
    public let enabled: Bool

    /// Whether to preserve the original error message (for debugging purposes).
    /// When true, the original message is stored but the sanitized version is used for display.
    public let preserveOriginal: Bool

    /// Creates a new error sanitization configuration.
    /// - Parameters:
    ///   - enabled: Whether sanitization is enabled (default: true).
    ///   - preserveOriginal: Whether to preserve the original message (default: false).
    public init(enabled: Bool = true, preserveOriginal: Bool = false) {
        self.enabled = enabled
        self.preserveOriginal = preserveOriginal
    }

    /// Default configuration with sanitization enabled.
    public static let `default` = ErrorSanitizationConfig()

    /// Configuration with sanitization disabled (for development/debugging).
    public static let disabled = ErrorSanitizationConfig(enabled: false)
}

// MARK: - Error Sanitizer

/// Sanitizes error messages to remove sensitive information.
public struct ErrorSanitizer: Sendable {

    /// Shared sanitizer instance with default patterns.
    public static let shared = ErrorSanitizer()

    /// The sanitization patterns.
    private let patterns: [SanitizationPattern]

    /// Creates a new error sanitizer with default patterns.
    public init() {
        self.patterns = SanitizationPattern.defaultPatterns
    }

    /// Creates a new error sanitizer with custom patterns.
    /// - Parameter patterns: The patterns to use for sanitization.
    public init(patterns: [SanitizationPattern]) {
        self.patterns = patterns
    }

    /// Sanitizes an error message by replacing sensitive information with placeholders.
    /// - Parameter message: The message to sanitize.
    /// - Returns: The sanitized message.
    public func sanitize(_ message: String) -> String {
        var result = message

        for pattern in patterns {
            result = pattern.apply(to: result)
        }

        return result
    }

    /// Sanitizes an error message if the configuration is enabled.
    /// - Parameters:
    ///   - message: The message to sanitize.
    ///   - config: The sanitization configuration.
    /// - Returns: A tuple containing the sanitized message and optionally the original.
    public func sanitize(_ message: String, config: ErrorSanitizationConfig) -> SanitizedMessage {
        guard config.enabled else {
            return SanitizedMessage(sanitized: message, original: nil)
        }

        let sanitized = sanitize(message)
        let original = config.preserveOriginal ? message : nil

        return SanitizedMessage(sanitized: sanitized, original: original)
    }
}

// MARK: - Sanitized Message

/// A sanitized error message with optional access to the original.
public struct SanitizedMessage: Sendable {
    /// The sanitized message.
    public let sanitized: String

    /// The original message, if preserved.
    public let original: String?

    /// Returns the sanitized message.
    public var message: String { sanitized }
}

// MARK: - Sanitization Pattern

/// A pattern for sanitizing sensitive information from error messages.
public struct SanitizationPattern: Sendable {
    /// The name of the pattern (for debugging).
    public let name: String

    /// The replacement placeholder.
    public let replacement: String

    /// The compiled regular expression.
    private let regex: NSRegularExpression

    /// Creates a new sanitization pattern.
    /// - Parameters:
    ///   - name: The name of the pattern.
    ///   - pattern: The regular expression pattern.
    ///   - replacement: The replacement placeholder.
    public init?(name: String, pattern: String, replacement: String) {
        self.name = name
        self.replacement = replacement

        do {
            self.regex = try NSRegularExpression(pattern: pattern, options: [])
        } catch {
            return nil
        }
    }

    /// Applies the pattern to a string.
    /// - Parameter string: The string to sanitize.
    /// - Returns: The sanitized string.
    public func apply(to string: String) -> String {
        let range = NSRange(string.startIndex..., in: string)
        return regex.stringByReplacingMatches(
            in: string,
            options: [],
            range: range,
            withTemplate: replacement
        )
    }

    // MARK: - Default Patterns

    /// Default sanitization patterns for common sensitive data.
    public static let defaultPatterns: [SanitizationPattern] = [
        // API keys with sdk_, srv_, or cli_ prefix
        SanitizationPattern(
            name: "apiKey",
            pattern: #"(sdk_|srv_|cli_)[a-zA-Z0-9_-]+"#,
            replacement: "[REDACTED]"
        ),

        // Email addresses
        SanitizationPattern(
            name: "email",
            pattern: #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#,
            replacement: "[EMAIL]"
        ),

        // IPv4 addresses
        SanitizationPattern(
            name: "ipv4",
            pattern: #"\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"#,
            replacement: "[IP]"
        ),

        // Unix paths (absolute paths starting with /)
        SanitizationPattern(
            name: "unixPath",
            pattern: #"(?<!\w)/(?:[a-zA-Z0-9._-]+/)+[a-zA-Z0-9._-]+"#,
            replacement: "[PATH]"
        ),

        // Windows paths (C:\, D:\, etc.)
        SanitizationPattern(
            name: "windowsPath",
            pattern: #"[A-Za-z]:\\(?:[^\\/:*?"<>|\r\n]+\\)*[^\\/:*?"<>|\r\n]*"#,
            replacement: "[PATH]"
        ),

        // Connection strings (various database formats)
        SanitizationPattern(
            name: "connectionString",
            pattern: #"(?:mongodb(?:\+srv)?|postgres(?:ql)?|mysql|redis|amqp|mssql):\/\/[^\s]+"#,
            replacement: "[CONNECTION_STRING]"
        ),

        // Generic connection strings with credentials
        SanitizationPattern(
            name: "connectionStringWithCreds",
            pattern: #"[a-zA-Z]+:\/\/[^:]+:[^@]+@[^\s]+"#,
            replacement: "[CONNECTION_STRING]"
        )
    ].compactMap { $0 }

    /// Pattern for API keys only.
    public static let apiKeyPattern = SanitizationPattern(
        name: "apiKey",
        pattern: #"(sdk_|srv_|cli_)[a-zA-Z0-9_-]+"#,
        replacement: "[REDACTED]"
    )

    /// Pattern for email addresses only.
    public static let emailPattern = SanitizationPattern(
        name: "email",
        pattern: #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#,
        replacement: "[EMAIL]"
    )

    /// Pattern for IPv4 addresses only.
    public static let ipv4Pattern = SanitizationPattern(
        name: "ipv4",
        pattern: #"\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"#,
        replacement: "[IP]"
    )

    /// Pattern for Unix paths only.
    public static let unixPathPattern = SanitizationPattern(
        name: "unixPath",
        pattern: #"(?<!\w)/(?:[a-zA-Z0-9._-]+/)+[a-zA-Z0-9._-]+"#,
        replacement: "[PATH]"
    )

    /// Pattern for Windows paths only.
    public static let windowsPathPattern = SanitizationPattern(
        name: "windowsPath",
        pattern: #"[A-Za-z]:\\(?:[^\\/:*?"<>|\r\n]+\\)*[^\\/:*?"<>|\r\n]*"#,
        replacement: "[PATH]"
    )

    /// Pattern for connection strings only.
    public static let connectionStringPattern = SanitizationPattern(
        name: "connectionString",
        pattern: #"(?:mongodb(?:\+srv)?|postgres(?:ql)?|mysql|redis|amqp|mssql):\/\/[^\s]+"#,
        replacement: "[CONNECTION_STRING]"
    )
}

// MARK: - String Extension

extension String {
    /// Returns a sanitized version of this string with sensitive information removed.
    public func sanitized() -> String {
        ErrorSanitizer.shared.sanitize(self)
    }

    /// Returns a sanitized version of this string based on the configuration.
    public func sanitized(config: ErrorSanitizationConfig) -> SanitizedMessage {
        ErrorSanitizer.shared.sanitize(self, config: config)
    }
}
