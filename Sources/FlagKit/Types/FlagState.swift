import Foundation

/// Represents the state of a feature flag.
public struct FlagState: Codable, Sendable, Equatable {
    /// The flag key.
    public let key: String

    /// The flag value.
    public let value: FlagValue

    /// Whether the flag is enabled.
    public let enabled: Bool

    /// The flag version.
    public let version: Int

    /// The flag type.
    public let flagType: FlagType

    /// Last modified timestamp.
    public let lastModified: String?

    /// Additional metadata.
    public let metadata: [String: String]?

    /// Creates a new flag state.
    public init(
        key: String,
        value: FlagValue,
        enabled: Bool = true,
        version: Int = 0,
        flagType: FlagType? = nil,
        lastModified: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.key = key
        self.value = value
        self.enabled = enabled
        self.version = version
        self.flagType = flagType ?? value.inferredType
        self.lastModified = lastModified ?? ISO8601DateFormatter().string(from: Date())
        self.metadata = metadata
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

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case key
        case value
        case enabled
        case version
        case flagType
        case lastModified
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        value = try container.decode(FlagValue.self, forKey: .value)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 0
        flagType = try container.decodeIfPresent(FlagType.self, forKey: .flagType) ?? value.inferredType
        lastModified = try container.decodeIfPresent(String.self, forKey: .lastModified)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
    }
}
