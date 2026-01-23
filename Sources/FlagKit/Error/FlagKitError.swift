import Foundation

/// Error type for FlagKit SDK operations.
public struct FlagKitError: Error, Sendable {
    /// The error code.
    public let code: ErrorCode

    /// The error message.
    public let message: String

    /// The underlying cause, if any.
    public let cause: Error?

    /// Additional error details.
    public var details: [String: Any] = [:]

    /// Creates a new FlagKit error.
    /// - Parameters:
    ///   - code: The error code.
    ///   - message: The error message.
    ///   - cause: The underlying cause.
    public init(code: ErrorCode, message: String, cause: Error? = nil) {
        self.code = code
        self.message = message
        self.cause = cause
    }

    /// Whether this error is recoverable.
    public var isRecoverable: Bool {
        code.isRecoverable
    }

    // MARK: - Factory Methods

    /// Creates an initialization error.
    public static func initError(_ message: String) -> FlagKitError {
        FlagKitError(code: .initFailed, message: message)
    }

    /// Creates an authentication error.
    public static func authError(code: ErrorCode, message: String) -> FlagKitError {
        FlagKitError(code: code, message: message)
    }

    /// Creates a network error.
    public static func networkError(_ message: String, cause: Error? = nil) -> FlagKitError {
        FlagKitError(code: .networkError, message: message, cause: cause)
    }

    /// Creates an evaluation error.
    public static func evalError(code: ErrorCode, message: String) -> FlagKitError {
        FlagKitError(code: code, message: message)
    }

    /// Creates a configuration error.
    public static func configError(code: ErrorCode, message: String) -> FlagKitError {
        FlagKitError(code: code, message: message)
    }
}

extension FlagKitError: LocalizedError {
    public var errorDescription: String? {
        "[\(code.rawValue)] \(message)"
    }
}
