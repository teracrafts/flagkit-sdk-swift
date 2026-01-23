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

    // MARK: - Network errors
    case networkError = "NETWORK_ERROR"
    case networkTimeout = "NETWORK_TIMEOUT"
    case networkRetryLimit = "NETWORK_RETRY_LIMIT"

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

    /// Whether this error is recoverable.
    public var isRecoverable: Bool {
        switch self {
        case .networkError, .networkTimeout, .networkRetryLimit,
             .circuitOpen, .cacheExpired, .evalStaleValue,
             .evalCacheMiss, .evalNetworkError, .eventSendFailed:
            return true
        default:
            return false
        }
    }
}
