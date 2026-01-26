import Foundation

// MARK: - Bootstrap Configuration

/// Bootstrap configuration with optional signature verification.
public struct BootstrapConfig: @unchecked Sendable {
    /// The flag data to bootstrap.
    public let flags: [String: Any]

    /// Optional HMAC-SHA256 signature for verification.
    public let signature: String?

    /// Optional timestamp (milliseconds since epoch) for freshness verification.
    public let timestamp: Int64?

    /// Creates a new bootstrap configuration.
    /// - Parameters:
    ///   - flags: The flag data to bootstrap.
    ///   - signature: Optional HMAC-SHA256 signature for verification.
    ///   - timestamp: Optional timestamp for freshness verification.
    public init(flags: [String: Any], signature: String? = nil, timestamp: Int64? = nil) {
        self.flags = flags
        self.signature = signature
        self.timestamp = timestamp
    }
}

/// Configuration for bootstrap signature verification.
public struct BootstrapVerificationConfig: Sendable {
    /// Whether verification is enabled.
    public let enabled: Bool

    /// Maximum age of bootstrap data in milliseconds (default: 24 hours).
    public let maxAge: Int64

    /// Action to take on verification failure: "warn", "error", or "ignore".
    public let onFailure: BootstrapVerificationFailureAction

    /// Creates a new bootstrap verification configuration.
    /// - Parameters:
    ///   - enabled: Whether verification is enabled (default: true).
    ///   - maxAge: Maximum age in milliseconds (default: 86400000 = 24 hours).
    ///   - onFailure: Action on failure (default: .warn).
    public init(
        enabled: Bool = true,
        maxAge: Int64 = 86_400_000,
        onFailure: BootstrapVerificationFailureAction = .warn
    ) {
        self.enabled = enabled
        self.maxAge = maxAge
        self.onFailure = onFailure
    }
}

/// Action to take when bootstrap verification fails.
public enum BootstrapVerificationFailureAction: String, Sendable {
    /// Log a warning but continue loading bootstrap data.
    case warn
    /// Throw an error and reject the bootstrap data.
    case error
    /// Silently ignore the failure and load bootstrap data anyway.
    case ignore
}

/// Result of bootstrap verification.
public struct BootstrapVerificationResult: Sendable {
    /// Whether the verification passed.
    public let valid: Bool

    /// Error message if verification failed.
    public let error: String?

    /// Creates a successful verification result.
    public static let success = BootstrapVerificationResult(valid: true, error: nil)

    /// Creates a failed verification result.
    /// - Parameter error: The error message.
    public static func failure(_ error: String) -> BootstrapVerificationResult {
        BootstrapVerificationResult(valid: false, error: error)
    }

    private init(valid: Bool, error: String?) {
        self.valid = valid
        self.error = error
    }
}

// MARK: - Evaluation Jitter Configuration

/// Configuration for evaluation jitter to protect against cache timing attacks.
public struct EvaluationJitterConfig: Sendable {
    /// Whether evaluation jitter is enabled.
    public let enabled: Bool

    /// Minimum jitter delay in milliseconds.
    public let minMs: Int

    /// Maximum jitter delay in milliseconds.
    public let maxMs: Int

    /// Creates a new evaluation jitter configuration.
    /// - Parameters:
    ///   - enabled: Whether jitter is enabled (default: false).
    ///   - minMs: Minimum jitter delay in milliseconds (default: 5).
    ///   - maxMs: Maximum jitter delay in milliseconds (default: 15).
    public init(enabled: Bool = false, minMs: Int = 5, maxMs: Int = 15) {
        self.enabled = enabled
        self.minMs = minMs
        self.maxMs = maxMs
    }
}

/// Configuration options for the FlagKit SDK.
public struct FlagKitOptions: Sendable {
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

    /// Default maximum persisted events.
    public static let defaultMaxPersistedEvents = 10000

    /// Default persistence flush interval in seconds.
    public static let defaultPersistenceFlushInterval: TimeInterval = 1.0

    /// The API key.
    public let apiKey: String

    /// Secondary API key for key rotation. Automatically used on 401 errors.
    public let secondaryApiKey: String?

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

    /// Local development server port. When set, uses http://localhost:{port}/api/v1.
    public let localPort: Int?

    /// Strict PII mode: throws SecurityError instead of warning when PII is detected.
    public let strictPIIMode: Bool

    /// Enable request signing for POST requests using HMAC-SHA256.
    public let enableRequestSigning: Bool

    /// Enable cache encryption using AES-GCM.
    public let enableCacheEncryption: Bool

    /// Enable crash-resilient event persistence.
    public let persistEvents: Bool

    /// Directory path for event storage. If nil, uses OS temp directory.
    public let eventStoragePath: String?

    /// Maximum number of events to persist.
    public let maxPersistedEvents: Int

    /// Interval between disk flushes in seconds.
    public let persistenceFlushInterval: TimeInterval

    /// Evaluation jitter configuration for cache timing attack protection.
    public let evaluationJitter: EvaluationJitterConfig

    /// Bootstrap verification configuration for signature and freshness validation.
    public let bootstrapVerification: BootstrapVerificationConfig

    /// Error sanitization configuration to remove sensitive information from error messages.
    public let errorSanitization: ErrorSanitizationConfig

