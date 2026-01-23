import Foundation

/// Context for flag evaluation containing user and custom attributes.
public struct EvaluationContext: Sendable, Equatable {
    private static let privateAttributePrefix = "_"

    /// The user identifier.
    public let userId: String?

    /// Custom attributes.
    public let attributes: [String: FlagValue]

    /// Creates a new evaluation context.
    public init(userId: String? = nil, attributes: [String: FlagValue] = [:]) {
        self.userId = userId
        self.attributes = attributes
    }

    /// Creates a context with the given user ID.
    public func withUserId(_ userId: String) -> EvaluationContext {
        EvaluationContext(userId: userId, attributes: attributes)
    }

    /// Creates a context with the given attribute added.
    public func withAttribute(_ key: String, value: FlagValue) -> EvaluationContext {
        var newAttributes = attributes
        newAttributes[key] = value
        return EvaluationContext(userId: userId, attributes: newAttributes)
    }

    /// Creates a context with multiple attributes added.
    public func withAttributes(_ newAttrs: [String: FlagValue]) -> EvaluationContext {
        var mergedAttributes = attributes
        for (key, value) in newAttrs {
            mergedAttributes[key] = value
        }
        return EvaluationContext(userId: userId, attributes: mergedAttributes)
    }

    /// Merges another context into this one.
    /// The other context takes precedence.
    public func merge(with other: EvaluationContext?) -> EvaluationContext {
        guard let other = other else { return self }

        let newUserId = other.userId ?? userId
        var newAttributes = attributes
        for (key, value) in other.attributes {
            newAttributes[key] = value
        }

        return EvaluationContext(userId: newUserId, attributes: newAttributes)
    }

    /// Creates a copy with private attributes stripped.
    public func stripPrivateAttributes() -> EvaluationContext {
        let publicAttributes = attributes.filter { !$0.key.hasPrefix(Self.privateAttributePrefix) }
        return EvaluationContext(userId: userId, attributes: publicAttributes)
    }

    /// Whether the context is empty.
    public var isEmpty: Bool {
        userId == nil && attributes.isEmpty
    }

    /// Gets an attribute value.
    public subscript(_ key: String) -> FlagValue? {
        attributes[key]
    }

    /// Converts to a dictionary for API requests.
    public func toDictionary() -> [String: Any] {
        var result: [String: Any] = [:]
        if let userId = userId {
            result["userId"] = userId
        }
        if !attributes.isEmpty {
            result["attributes"] = attributes.mapValues { $0.toAny() }
        }
        return result
    }
}

// MARK: - Builder

extension EvaluationContext {
    /// A builder for creating evaluation contexts.
    public struct Builder {
        private var userId: String?
        private var attributes: [String: FlagValue] = [:]

        public init() {}

        @discardableResult
        public mutating func userId(_ userId: String) -> Builder {
            self.userId = userId
            return self
        }

        @discardableResult
        public mutating func attribute(_ key: String, value: Bool) -> Builder {
            attributes[key] = .bool(value)
            return self
        }

        @discardableResult
        public mutating func attribute(_ key: String, value: String) -> Builder {
            attributes[key] = .string(value)
            return self
        }

        @discardableResult
        public mutating func attribute(_ key: String, value: Int) -> Builder {
            attributes[key] = .int(value)
            return self
        }

        @discardableResult
        public mutating func attribute(_ key: String, value: Double) -> Builder {
            attributes[key] = .double(value)
            return self
        }

        public func build() -> EvaluationContext {
            EvaluationContext(userId: userId, attributes: attributes)
        }
    }
}
