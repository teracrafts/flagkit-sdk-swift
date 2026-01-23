import Foundation

/// The main FlagKit client for evaluating feature flags.
public actor FlagKitClient {
    private let options: FlagKitOptions
    private let httpClient: HTTPClient
    private let circuitBreaker: CircuitBreaker
    private let cache: Cache<FlagState>
    private var pollingManager: PollingManager?
    private var eventQueue: EventQueue?
    private var context: EvaluationContext
    private var isReady = false
    private var readyContinuation: CheckedContinuation<Void, Never>?

    /// Creates a new FlagKit client.
    /// - Parameter options: The client options.
    public init(options: FlagKitOptions) {
        self.options = options
        self.context = EvaluationContext()

        self.circuitBreaker = CircuitBreaker(
            failureThreshold: options.circuitBreakerThreshold,
            resetTimeout: options.circuitBreakerResetTimeout
        )

        self.httpClient = HTTPClient(
            apiKey: options.apiKey,
            timeout: options.timeout,
            retryAttempts: options.retryAttempts,
            circuitBreaker: circuitBreaker,
            isLocal: options.isLocal
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
            interval: options.pollingInterval,
            onUpdate: { [weak self] lastUpdate in
                try await self?.pollForUpdates(since: lastUpdate)
            }
        )

        // Set up event queue if enabled
        if options.eventsEnabled {
            self.eventQueue = EventQueue(
                batchSize: options.eventBatchSize,
                flushInterval: options.eventFlushInterval,
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
        } catch {
            // Continue without initial flags
        }

        await startBackgroundTasks()
        markReady()
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

    /// Sets the user context.
    public func identify(userId: String, attributes: [String: FlagValue] = [:]) {
        context = EvaluationContext(userId: userId, attributes: attributes)
    }

    /// Clears the user context.
    public func resetContext() {
        context = EvaluationContext()
    }

    /// Gets the current context.
    public func getContext() -> EvaluationContext {
        context
    }

    /// Evaluates a flag and returns the full result.
    public func evaluate(key: String, defaultValue: FlagValue, context override: EvaluationContext? = nil) async -> EvaluationResult {
        let effectiveContext = context.merge(with: override)

        // Check cache first
        if options.cacheEnabled, let cached = await cache.get(key) {
            return EvaluationResult(
                flagKey: key,
                value: cached.value,
                enabled: cached.enabled,
                reason: .cached,
                version: cached.version
            )
        }

        // Fetch from server
        do {
            let body: [String: Any] = [
                "key": key,
                "context": effectiveContext.stripPrivateAttributes().toDictionary()
            ]

            let response = try await httpClient.post("/sdk/evaluate", body: body)
            let flagState = try decodeFlagState(from: response)

            if options.cacheEnabled {
                await cache.set(key, value: flagState)
            }

            return EvaluationResult(
                flagKey: key,
                value: flagState.value,
                enabled: flagState.enabled,
                reason: .server,
                version: flagState.version
            )
        } catch {
            return EvaluationResult.defaultResult(key: key, defaultValue: defaultValue, reason: .error)
        }
    }

    /// Gets a boolean flag value.
    public func getBoolValue(_ key: String, default defaultValue: Bool, context: EvaluationContext? = nil) async -> Bool {
        let result = await evaluate(key: key, defaultValue: .bool(defaultValue), context: context)
        return result.boolValue
    }

    /// Gets a string flag value.
    public func getStringValue(_ key: String, default defaultValue: String, context: EvaluationContext? = nil) async -> String {
        let result = await evaluate(key: key, defaultValue: .string(defaultValue), context: context)
        return result.stringValue ?? defaultValue
    }

    /// Gets a number flag value.
    public func getNumberValue(_ key: String, default defaultValue: Double, context: EvaluationContext? = nil) async -> Double {
        let result = await evaluate(key: key, defaultValue: .double(defaultValue), context: context)
        return result.numberValue
    }

    /// Gets an integer flag value.
    public func getIntValue(_ key: String, default defaultValue: Int, context: EvaluationContext? = nil) async -> Int {
        let result = await evaluate(key: key, defaultValue: .int(defaultValue), context: context)
        return result.intValue
    }

    /// Gets a JSON flag value.
    public func getJsonValue(_ key: String, default defaultValue: [String: Any], context: EvaluationContext? = nil) async -> [String: Any] {
        let result = await evaluate(key: key, defaultValue: .dictionary(defaultValue.mapValues { FlagValue.from($0) }), context: context)
        return result.jsonValue ?? defaultValue
    }

    /// Tracks an analytics event.
    public func track(_ eventType: String, data: [String: Any]? = nil) async {
        guard options.eventsEnabled, let eventQueue = eventQueue else { return }

        var event: [String: Any] = [
            "type": eventType,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        if let userId = context.userId {
            event["userId"] = userId
        }

        if let data = data {
            event["data"] = data
        }

        await eventQueue.enqueue(event)
    }

    /// Closes the client and releases resources.
    public func close() async {
        await pollingManager?.stop()
        await eventQueue?.stop()
        await cache.clear()
    }

    // MARK: - Private

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
}