    /// Creates new options.
    public init(
        apiKey: String,
        secondaryApiKey: String? = nil,
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
        bootstrap: [String: Any]? = nil,
        localPort: Int? = nil,
        strictPIIMode: Bool = false,
        enableRequestSigning: Bool = false,
        enableCacheEncryption: Bool = false,
        persistEvents: Bool = false,
        eventStoragePath: String? = nil,
        maxPersistedEvents: Int = defaultMaxPersistedEvents,
        persistenceFlushInterval: TimeInterval = defaultPersistenceFlushInterval,
        evaluationJitter: EvaluationJitterConfig = EvaluationJitterConfig(),
        bootstrapVerification: BootstrapVerificationConfig = BootstrapVerificationConfig(enabled: false),
        errorSanitization: ErrorSanitizationConfig = ErrorSanitizationConfig()
    ) {
        self.apiKey = apiKey
        self.secondaryApiKey = secondaryApiKey
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
        self.localPort = localPort
        self.strictPIIMode = strictPIIMode
        self.enableRequestSigning = enableRequestSigning
        self.enableCacheEncryption = enableCacheEncryption
        self.persistEvents = persistEvents
        self.eventStoragePath = eventStoragePath
        self.maxPersistedEvents = maxPersistedEvents
        self.persistenceFlushInterval = persistenceFlushInterval
        self.evaluationJitter = evaluationJitter
        self.bootstrapVerification = bootstrapVerification
        self.errorSanitization = errorSanitization
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

        // Validate secondary API key format if provided
        if let secondaryKey = secondaryApiKey, !secondaryKey.isEmpty {
            guard validPrefixes.contains(where: { secondaryKey.hasPrefix($0) }) else {
                throw FlagKitError.configError(code: .configInvalidApiKey, message: "Invalid secondary API key format")
            }
        }

        guard pollingInterval > 0 else {
            throw FlagKitError.configError(code: .configInvalidPollingInterval, message: "Polling interval must be positive")
        }

        guard cacheTTL > 0 else {
            throw FlagKitError.configError(code: .configInvalidCacheTtl, message: "Cache TTL must be positive")
        }

        // Validate localPort restriction in production
        try validateLocalPortRestriction(localPort: localPort)
    }
}

// MARK: - Builder

extension FlagKitOptions {
    /// A builder for creating options.
    public class Builder {
        private var apiKey: String
        private var secondaryApiKey: String?
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
        private var localPort: Int?
        private var strictPIIMode: Bool = false
        private var enableRequestSigning: Bool = false
        private var enableCacheEncryption: Bool = false
        private var persistEvents: Bool = false
        private var eventStoragePath: String?
        private var maxPersistedEvents: Int = FlagKitOptions.defaultMaxPersistedEvents
        private var persistenceFlushInterval: TimeInterval = FlagKitOptions.defaultPersistenceFlushInterval
        private var evaluationJitter: EvaluationJitterConfig = EvaluationJitterConfig()
        private var bootstrapVerification: BootstrapVerificationConfig = BootstrapVerificationConfig(enabled: false)
        private var errorSanitization: ErrorSanitizationConfig = ErrorSanitizationConfig()

        public init(apiKey: String) {
            self.apiKey = apiKey
        }

        @discardableResult
        public func secondaryApiKey(_ key: String) -> Builder {
            self.secondaryApiKey = key
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

        @discardableResult
        public func localPort(_ port: Int) -> Builder {
            self.localPort = port
            return self
        }

        @discardableResult
        public func strictPIIMode(_ enabled: Bool) -> Builder {
            self.strictPIIMode = enabled
            return self
        }

        @discardableResult
        public func enableRequestSigning(_ enabled: Bool) -> Builder {
            self.enableRequestSigning = enabled
            return self
        }

        @discardableResult
        public func enableCacheEncryption(_ enabled: Bool) -> Builder {
            self.enableCacheEncryption = enabled
            return self
        }

        @discardableResult
        public func persistEvents(_ enabled: Bool) -> Builder {
            self.persistEvents = enabled
            return self
        }

        @discardableResult
        public func eventStoragePath(_ path: String) -> Builder {
            self.eventStoragePath = path
            return self
        }

        @discardableResult
        public func maxPersistedEvents(_ max: Int) -> Builder {
            self.maxPersistedEvents = max
            return self
        }

        @discardableResult
        public func persistenceFlushInterval(_ interval: TimeInterval) -> Builder {
            self.persistenceFlushInterval = interval
            return self
        }

        @discardableResult
        public func evaluationJitter(_ config: EvaluationJitterConfig) -> Builder {
            self.evaluationJitter = config
            return self
        }

        @discardableResult
        public func bootstrapVerification(_ config: BootstrapVerificationConfig) -> Builder {
            self.bootstrapVerification = config
            return self
        }

        @discardableResult
        public func errorSanitization(_ config: ErrorSanitizationConfig) -> Builder {
            self.errorSanitization = config
            return self
        }

        public func build() -> FlagKitOptions {
            FlagKitOptions(
                apiKey: apiKey,
                secondaryApiKey: secondaryApiKey,
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
                bootstrap: bootstrap,
                localPort: localPort,
                strictPIIMode: strictPIIMode,
                enableRequestSigning: enableRequestSigning,
                enableCacheEncryption: enableCacheEncryption,
                persistEvents: persistEvents,
                eventStoragePath: eventStoragePath,
                maxPersistedEvents: maxPersistedEvents,
                persistenceFlushInterval: persistenceFlushInterval,
                evaluationJitter: evaluationJitter,
                bootstrapVerification: bootstrapVerification,
                errorSanitization: errorSanitization
            )
        }
    }
}
