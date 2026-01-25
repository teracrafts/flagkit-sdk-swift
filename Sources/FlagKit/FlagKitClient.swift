import Foundation

/// The main FlagKit client for evaluating feature flags.
public actor FlagKitClient {
    /// SDK version identifier.
    public static let sdkVersion = "1.0.0"

    private let options: FlagKitOptions
    private let httpClient: HTTPClient
    private let circuitBreaker: CircuitBreaker
    private let cache: Cache<FlagState>
    private let contextManager: ContextManager
    private var pollingManager: PollingManager?
    private var eventQueue: EventQueue?
    private var isReady = false
    private var readyContinuation: CheckedContinuation<Void, Never>?
    private var initializationError: Error?
    private var lastUpdateTime: Date?
    private var sessionId: String

    /// Creates a new FlagKit client.
    /// - Parameter options: The client options.
    public init(options: FlagKitOptions) {
        self.options = options
        self.contextManager = ContextManager()
        self.sessionId = UUID().uuidString

        self.circuitBreaker = CircuitBreaker(
            failureThreshold: options.circuitBreakerThreshold,
            resetTimeout: options.circuitBreakerResetTimeout
        )

        self.httpClient = HTTPClient(
            apiKey: options.apiKey,
            secondaryApiKey: options.secondaryApiKey,
            timeout: options.timeout,
            retryAttempts: options.retryAttempts,
            circuitBreaker: circuitBreaker,
            localPort: options.localPort,
            enableRequestSigning: options.enableRequestSigning
        )

        self.cache = Cache(
            ttl: options.cacheTTL,
            maxSize: options.maxCacheSize
        )

        // PollingManager and EventQueue are initialized in initialize()
        // to avoid capturing self in closures before init completes
    }

    /// Initializes the SDK by fetching initial flag state.
    public func initialize() async throws {
        // Set up polling manager
        self.pollingManager = PollingManager(
            config: PollingConfig(interval: options.pollingInterval),
            onUpdate: { [weak self] lastUpdate in
                try await self?.pollForUpdates(since: lastUpdate)
            }
        )

        // Set up event queue if enabled
        if options.eventsEnabled {
            self.eventQueue = EventQueue(
                config: EventQueueConfig(
                    batchSize: options.eventBatchSize,
                    flushInterval: options.eventFlushInterval
                ),
                onFlush: { [weak self] events in
                    try await self?.sendEvents(events)
                }
            )
        }

        if let bootstrap = options.bootstrap {
            await loadBootstrap(bootstrap)
        }

        do {
            try await fetchInitialFlags()
            lastUpdateTime = Date()
        } catch {
            initializationError = error
            // Continue without initial flags - use cache/defaults
        }

        await startBackgroundTasks()
        markReady()

        // Track SDK initialized event
        await trackInternal(eventType: .sdkInitialized, data: [
            "sdkVersion": Self.sdkVersion,
            "platform": "swift"
        ])
    }

    /// Waits for the SDK to be ready.
    public func waitForReady() async {
        if isReady { return }

        await withCheckedContinuation { continuation in
            if isReady {
                continuation.resume()
            } else {
                readyContinuation = continuation
            }
        }
    }

    /// Whether the SDK is ready.
    public var ready: Bool {
        isReady
    }

    /// Whether the SDK initialized successfully (no errors during init).
    public var initializedSuccessfully: Bool {
        isReady && initializationError == nil
    }

    /// The error that occurred during initialization, if any.
    public func getInitializationError() -> Error? {
        initializationError
    }

    // MARK: - Context Management

    /// Sets the global context that applies to all evaluations.
    /// - Parameter context: The context to set.
    public func setContext(_ context: EvaluationContext) async {
        await contextManager.setContext(context)
        await trackInternal(eventType: .contextChanged, data: [
            "hasUserId": context.userId != nil
        ])
    }

    /// Gets the current global context.
    public func getContext() async -> EvaluationContext? {
        await contextManager.getContext()
    }

    /// Clears the global context.
    public func clearContext() async {
        await contextManager.clearContext()
    }

    /// Sets the user context (identifies a user).
    /// - Parameters:
    ///   - userId: The user identifier.
    ///   - attributes: Optional additional attributes.
    public func identify(userId: String, attributes: [String: FlagValue] = [:]) async {
        await contextManager.identify(userId: userId, attributes: attributes)
        await trackInternal(eventType: .identify, data: [
            "userId": userId
        ])
    }

    /// Resets to anonymous state.
    public func reset() async {
        await contextManager.reset()
    }

    /// Clears the user context (legacy method - calls clearContext).
    @available(*, deprecated, renamed: "clearContext")
    public func resetContext() async {
        await contextManager.reset()
    }

    // MARK: - Flag Evaluation

    /// Evaluates a flag and returns the full result.
    /// - Parameters:
    ///   - key: The flag key.
    ///   - defaultValue: The default value if evaluation fails.
    ///   - context: Optional per-evaluation context.
    /// - Returns: The evaluation result.
    public func evaluate(key: String, defaultValue: FlagValue, context override: EvaluationContext? = nil) async -> EvaluationResult {
        let effectiveContext = await contextManager.resolveContext(with: override)

        // Check cache first
        if options.cacheEnabled {
            if let cached = await cache.get(key) {
                return EvaluationResult(
                    flagKey: key,
                    value: cached.value,
                    enabled: cached.enabled,
                    reason: .cached,
                    version: cached.version
                )
            }

            // Check for stale value as fallback
            if await circuitBreaker.isOpen, let stale = await cache.getStaleValue(key) {
                return EvaluationResult(
                    flagKey: key,
                    value: stale.value,
                    enabled: stale.enabled,
                    reason: .stale,
                    version: stale.version
                )
            }
        }

        // Fetch from server
        do {
            var body: [String: Any] = ["flagKey": key]
            if let ctx = effectiveContext {
                body["context"] = ctx.toDictionary()
            }

            let response = try await httpClient.post("/sdk/evaluate", body: body)
            let flagState = try decodeFlagState(from: response)

            if options.cacheEnabled {
                await cache.set(flagState.key, value: flagState)
            }

            return EvaluationResult(
                flagKey: key,
                value: flagState.value,
                enabled: flagState.enabled,
                reason: .server,
                version: flagState.version
            )
        } catch {
            // Try stale cache as last resort
            if options.cacheEnabled, let stale = await cache.getStaleValue(key) {
                return EvaluationResult(
                    flagKey: key,
                    value: stale.value,
                    enabled: stale.enabled,
                    reason: .stale,
                    version: stale.version
                )
            }

            return EvaluationResult.defaultResult(key: key, defaultValue: defaultValue, reason: .error)
        }
    }

    /// Evaluates all flags and returns a dictionary of results.
    /// - Parameter context: Optional per-evaluation context.
    /// - Returns: Dictionary mapping flag keys to evaluation results.
    public func evaluateAll(context: EvaluationContext? = nil) async -> [String: EvaluationResult] {
        let effectiveContext = await contextManager.resolveContext(with: context)

        do {
            var body: [String: Any] = [:]
            if let ctx = effectiveContext {
                body["context"] = ctx.toDictionary()
            }

            let response = try await httpClient.post("/sdk/evaluate/all", body: body)

            guard let flagsData = response["flags"] as? [String: [String: Any]] else {
                // Return cached values as fallback
                return await getCachedEvaluations()
            }

            var results: [String: EvaluationResult] = [:]
            for (key, flagData) in flagsData {
                if let flagState = try? decodeFlagState(from: flagData) {
                    if options.cacheEnabled {
                        await cache.set(key, value: flagState)
                    }
                    results[key] = EvaluationResult(
                        flagKey: key,
                        value: flagState.value,
                        enabled: flagState.enabled,
                        reason: .server,
                        version: flagState.version
                    )
                }
            }

            return results
        } catch {
            // Return cached values as fallback
            return await getCachedEvaluations()
        }
    }

    /// Gets a boolean flag value.
    /// - Parameters:
    ///   - key: The flag key.
    ///   - defaultValue: The default value if evaluation fails.
    ///   - context: Optional per-evaluation context.
    /// - Returns: The boolean flag value.
    public func getBoolValue(_ key: String, default defaultValue: Bool, context: EvaluationContext? = nil) async -> Bool {
        let result = await evaluate(key: key, defaultValue: .bool(defaultValue), context: context)
        return result.boolValue
    }

    /// Gets a string flag value.
    /// - Parameters:
    ///   - key: The flag key.
    ///   - defaultValue: The default value if evaluation fails.
    ///   - context: Optional per-evaluation context.
    /// - Returns: The string flag value.
    public func getStringValue(_ key: String, default defaultValue: String, context: EvaluationContext? = nil) async -> String {
        let result = await evaluate(key: key, defaultValue: .string(defaultValue), context: context)
        return result.stringValue ?? defaultValue
    }

    /// Gets a number flag value.
    /// - Parameters:
    ///   - key: The flag key.
    ///   - defaultValue: The default value if evaluation fails.
    ///   - context: Optional per-evaluation context.
    /// - Returns: The number flag value.
    public func getNumberValue(_ key: String, default defaultValue: Double, context: EvaluationContext? = nil) async -> Double {
        let result = await evaluate(key: key, defaultValue: .double(defaultValue), context: context)
        return result.numberValue
    }

    /// Gets an integer flag value.
    /// - Parameters:
    ///   - key: The flag key.
    ///   - defaultValue: The default value if evaluation fails.
    ///   - context: Optional per-evaluation context.
    /// - Returns: The integer flag value.
    public func getIntValue(_ key: String, default defaultValue: Int, context: EvaluationContext? = nil) async -> Int {
        let result = await evaluate(key: key, defaultValue: .int(defaultValue), context: context)
        return result.intValue
    }

    /// Gets a JSON flag value.
    /// - Parameters:
    ///   - key: The flag key.
    ///   - defaultValue: The default value if evaluation fails.
    ///   - context: Optional per-evaluation context.
    /// - Returns: The JSON flag value as a dictionary.
    public func getJsonValue(_ key: String, default defaultValue: [String: Any], context: EvaluationContext? = nil) async -> [String: Any] {
        let result = await evaluate(key: key, defaultValue: .dictionary(defaultValue.mapValues { FlagValue.from($0) }), context: context)
        return result.jsonValue ?? defaultValue
    }

    // MARK: - Flag Metadata

    /// Checks if a flag exists in the cache.
    /// - Parameter key: The flag key.
    /// - Returns: True if the flag is known (cached).
    public func hasFlag(_ key: String) async -> Bool {
        // Check valid cache first
        if await cache.has(key) {
            return true
        }
        // Also check stale cache
        return await cache.getStaleValue(key) != nil
    }

    /// Gets all known flag keys from the cache.
    /// - Returns: Array of flag keys.
    public func getAllFlagKeys() async -> [String] {
        return await cache.getAllKeysIncludingStale()
    }

    /// Gets cache statistics.
    /// - Returns: Cache statistics including size, valid count, stale count.
    public func getCacheStats() async -> CacheStats {
        return await cache.getStats()
    }

    // MARK: - Refresh and Flush

    /// Forces a refresh of all flags from the server.
    /// - Throws: If the refresh fails.
    public func refresh() async throws {
        try await fetchInitialFlags()
        lastUpdateTime = Date()
    }

    /// Flushes all pending analytics events immediately.
    public func flush() async {
        await eventQueue?.flush()
    }

    // MARK: - Event Tracking

    /// Tracks a custom analytics event.
    /// - Parameters:
    ///   - eventType: The type of event.
    ///   - data: Optional event data.
    public func track(_ eventType: String, data: [String: Any]? = nil) async {
        guard options.eventsEnabled, let eventQueue = eventQueue else { return }

        let userId = await contextManager.userId
        let event = AnalyticsEvent(
            eventType: eventType,
            eventData: data,
            userId: userId,
            sessionId: sessionId,
            sdkVersion: Self.sdkVersion
        )

        await eventQueue.add(event)
    }

    // MARK: - Lifecycle

    /// Closes the client and releases resources.
    /// Flushes any pending events before closing.
    public func close() async {
        await pollingManager?.stop()
        await eventQueue?.stop()
        await cache.clear()
    }

    /// Pauses background tasks (polling and event flushing).
    public func pause() async {
        await pollingManager?.pause()
    }

    /// Resumes background tasks after pausing.
    public func resume() async {
        await pollingManager?.resume()
    }

    // MARK: - Private Methods

    private func markReady() {
        isReady = true
        readyContinuation?.resume()
        readyContinuation = nil
    }

    private func loadBootstrap(_ bootstrap: [String: Any]) async {
        guard let flags = bootstrap["flags"] as? [[String: Any]] else { return }

        for flagData in flags {
            if let flagState = try? decodeFlagState(from: flagData) {
                await cache.set(flagState.key, value: flagState)
            }
        }
    }

    private func fetchInitialFlags() async throws {
        let response = try await httpClient.get("/sdk/init")
        guard let flags = response["flags"] as? [[String: Any]] else { return }

        for flagData in flags {
            if let flagState = try? decodeFlagState(from: flagData) {
                await cache.set(flagState.key, value: flagState)
            }
        }
    }

    private func startBackgroundTasks() async {
        await pollingManager?.start()
        await eventQueue?.start()
    }

    private func pollForUpdates(since lastUpdate: Date?) async throws {
        var params: [String: String] = [:]
        if let lastUpdate = lastUpdate {
            params["since"] = ISO8601DateFormatter().string(from: lastUpdate)
        }

        let response = try await httpClient.get("/sdk/updates", params: params)
        guard let flags = response["flags"] as? [[String: Any]] else { return }

        for flagData in flags {
            if let flagState = try? decodeFlagState(from: flagData) {
                await cache.set(flagState.key, value: flagState)
            }
        }
    }

    private func sendEvents(_ events: [[String: Any]]) async throws {
        _ = try await httpClient.post("/sdk/events/batch", body: ["events": events])
    }

    private func decodeFlagState(from dict: [String: Any]) throws -> FlagState {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(FlagState.self, from: data)
    }

    private func trackInternal(eventType: EventType, data: [String: Any]? = nil) async {
        guard options.eventsEnabled, let eventQueue = eventQueue else { return }

        let userId = await contextManager.userId
        let event = AnalyticsEvent(
            eventType: eventType.rawValue,
            eventData: data,
            userId: userId,
            sessionId: sessionId,
            sdkVersion: Self.sdkVersion
        )

        await eventQueue.add(event)
    }

    private func getCachedEvaluations() async -> [String: EvaluationResult] {
        var results: [String: EvaluationResult] = [:]
        let cachedFlags = await cache.getAll()

        for flag in cachedFlags {
            results[flag.key] = EvaluationResult(
                flagKey: flag.key,
                value: flag.value,
                enabled: flag.enabled,
                reason: .cached,
                version: flag.version
            )
        }

        return results
    }
}

// MARK: - Static Factory Methods

extension FlagKitClient {
    /// Creates and initializes a FlagKit client.
    /// - Parameter options: The client options.
    /// - Returns: An initialized FlagKit client.
    /// - Throws: If initialization fails critically.
    public static func create(options: FlagKitOptions) async throws -> FlagKitClient {
        let client = FlagKitClient(options: options)
        try await client.initialize()
        return client
    }

    /// Creates and initializes a FlagKit client with a simple API key.
    /// - Parameter apiKey: The API key.
    /// - Returns: An initialized FlagKit client.
    /// - Throws: If initialization fails critically.
    public static func create(apiKey: String) async throws -> FlagKitClient {
        let options = FlagKitOptions(apiKey: apiKey)
        return try await create(options: options)
    }
}
