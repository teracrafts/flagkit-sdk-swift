import Foundation

/// Configuration options for the FlagKit SDK.
public struct FlagKitOptions: Sendable {
    /// Default base URL.
    public static let defaultBaseURL = "https://api.flagkit.dev/api/v1"

    /// Default polling interval in seconds.
    public static let defaultPollingInterval: TimeInterval = 30

    /// Default cache TTL in seconds.
    public static let defaultCacheTTL: TimeInterval = 300

    /// Default maximum cache size.
    public static let defaultMaxCacheSize = 1000

    /// Default event batch size.
    public static let defaultEventBatchSize = 10

    /// Default event flush interval in seconds.
    public static let defaultEventFlushInterval: TimeInterval = 30

    /// Default request timeout in seconds.
    public static let defaultTimeout: TimeInterval = 10

    /// Default number of retry attempts.
    public static let defaultRetryAttempts = 3

    /// Default circuit breaker threshold.
    public static let defaultCircuitBreakerThreshold = 5

    /// Default circuit breaker reset timeout in seconds.
    public static let defaultCircuitBreakerResetTimeout: TimeInterval = 30

    /// The API key.
    public let apiKey: String

    /// The base URL.
    public let baseURL: String

    /// Polling interval in seconds.
    public let pollingInterval: TimeInterval

    /// Cache TTL in seconds.
    public let cacheTTL: TimeInterval

    /// Maximum cache size.
    public let maxCacheSize: Int

    /// Whether caching is enabled.
    public let cacheEnabled: Bool

    /// Event batch size.
    public let eventBatchSize: Int

    /// Event flush interval in seconds.
    public let eventFlushInterval: TimeInterval

    /// Whether events are enabled.
    public let eventsEnabled: Bool

    /// Request timeout in seconds.
    public let timeout: TimeInterval

    /// Number of retry attempts.
    public let retryAttempts: Int

    /// Circuit breaker failure threshold.
    public let circuitBreakerThreshold: Int

    /// Circuit breaker reset timeout in seconds.
    public let circuitBreakerResetTimeout: TimeInterval

    /// Bootstrap data.
    public let bootstrap: [String: Any]?

    /// Creates new options.
    public init(
        apiKey: String,
        baseURL: String = defaultBaseURL,
        pollingInterval: TimeInterval = defaultPollingInterval,
        cacheTTL: TimeInterval = defaultCacheTTL,
        maxCacheSize: Int = defaultMaxCacheSize,
        cacheEnabled: Bool = true,
        eventBatchSize: Int = defaultEventBatchSize,
        eventFlushInterval: TimeInterval = defaultEventFlushInterval,
        eventsEnabled: Bool = true,
        timeout: TimeInterval = defaultTimeout,
        retryAttempts: Int = defaultRetryAttempts,
        circuitBreakerThreshold: Int = defaultCircuitBreakerThreshold,
        circuitBreakerResetTimeout: TimeInterval = defaultCircuitBreakerResetTimeout,
        bootstrap: [String: Any]? = nil
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.pollingInterval = pollingInterval
        self.cacheTTL = cacheTTL
        self.maxCacheSize = maxCacheSize
        self.cacheEnabled = cacheEnabled
        self.eventBatchSize = eventBatchSize
        self.eventFlushInterval = eventFlushInterval
        self.eventsEnabled = eventsEnabled
        self.timeout = timeout
        self.retryAttempts = retryAttempts
        self.circuitBreakerThreshold = circuitBreakerThreshold
        self.circuitBreakerResetTimeout = circuitBreakerResetTimeout
        self.bootstrap = bootstrap
    }

