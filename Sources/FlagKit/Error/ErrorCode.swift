import Foundation

/// Error codes for FlagKit SDK errors.
public enum ErrorCode: String, Sendable {
    // MARK: - Initialization errors
    case initFailed = "INIT_FAILED"
    case initTimeout = "INIT_TIMEOUT"
    case initAlreadyInitialized = "INIT_ALREADY_INITIALIZED"
    case initNotInitialized = "INIT_NOT_INITIALIZED"

    // MARK: - Authentication errors
    case authInvalidKey = "AUTH_INVALID_KEY"
    case authExpiredKey = "AUTH_EXPIRED_KEY"
    case authMissingKey = "AUTH_MISSING_KEY"
    case authUnauthorized = "AUTH_UNAUTHORIZED"
    case authPermissionDenied = "AUTH_PERMISSION_DENIED"
    case authEnvironmentMismatch = "AUTH_ENVIRONMENT_MISMATCH"
    case authIPRestricted = "AUTH_IP_RESTRICTED"
    case authOrganizationRequired = "AUTH_ORGANIZATION_REQUIRED"
    case authSubscriptionSuspended = "AUTH_SUBSCRIPTION_SUSPENDED"

    // MARK: - Network errors
    case networkError = "NETWORK_ERROR"
    case networkTimeout = "NETWORK_TIMEOUT"
    case networkRetryLimit = "NETWORK_RETRY_LIMIT"
    case networkInvalidResponse = "NETWORK_INVALID_RESPONSE"
    case networkServiceUnavailable = "NETWORK_SERVICE_UNAVAILABLE"

    // MARK: - Evaluation errors
    case evalFlagNotFound = "EVAL_FLAG_NOT_FOUND"
    case evalTypeMismatch = "EVAL_TYPE_MISMATCH"
    case evalInvalidKey = "EVAL_INVALID_KEY"
    case evalInvalidValue = "EVAL_INVALID_VALUE"
    case evalDisabled = "EVAL_DISABLED"
    case evalError = "EVAL_ERROR"
    case evalContextError = "EVAL_CONTEXT_ERROR"
    case evalDefaultUsed = "EVAL_DEFAULT_USED"
    case evalStaleValue = "EVAL_STALE_VALUE"
    case evalCacheMiss = "EVAL_CACHE_MISS"
    case evalNetworkError = "EVAL_NETWORK_ERROR"
    case evalParseError = "EVAL_PARSE_ERROR"
    case evalTimeoutError = "EVAL_TIMEOUT_ERROR"

    // MARK: - Cache errors
    case cacheReadError = "CACHE_READ_ERROR"
    case cacheWriteError = "CACHE_WRITE_ERROR"
    case cacheInvalidData = "CACHE_INVALID_DATA"
    case cacheExpired = "CACHE_EXPIRED"
    case cacheStorageError = "CACHE_STORAGE_ERROR"

    // MARK: - Event errors
    case eventQueueFull = "EVENT_QUEUE_FULL"
    case eventInvalidType = "EVENT_INVALID_TYPE"
    case eventInvalidData = "EVENT_INVALID_DATA"
    case eventSendFailed = "EVENT_SEND_FAILED"
    case eventFlushFailed = "EVENT_FLUSH_FAILED"
    case eventFlushTimeout = "EVENT_FLUSH_TIMEOUT"

    // MARK: - Circuit breaker errors
    case circuitOpen = "CIRCUIT_OPEN"

    // MARK: - Configuration errors
    case configInvalidUrl = "CONFIG_INVALID_URL"
    case configInvalidInterval = "CONFIG_INVALID_INTERVAL"
    case configMissingRequired = "CONFIG_MISSING_REQUIRED"
    case configInvalidApiKey = "CONFIG_INVALID_API_KEY"
    case configInvalidBaseUrl = "CONFIG_INVALID_BASE_URL"
    case configInvalidPollingInterval = "CONFIG_INVALID_POLLING_INTERVAL"
    case configInvalidCacheTtl = "CONFIG_INVALID_CACHE_TTL"

    // MARK: - Streaming errors (1800-1899)
    case streamingTokenInvalid = "STREAMING_TOKEN_INVALID"
    case streamingTokenExpired = "STREAMING_TOKEN_EXPIRED"
    case streamingSubscriptionSuspended = "STREAMING_SUBSCRIPTION_SUSPENDED"
    case streamingConnectionLimit = "STREAMING_CONNECTION_LIMIT"
    case streamingUnavailable = "STREAMING_UNAVAILABLE"

    /// Whether this error is recoverable.
    public var isRecoverable: Bool {
        switch self {
        case .networkError, .networkTimeout, .networkRetryLimit,
             .networkServiceUnavailable,
             .circuitOpen, .cacheExpired, .evalStaleValue,
             .evalCacheMiss, .evalNetworkError, .eventSendFailed,
             .streamingTokenInvalid, .streamingTokenExpired,
             .streamingConnectionLimit, .streamingUnavailable:
            return true
        default:
            return false
        }
    }

