import Foundation

/// Static factory for FlagKit SDK with singleton pattern.
public final class FlagKit: @unchecked Sendable {
    /// The singleton instance.
    private static var _instance: FlagKitClient?
    private static let lock = NSLock()

    private init() {}

    /// The current client instance.
    public static var instance: FlagKitClient? {
        lock.lock()
        defer { lock.unlock() }
        return _instance
    }

    /// Initializes the FlagKit SDK.
    /// - Parameter options: The configuration options.
    /// - Returns: The initialized client.
    @discardableResult
    public static func initialize(options: FlagKitOptions) async throws -> FlagKitClient {
        lock.lock()

        if let existing = _instance {
            lock.unlock()
            throw FlagKitError(code: .initAlreadyInitialized, message: "FlagKit is already initialized")
        }

        try options.validate()

        let client = FlagKitClient(options: options)
        _instance = client
        lock.unlock()

        try await client.initialize()
        return client
    }

    /// Initializes the FlagKit SDK with an API key.
    /// - Parameter apiKey: The API key.
    /// - Returns: The initialized client.
    @discardableResult
    public static func initialize(apiKey: String) async throws -> FlagKitClient {
        let options = FlagKitOptions(apiKey: apiKey)
        return try await initialize(options: options)
    }

    /// Whether the SDK is initialized.
    public static var isInitialized: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _instance != nil
    }

    /// Shuts down the SDK.
    public static func shutdown() async {
        lock.lock()
        let client = _instance
        _instance = nil
        lock.unlock()

        await client?.close()
    }

    // MARK: - Convenience Methods

    /// Gets a boolean flag value.
    public static func getBoolValue(_ key: String, default defaultValue: Bool) async -> Bool {
        guard let client = instance else { return defaultValue }
        return await client.getBoolValue(key, default: defaultValue)
    }

    /// Gets a string flag value.
    public static func getStringValue(_ key: String, default defaultValue: String) async -> String {
        guard let client = instance else { return defaultValue }
        return await client.getStringValue(key, default: defaultValue)
    }

    /// Gets a number flag value.
    public static func getNumberValue(_ key: String, default defaultValue: Double) async -> Double {
        guard let client = instance else { return defaultValue }
        return await client.getNumberValue(key, default: defaultValue)
    }

    /// Gets an integer flag value.
    public static func getIntValue(_ key: String, default defaultValue: Int) async -> Int {
        guard let client = instance else { return defaultValue }
        return await client.getIntValue(key, default: defaultValue)
    }

    /// Gets a JSON flag value.
    public static func getJsonValue(_ key: String, default defaultValue: [String: Any]) async -> [String: Any] {
        guard let client = instance else { return defaultValue }
        return await client.getJsonValue(key, default: defaultValue)
    }

    /// Evaluates a flag.
    public static func evaluate(_ key: String, defaultValue: FlagValue) async -> EvaluationResult {
        guard let client = instance else {
            return EvaluationResult.defaultResult(key: key, defaultValue: defaultValue, reason: .error)
        }
        return await client.evaluate(key: key, defaultValue: defaultValue)
    }

    /// Identifies a user.
    public static func identify(userId: String, attributes: [String: FlagValue] = [:]) async {
        await instance?.identify(userId: userId, attributes: attributes)
    }

    /// Resets the context.
    public static func resetContext() async {
        await instance?.resetContext()
    }

    /// Tracks an event.
    public static func track(_ eventType: String, data: [String: Any]? = nil) async {
        await instance?.track(eventType, data: data)
    }
}
