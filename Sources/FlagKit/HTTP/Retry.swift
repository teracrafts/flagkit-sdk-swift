import Foundation

/// Configuration for retry behavior.
public struct RetryConfig: Sendable {
    /// Maximum number of retry attempts. Default: 3.
    public let maxAttempts: Int

    /// Base delay in seconds. Default: 1.0.
    public let baseDelay: TimeInterval

    /// Maximum delay in seconds (cap for exponential backoff). Default: 30.0.
    public let maxDelay: TimeInterval

    /// Backoff multiplier. Default: 2.0.
    public let backoffMultiplier: Double

    /// Maximum jitter in seconds (random variation). Default: 0.1.
    public let jitter: TimeInterval

    /// Default retry configuration.
    public static let `default` = RetryConfig()

    /// Creates retry configuration.
    public init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        backoffMultiplier: Double = 2.0,
        jitter: TimeInterval = 0.1
    ) {
        self.maxAttempts = max(1, maxAttempts)
        self.baseDelay = max(0, baseDelay)
        self.maxDelay = max(baseDelay, maxDelay)
        self.backoffMultiplier = max(1.0, backoffMultiplier)
        self.jitter = max(0, jitter)
    }
}

/// Result of a retry operation.
public struct RetryResult<T: Sendable>: Sendable {
    /// Whether the operation succeeded.
    public let success: Bool

    /// The successful result value.
    public let value: T?

    /// The error if the operation failed.
    public let error: Error?

    /// Number of attempts made.
    public let attempts: Int

    /// Total time spent including delays.
    public let totalDuration: TimeInterval

    /// Creates a successful result.
    public static func success(_ value: T, attempts: Int, duration: TimeInterval) -> RetryResult {
        return RetryResult(success: true, value: value, error: nil, attempts: attempts, totalDuration: duration)
    }

    /// Creates a failed result.
    public static func failure(_ error: Error, attempts: Int, duration: TimeInterval) -> RetryResult {
        return RetryResult(success: false, value: nil, error: error, attempts: attempts, totalDuration: duration)
    }
}

/// Retry utilities for handling transient failures.
public enum Retry {
    /// Calculates the backoff delay for a given attempt.
    /// - Parameters:
    ///   - attempt: The attempt number (1-based).
    ///   - config: The retry configuration.
    /// - Returns: The delay in seconds before the next retry.
    public static func calculateBackoff(attempt: Int, config: RetryConfig = .default) -> TimeInterval {
        // Exponential backoff: baseDelay * (multiplier ^ (attempt - 1))
        let exponentialDelay = config.baseDelay * pow(config.backoffMultiplier, Double(attempt - 1))

        // Cap at maxDelay
        let cappedDelay = min(exponentialDelay, config.maxDelay)

        // Add jitter to prevent thundering herd
        let jitter = Double.random(in: 0...config.jitter)

        return cappedDelay + jitter
    }

    /// Sleeps for the specified duration.
    /// - Parameter duration: The duration in seconds.
    public static func sleep(_ duration: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }

