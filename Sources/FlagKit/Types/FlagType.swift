import Foundation

/// Types of feature flags.
public enum FlagType: String, Codable, Sendable {
    case boolean
    case string
    case number
    case json

    /// Infers the flag type from a value.
    /// - Parameter value: The value to infer from.
    /// - Returns: The inferred flag type.
    public static func infer(from value: Any) -> FlagType {
        switch value {
        case is Bool:
            return .boolean
        case is String:
            return .string
        case is Int, is Double, is Float:
            return .number
        default:
            return .json
        }
    }
}
