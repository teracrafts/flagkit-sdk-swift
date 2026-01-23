import Foundation

/// A type-safe wrapper for flag values.
public enum FlagValue: Sendable, Equatable {
    case bool(Bool)
    case string(String)
    case int(Int)
    case double(Double)
    case dictionary([String: FlagValue])
    case array([FlagValue])
    case null

    /// The value as a boolean.
    public var boolValue: Bool? {
        if case .bool(let value) = self {
            return value
        }
        return nil
    }

    /// The value as a string.
    public var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .bool(let value):
            return String(value)
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(value)
        default:
            return nil
        }
    }

    /// The value as a number.
    public var numberValue: Double? {
        switch self {
        case .double(let value):
            return value
        case .int(let value):
            return Double(value)
        default:
            return nil
        }
    }

    /// The value as an integer.
    public var intValue: Int? {
        switch self {
        case .int(let value):
            return value
        case .double(let value):
            return Int(value)
        default:
            return nil
        }
    }

    /// The value as a dictionary.
    public var jsonValue: [String: Any]? {
        if case .dictionary(let dict) = self {
            return dict.mapValues { $0.toAny() }
        }
        return nil
    }

    /// The inferred flag type.
    public var inferredType: FlagType {
        switch self {
        case .bool:
            return .boolean
        case .string:
            return .string
        case .int, .double:
            return .number
        case .dictionary, .array, .null:
            return .json
        }
    }

    /// Converts to Any type.
    public func toAny() -> Any {
        switch self {
        case .bool(let value):
            return value
        case .string(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .dictionary(let dict):
            return dict.mapValues { $0.toAny() }
        case .array(let arr):
            return arr.map { $0.toAny() }
        case .null:
            return NSNull()
        }
    }

    /// Creates a FlagValue from Any type.
    public static func from(_ value: Any) -> FlagValue {
        switch value {
        case let bool as Bool:
            return .bool(bool)
        case let string as String:
            return .string(string)
        case let int as Int:
            return .int(int)
        case let double as Double:
            return .double(double)
        case let dict as [String: Any]:
            return .dictionary(dict.mapValues { from($0) })
        case let array as [Any]:
            return .array(array.map { from($0) })
        default:
            return .null
        }
    }
}

// MARK: - Codable

extension FlagValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let dict = try? container.decode([String: FlagValue].self) {
            self = .dictionary(dict)
        } else if let array = try? container.decode([FlagValue].self) {
            self = .array(array)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.typeMismatch(
                FlagValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unable to decode FlagValue"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}
