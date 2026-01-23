import Foundation

/// Result of evaluating a feature flag.
public struct EvaluationResult: Sendable {
    /// The flag key.
    public let flagKey: String

    /// The evaluated value.
    public let value: FlagValue

    /// Whether the flag is enabled.
    public let enabled: Bool

    /// The evaluation reason.
    public let reason: EvaluationReason

    /// The flag version.
    public let version: Int

    /// When the evaluation occurred.
    public let timestamp: Date

    /// Creates a new evaluation result.
    public init(
        flagKey: String,
        value: FlagValue,
        enabled: Bool = false,
        reason: EvaluationReason = .default,
        version: Int = 0,
        timestamp: Date = Date()
    ) {
        self.flagKey = flagKey
        self.value = value
        self.enabled = enabled
        self.reason = reason
        self.version = version
        self.timestamp = timestamp
    }

    /// The value as a boolean.
    public var boolValue: Bool {
        value.boolValue ?? false
    }

    /// The value as a string.
    public var stringValue: String? {
        value.stringValue
    }

    /// The value as a number.
    public var numberValue: Double {
        value.numberValue ?? 0.0
    }

    /// The value as an integer.
    public var intValue: Int {
        value.intValue ?? 0
    }

    /// The value as a dictionary.
    public var jsonValue: [String: Any]? {
        value.jsonValue
    }

    /// Creates a default result.
    public static func defaultResult(
        key: String,
        defaultValue: FlagValue,
        reason: EvaluationReason
    ) -> EvaluationResult {
        EvaluationResult(
            flagKey: key,
            value: defaultValue,
            enabled: false,
            reason: reason
        )
    }
}
