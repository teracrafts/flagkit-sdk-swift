import Foundation

/// Manages global and per-evaluation context for flag evaluations.
public actor ContextManager {
    private var globalContext: EvaluationContext?

    /// Creates a new context manager.
    public init() {
        self.globalContext = nil
    }

    /// Creates a new context manager with an initial context.
    /// - Parameter initialContext: The initial global context.
    public init(initialContext: EvaluationContext?) {
        self.globalContext = initialContext
    }

    // MARK: - Context Management

    /// Sets the global context that applies to all evaluations.
    /// - Parameter context: The context to set.
    public func setContext(_ context: EvaluationContext) {
        self.globalContext = context
    }

    /// Gets the current global context.
    /// - Returns: The current context, or nil if not set.
    public func getContext() -> EvaluationContext? {
        return globalContext
    }

    /// Clears the global context.
    public func clearContext() {
        globalContext = nil
    }

    /// Updates the global context with new attributes.
    /// Existing attributes are preserved unless overwritten.
    /// - Parameter updates: The attributes to update.
    public func updateContext(_ updates: [String: FlagValue]) {
        if let current = globalContext {
            globalContext = current.withAttributes(updates)
        } else {
            globalContext = EvaluationContext(attributes: updates)
        }
    }

    // MARK: - User Identification

    /// Identifies a user with the given user ID and optional attributes.
    /// - Parameters:
    ///   - userId: The user identifier.
    ///   - attributes: Optional additional attributes.
    public func identify(userId: String, attributes: [String: FlagValue] = [:]) {
        var mergedAttributes = globalContext?.attributes ?? [:]
        for (key, value) in attributes {
            mergedAttributes[key] = value
        }
        mergedAttributes["anonymous"] = .bool(false)

        globalContext = EvaluationContext(userId: userId, attributes: mergedAttributes)
    }

    /// Resets to anonymous state, clearing user identification.
    public func reset() {
        globalContext = EvaluationContext(attributes: ["anonymous": .bool(true)])
    }

    // MARK: - Context Resolution

    /// Resolves the final context by merging global and evaluation-specific context.
    /// The evaluation context takes precedence over the global context.
    /// Private attributes are stripped before returning.
    /// - Parameter evaluationContext: Optional per-evaluation context.
    /// - Returns: The resolved context with private attributes stripped, or nil if no context available.
    public func resolveContext(with evaluationContext: EvaluationContext? = nil) -> EvaluationContext? {
        let merged = mergeContexts(global: globalContext, evaluation: evaluationContext)
        return merged?.stripPrivateAttributes()
    }

    /// Gets the merged context without stripping private attributes.
    /// - Parameter evaluationContext: Optional per-evaluation context.
    /// - Returns: The merged context, or nil if no context available.
    public func getMergedContext(with evaluationContext: EvaluationContext? = nil) -> EvaluationContext? {
        return mergeContexts(global: globalContext, evaluation: evaluationContext)
    }

    // MARK: - State Queries

    /// Whether a user has been identified.
    public var isIdentified: Bool {
        guard let context = globalContext else { return false }
        if let anonymous = context.attributes["anonymous"]?.boolValue, anonymous {
            return false
        }
        return context.userId != nil
    }

    /// Whether the user is anonymous.
    public var isAnonymous: Bool {
        guard let context = globalContext else { return true }
        if let anonymous = context.attributes["anonymous"]?.boolValue {
            return anonymous
        }
        return context.userId == nil
    }

    /// Gets the current user ID if identified.
    public var userId: String? {
        return globalContext?.userId
    }

    /// Gets a specific attribute from the global context.
    /// - Parameter key: The attribute key.
    /// - Returns: The attribute value, or nil if not found.
    public func getAttribute(_ key: String) -> FlagValue? {
        return globalContext?.attributes[key]
    }

    /// Sets a specific attribute in the global context.
    /// - Parameters:
    ///   - key: The attribute key.
    ///   - value: The attribute value.
    public func setAttribute(_ key: String, value: FlagValue) {
        if let current = globalContext {
            globalContext = current.withAttribute(key, value: value)
        } else {
            globalContext = EvaluationContext(attributes: [key: value])
        }
    }

    /// Removes a specific attribute from the global context.
    /// - Parameter key: The attribute key to remove.
    public func removeAttribute(_ key: String) {
        guard var attributes = globalContext?.attributes else { return }
        attributes.removeValue(forKey: key)
        globalContext = EvaluationContext(userId: globalContext?.userId, attributes: attributes)
    }

    // MARK: - Private Methods

    private func mergeContexts(global: EvaluationContext?, evaluation: EvaluationContext?) -> EvaluationContext? {
        switch (global, evaluation) {
        case (nil, nil):
            return nil
        case (let g?, nil):
            return g
        case (nil, let e?):
            return e
        case (let g?, let e?):
            return g.merge(with: e)
        }
    }
}

// MARK: - Convenience Extensions

extension EvaluationContext {
    /// Standard attribute keys used by FlagKit.
    public enum StandardAttribute: String {
        case email = "email"
        case name = "name"
        case country = "country"
        case ip = "ip"
        case userAgent = "userAgent"
        case anonymous = "anonymous"
        case plan = "plan"
        case version = "version"
    }

    /// Creates a context with a standard attribute.
    public func with(_ attribute: StandardAttribute, value: FlagValue) -> EvaluationContext {
        return withAttribute(attribute.rawValue, value: value)
    }

    /// Gets a standard attribute.
    public subscript(_ attribute: StandardAttribute) -> FlagValue? {
        return attributes[attribute.rawValue]
    }

    /// Creates a new context builder.
    public static func builder() -> Builder {
        return Builder()
    }
}

// MARK: - Context Factory

extension EvaluationContext {
    /// Creates an anonymous context.
    public static func anonymous() -> EvaluationContext {
        return EvaluationContext(attributes: ["anonymous": .bool(true)])
    }

    /// Creates a context for an identified user.
    /// - Parameters:
    ///   - userId: The user identifier.
    ///   - email: Optional email address.
    ///   - name: Optional display name.
    ///   - attributes: Additional custom attributes.
    public static func user(
        _ userId: String,
        email: String? = nil,
        name: String? = nil,
        attributes: [String: FlagValue] = [:]
    ) -> EvaluationContext {
        var attrs = attributes
        attrs["anonymous"] = .bool(false)

        if let email = email {
            attrs["email"] = .string(email)
        }

        if let name = name {
            attrs["name"] = .string(name)
        }

        return EvaluationContext(userId: userId, attributes: attrs)
    }
}