    /// The numeric error code.
    public var numericCode: Int {
        switch self {
        // Initialization errors (1000-1099)
        case .initFailed: return 1000
        case .initTimeout: return 1001
        case .initAlreadyInitialized: return 1002
        case .initNotInitialized: return 1003

        // Authentication errors (1100-1199)
        case .authInvalidKey: return 1100
        case .authExpiredKey: return 1101
        case .authMissingKey: return 1102
        case .authUnauthorized: return 1103
        case .authPermissionDenied: return 1104
        case .authEnvironmentMismatch: return 1106
        case .authIPRestricted: return 1107
        case .authOrganizationRequired: return 1108
        case .authSubscriptionSuspended: return 1109

        // Network errors (1300-1399)
        case .networkError: return 1300
        case .networkTimeout: return 1301
        case .networkRetryLimit: return 1302
        case .networkInvalidResponse: return 1307
        case .networkServiceUnavailable: return 1308

        // Evaluation errors (1400-1499)
        case .evalFlagNotFound: return 1400
        case .evalTypeMismatch: return 1401
        case .evalInvalidKey: return 1402
        case .evalInvalidValue: return 1403
        case .evalDisabled: return 1404
        case .evalError: return 1405
        case .evalContextError: return 1406
        case .evalDefaultUsed: return 1407
        case .evalStaleValue: return 1408
        case .evalCacheMiss: return 1409
        case .evalNetworkError: return 1410
        case .evalParseError: return 1411
        case .evalTimeoutError: return 1412

        // Cache errors (1500-1599)
        case .cacheReadError: return 1500
        case .cacheWriteError: return 1501
        case .cacheInvalidData: return 1502
        case .cacheExpired: return 1503
        case .cacheStorageError: return 1504

        // Event errors (1600-1699)
        case .eventQueueFull: return 1600
        case .eventInvalidType: return 1601
        case .eventInvalidData: return 1602
        case .eventSendFailed: return 1603
        case .eventFlushFailed: return 1604
        case .eventFlushTimeout: return 1605

        // Circuit breaker errors (1700-1799)
        case .circuitOpen: return 1700

        // Configuration errors (1200-1299)
        case .configInvalidUrl: return 1200
        case .configInvalidInterval: return 1201
        case .configMissingRequired: return 1202
        case .configInvalidApiKey: return 1203
        case .configInvalidBaseUrl: return 1204
        case .configInvalidPollingInterval: return 1205
        case .configInvalidCacheTtl: return 1206

        // Streaming errors (1800-1899)
        case .streamingTokenInvalid: return 1800
        case .streamingTokenExpired: return 1801
        case .streamingSubscriptionSuspended: return 1802
        case .streamingConnectionLimit: return 1803
        case .streamingUnavailable: return 1804
        }
    }

    /// Human-readable error message.
    public var message: String {
        switch self {
        // Initialization errors
        case .initFailed: return "SDK initialization failed"
        case .initTimeout: return "SDK initialization timed out"
        case .initAlreadyInitialized: return "SDK is already initialized"
        case .initNotInitialized: return "SDK is not initialized"

        // Authentication errors
        case .authInvalidKey: return "Invalid API key"
        case .authExpiredKey: return "API key has expired"
        case .authMissingKey: return "API key is missing"
        case .authUnauthorized: return "Unauthorized access"
        case .authPermissionDenied: return "Permission denied"
        case .authEnvironmentMismatch: return "Environment mismatch for API key"
        case .authIPRestricted: return "IP address not allowed for this API key"
        case .authOrganizationRequired: return "Organization context missing from token"
        case .authSubscriptionSuspended: return "Subscription is suspended"

        // Network errors
        case .networkError: return "Network error occurred"
        case .networkTimeout: return "Network request timed out"
        case .networkRetryLimit: return "Maximum retry attempts exceeded"
        case .networkInvalidResponse: return "Invalid response from server"
        case .networkServiceUnavailable: return "Service unavailable"

        // Evaluation errors
        case .evalFlagNotFound: return "Flag not found"
        case .evalTypeMismatch: return "Flag type mismatch"
        case .evalInvalidKey: return "Invalid flag key"
        case .evalInvalidValue: return "Invalid flag value"
        case .evalDisabled: return "Flag is disabled"
        case .evalError: return "Flag evaluation error"
        case .evalContextError: return "Evaluation context error"
        case .evalDefaultUsed: return "Default value used"
        case .evalStaleValue: return "Stale value returned"
        case .evalCacheMiss: return "Cache miss during evaluation"
        case .evalNetworkError: return "Network error during evaluation"
        case .evalParseError: return "Parse error during evaluation"
        case .evalTimeoutError: return "Timeout during evaluation"

        // Cache errors
        case .cacheReadError: return "Failed to read from cache"
        case .cacheWriteError: return "Failed to write to cache"
        case .cacheInvalidData: return "Invalid cache data"
        case .cacheExpired: return "Cache has expired"
        case .cacheStorageError: return "Cache storage error"

        // Event errors
        case .eventQueueFull: return "Event queue is full"
        case .eventInvalidType: return "Invalid event type"
        case .eventInvalidData: return "Invalid event data"
        case .eventSendFailed: return "Failed to send event"
        case .eventFlushFailed: return "Failed to flush events"
        case .eventFlushTimeout: return "Event flush timed out"

        // Circuit breaker errors
        case .circuitOpen: return "Circuit breaker is open"

        // Configuration errors
        case .configInvalidUrl: return "Invalid URL configuration"
        case .configInvalidInterval: return "Invalid interval configuration"
        case .configMissingRequired: return "Missing required configuration"
        case .configInvalidApiKey: return "Invalid API key configuration"
        case .configInvalidBaseUrl: return "Invalid base URL configuration"
        case .configInvalidPollingInterval: return "Invalid polling interval configuration"
        case .configInvalidCacheTtl: return "Invalid cache TTL configuration"

        // Streaming errors
        case .streamingTokenInvalid: return "Stream token is invalid"
        case .streamingTokenExpired: return "Stream token has expired"
        case .streamingSubscriptionSuspended: return "Organization subscription suspended"
        case .streamingConnectionLimit: return "Too many concurrent streaming connections"
        case .streamingUnavailable: return "Streaming service not available"
        }
    }
}