    /// Validates the options.
    public func validate() throws {
        guard !apiKey.isEmpty else {
            throw FlagKitError.configError(code: .configInvalidApiKey, message: "API key is required")
        }

        let validPrefixes = ["sdk_", "srv_", "cli_"]
        guard validPrefixes.contains(where: { apiKey.hasPrefix($0) }) else {
            throw FlagKitError.configError(code: .configInvalidApiKey, message: "Invalid API key format")
        }

        guard let url = URL(string: baseURL), url.scheme != nil, url.host != nil else {
            throw FlagKitError.configError(code: .configInvalidBaseUrl, message: "Invalid base URL")
        }

        guard pollingInterval > 0 else {
            throw FlagKitError.configError(code: .configInvalidPollingInterval, message: "Polling interval must be positive")
        }

        guard cacheTTL > 0 else {
            throw FlagKitError.configError(code: .configInvalidCacheTtl, message: "Cache TTL must be positive")
        }
    }
}

// MARK: - Builder

extension FlagKitOptions {
    /// A builder for creating options.
    public class Builder {
        private var apiKey: String
        private var baseURL: String = FlagKitOptions.defaultBaseURL
        private var pollingInterval: TimeInterval = FlagKitOptions.defaultPollingInterval
        private var cacheTTL: TimeInterval = FlagKitOptions.defaultCacheTTL
        private var maxCacheSize: Int = FlagKitOptions.defaultMaxCacheSize
        private var cacheEnabled: Bool = true
        private var eventBatchSize: Int = FlagKitOptions.defaultEventBatchSize
        private var eventFlushInterval: TimeInterval = FlagKitOptions.defaultEventFlushInterval
        private var eventsEnabled: Bool = true
        private var timeout: TimeInterval = FlagKitOptions.defaultTimeout
        private var retryAttempts: Int = FlagKitOptions.defaultRetryAttempts
        private var circuitBreakerThreshold: Int = FlagKitOptions.defaultCircuitBreakerThreshold
        private var circuitBreakerResetTimeout: TimeInterval = FlagKitOptions.defaultCircuitBreakerResetTimeout
        private var bootstrap: [String: Any]?

        public init(apiKey: String) {
            self.apiKey = apiKey
        }

        @discardableResult
        public func baseURL(_ url: String) -> Builder {
            self.baseURL = url
            return self
        }

        @discardableResult
        public func pollingInterval(_ interval: TimeInterval) -> Builder {
            self.pollingInterval = interval
            return self
        }

        @discardableResult
        public func cacheTTL(_ ttl: TimeInterval) -> Builder {
            self.cacheTTL = ttl
            return self
        }

        @discardableResult
        public func maxCacheSize(_ size: Int) -> Builder {
            self.maxCacheSize = size
            return self
        }

        @discardableResult
        public func cacheEnabled(_ enabled: Bool) -> Builder {
            self.cacheEnabled = enabled
            return self
        }

        @discardableResult
        public func eventBatchSize(_ size: Int) -> Builder {
            self.eventBatchSize = size
            return self
        }

        @discardableResult
        public func eventFlushInterval(_ interval: TimeInterval) -> Builder {
            self.eventFlushInterval = interval
            return self
        }

        @discardableResult
        public func eventsEnabled(_ enabled: Bool) -> Builder {
            self.eventsEnabled = enabled
            return self
        }

        @discardableResult
        public func timeout(_ timeout: TimeInterval) -> Builder {
            self.timeout = timeout
            return self
        }

        @discardableResult
        public func retryAttempts(_ attempts: Int) -> Builder {
            self.retryAttempts = attempts
            return self
        }

        @discardableResult
        public func bootstrap(_ data: [String: Any]) -> Builder {
            self.bootstrap = data
            return self
        }

        public func build() -> FlagKitOptions {
            FlagKitOptions(
                apiKey: apiKey,
                baseURL: baseURL,
                pollingInterval: pollingInterval,
                cacheTTL: cacheTTL,
                maxCacheSize: maxCacheSize,
                cacheEnabled: cacheEnabled,
                eventBatchSize: eventBatchSize,
                eventFlushInterval: eventFlushInterval,
                eventsEnabled: eventsEnabled,
                timeout: timeout,
                retryAttempts: retryAttempts,
                circuitBreakerThreshold: circuitBreakerThreshold,
                circuitBreakerResetTimeout: circuitBreakerResetTimeout,
                bootstrap: bootstrap
            )
        }
    }
}
