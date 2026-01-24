import Foundation

/// Reasons for flag evaluation results as defined in the FlagKit SDK spec.
public enum EvaluationReason: String, Codable, Sendable {
    // MARK: - Success Reasons

    /// Flag value was returned from cache.
    case cached = "CACHED"

    /// Flag value was returned from server evaluation.
    case server = "SERVER"

    /// Default targeting rule matched (fallthrough).
    case `fallthrough` = "FALLTHROUGH"

    /// A targeting rule matched.
    case ruleMatch = "RULE_MATCH"

    /// User is in a matched segment.
    case segmentMatch = "SEGMENT_MATCH"

    /// Flag value was returned from bootstrap data.
    case bootstrap = "BOOTSTRAP"

    // MARK: - Fallback Reasons

    /// Returned default value provided by caller.
    case `default` = "DEFAULT"

    /// Stale cached value was used as fallback.
    case stale = "STALE"

    /// Legacy alias for stale.
    case staleCache = "STALE_CACHE"

    /// Value returned while offline.
    case offline = "OFFLINE"

    // MARK: - Error Reasons

    /// Flag does not exist.
    case flagNotFound = "FLAG_NOT_FOUND"

    /// Flag is disabled in this environment.
    case flagDisabled = "FLAG_DISABLED"

    /// Legacy alias for flag disabled.
    case disabled = "DISABLED"

    /// No environment configuration exists.
    case environmentNotConfigured = "ENVIRONMENT_NOT_CONFIGURED"

    /// Error during evaluation.
    case evaluationError = "EVALUATION_ERROR"

    /// Generic error occurred.
    case error = "ERROR"

    /// Type mismatch between expected and actual value.
    case typeMismatch = "TYPE_MISMATCH"

    /// Whether this reason indicates a successful evaluation.
    public var isSuccess: Bool {
        switch self {
        case .cached, .server, .`fallthrough`, .ruleMatch, .segmentMatch, .bootstrap:
            return true
        default:
            return false
        }
    }

    /// Whether this reason indicates a fallback was used.
    public var isFallback: Bool {
        switch self {
        case .default, .stale, .staleCache, .offline:
            return true
        default:
            return false
        }
    }

    /// Whether this reason indicates an error occurred.
    public var isError: Bool {
        switch self {
        case .flagNotFound, .flagDisabled, .disabled, .environmentNotConfigured, .evaluationError, .error, .typeMismatch:
            return true
        default:
            return false
        }
    }
}