    /// Executes an operation with retry logic.
    /// - Parameters:
    ///   - config: The retry configuration.
    ///   - shouldRetry: Optional predicate to determine if an error is retryable.
    ///   - onRetry: Optional callback called before each retry.
    ///   - operation: The operation to execute.
    /// - Returns: The result of the operation.
    /// - Throws: The last error if all retries fail.
    public static func withRetry<T: Sendable>(
        config: RetryConfig = .default,
        shouldRetry: ((Error) -> Bool)? = nil,
        onRetry: ((Int, Error, TimeInterval) async -> Void)? = nil,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...config.maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error

                // Check if we should retry
                let canRetry = shouldRetry?(error) ?? isRetryableError(error)

                if !canRetry {
                    throw error
                }

                // Check if we've exhausted retries
                if attempt >= config.maxAttempts {
                    throw error
                }

                // Calculate and apply backoff
                let delay = calculateBackoff(attempt: attempt, config: config)

                // Call onRetry callback if provided
                await onRetry?(attempt, error, delay)

                // Wait before retrying
                try? await sleep(delay)
            }
        }

        // This should never be reached, but TypeScript needs it
        throw lastError ?? FlagKitError(code: .networkError, message: "Retry failed")
    }

    /// Executes an operation with retry logic and returns a result.
    /// Does not throw; instead returns a result indicating success or failure.
    /// - Parameters:
    ///   - config: The retry configuration.
    ///   - shouldRetry: Optional predicate to determine if an error is retryable.
    ///   - operation: The operation to execute.
    /// - Returns: A RetryResult containing the outcome.
    public static func withRetryResult<T: Sendable>(
        config: RetryConfig = .default,
        shouldRetry: ((Error) -> Bool)? = nil,
        operation: @Sendable () async throws -> T
    ) async -> RetryResult<T> {
        let startTime = Date()
        var attempts = 0
        var lastError: Error?

        for attempt in 1...config.maxAttempts {
            attempts = attempt
            do {
                let result = try await operation()
                let duration = Date().timeIntervalSince(startTime)
                return .success(result, attempts: attempts, duration: duration)
            } catch {
                lastError = error

                // Check if we should retry
                let canRetry = shouldRetry?(error) ?? isRetryableError(error)

                if !canRetry || attempt >= config.maxAttempts {
                    break
                }

                // Calculate and apply backoff
                let delay = calculateBackoff(attempt: attempt, config: config)
                try? await sleep(delay)
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        return .failure(lastError ?? FlagKitError(code: .networkError, message: "Retry failed"), attempts: attempts, duration: duration)
    }

    /// Determines if an error is retryable.
    /// - Parameter error: The error to check.
    /// - Returns: True if the error is retryable.
    public static func isRetryableError(_ error: Error) -> Bool {
        if let flagKitError = error as? FlagKitError {
            return flagKitError.isRecoverable
        }

        // URLSession errors that are typically retryable
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .notConnectedToInternet,
                 .dnsLookupFailed,
                 .httpTooManyRedirects,
                 .resourceUnavailable,
                 .secureConnectionFailed:
                return true
            default:
                return false
            }
        }

        // Generic network errors
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return true
        }

        return false
    }

    /// Parses a Retry-After header value.
    /// Can be either a number of seconds or an HTTP date.
    /// - Parameter value: The header value.
    /// - Returns: The delay in seconds, or nil if parsing fails.
    public static func parseRetryAfter(_ value: String?) -> TimeInterval? {
        guard let value = value else { return nil }

        // Try parsing as number of seconds
        if let seconds = Double(value), seconds > 0 {
            return seconds
        }

        // Try parsing as HTTP date (RFC 7231)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")

        // HTTP date formats
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss zzz",  // IMF-fixdate
            "EEEE, dd-MMM-yy HH:mm:ss zzz",   // RFC 850
            "EEE MMM d HH:mm:ss yyyy"          // ANSI C's asctime()
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                let retryAt = date.timeIntervalSince1970
                let now = Date().timeIntervalSince1970
                if retryAt > now {
                    return retryAt - now
                }
            }
        }

        return nil
    }
}

// MARK: - Async Retry Extensions

extension Retry {
    /// Executes an async operation with a simple retry count.
    /// - Parameters:
    ///   - times: Number of retry attempts.
    ///   - delay: Delay between retries in seconds.
    ///   - operation: The operation to execute.
    /// - Returns: The result of the operation.
    public static func retry<T: Sendable>(
        times: Int,
        delay: TimeInterval = 1.0,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        let config = RetryConfig(
            maxAttempts: times,
            baseDelay: delay,
            maxDelay: delay,
            backoffMultiplier: 1.0,
            jitter: 0
        )
        return try await withRetry(config: config, operation: operation)
    }

    /// Executes an async operation with exponential backoff.
    /// - Parameters:
    ///   - maxAttempts: Maximum number of attempts.
    ///   - operation: The operation to execute.
    /// - Returns: The result of the operation.
    public static func exponentialBackoff<T: Sendable>(
        maxAttempts: Int = 3,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        return try await withRetry(config: RetryConfig(maxAttempts: maxAttempts), operation: operation)
    }
}
