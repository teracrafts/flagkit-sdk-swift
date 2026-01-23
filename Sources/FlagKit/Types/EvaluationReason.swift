import Foundation

/// Reasons for flag evaluation results.
public enum EvaluationReason: String, Codable, Sendable {
    case cached = "CACHED"
    case `default` = "DEFAULT"
    case flagNotFound = "FLAG_NOT_FOUND"
    case bootstrap = "BOOTSTRAP"
    case server = "SERVER"
    case staleCache = "STALE_CACHE"
    case error = "ERROR"
    case disabled = "DISABLED"
    case typeMismatch = "TYPE_MISMATCH"
    case offline = "OFFLINE"
}
