import Foundation

// MARK: - Usage Metrics

/// Usage metrics extracted from response headers.
public struct UsageMetrics: Sendable {
    /// Percentage of API call limit used this period (0-150+).
    public let apiUsagePercent: Double?

    /// Percentage of evaluation limit used (0-150+).
    public let evaluationUsagePercent: Double?

    /// Whether approaching rate limit threshold.
    public let rateLimitWarning: Bool

    /// Current subscription status.
    public let subscriptionStatus: SubscriptionStatus?

    public init(
        apiUsagePercent: Double? = nil,
        evaluationUsagePercent: Double? = nil,
        rateLimitWarning: Bool = false,
        subscriptionStatus: SubscriptionStatus? = nil
    ) {
        self.apiUsagePercent = apiUsagePercent
        self.evaluationUsagePercent = evaluationUsagePercent
        self.rateLimitWarning = rateLimitWarning
        self.subscriptionStatus = subscriptionStatus
    }
}

/// Subscription status values.
public enum SubscriptionStatus: String, Sendable {
    case active
    case trial
    case pastDue = "past_due"
    case suspended
    case cancelled
}

/// Usage update callback type.
public typealias UsageUpdateCallback = @Sendable (UsageMetrics) -> Void

/// HTTP client with retry logic and circuit breaker integration.
actor HTTPClient {
    /// The base URL for the FlagKit API.
    static let baseURL = "https://api.flagkit.dev/api/v1"

    /// Returns the base URL for the given local port, or the default production URL.
    static func getBaseUrl(localPort: Int?) -> String {
        if let port = localPort {
            return "http://localhost:\(port)/api/v1"
        }
        return baseURL
    }

    private static let baseRetryDelay: TimeInterval = 1.0
    private static let maxRetryDelay: TimeInterval = 30.0
    private static let retryMultiplier: Double = 2.0
    private static let jitterFactor: Double = 0.1

    private var currentApiKey: String
    private let primaryApiKey: String
    private let secondaryApiKey: String?
    private let timeout: TimeInterval
    private let retryAttempts: Int
    private let circuitBreaker: CircuitBreaker
    private let session: URLSession
    private let localPort: Int?
    private let enableRequestSigning: Bool
    private var hasFailedOverToSecondary: Bool = false
    private let onUsageUpdate: UsageUpdateCallback?
    private let logger: Logger?

    init(
        apiKey: String,
        secondaryApiKey: String? = nil,
        timeout: TimeInterval,
        retryAttempts: Int,
        circuitBreaker: CircuitBreaker,
        localPort: Int? = nil,
        enableRequestSigning: Bool = false,
        onUsageUpdate: UsageUpdateCallback? = nil,
        logger: Logger? = nil
    ) {
        self.primaryApiKey = apiKey
        self.currentApiKey = apiKey
        self.secondaryApiKey = secondaryApiKey
        self.timeout = timeout
        self.retryAttempts = retryAttempts
        self.circuitBreaker = circuitBreaker
        self.localPort = localPort
        self.enableRequestSigning = enableRequestSigning
        self.onUsageUpdate = onUsageUpdate
        self.logger = logger

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        self.session = URLSession(configuration: config)
    }

    /// Returns the currently active API key.
    var activeApiKey: String {
        currentApiKey
    }

    /// Returns whether the client has failed over to the secondary key.
    var isUsingSecondaryKey: Bool {
        hasFailedOverToSecondary
    }

    /// Resets to use the primary API key.
    func resetToPrimaryKey() {
        currentApiKey = primaryApiKey
        hasFailedOverToSecondary = false
    }

    /// Makes a GET request.
    func get(_ path: String, params: [String: String] = [:]) async throws -> [String: Any] {
        try await request(.get, path: path, params: params)
    }

    /// Makes a POST request.
    func post(_ path: String, body: [String: Any] = [:]) async throws -> [String: Any] {
        try await request(.post, path: path, body: body)
    }

    private enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
    }

    private func request(
        _ method: HTTPMethod,
        path: String,
        params: [String: String]? = nil,
        body: [String: Any]? = nil
    ) async throws -> [String: Any] {
        guard await circuitBreaker.allowRequest() else {
            throw FlagKitError(code: .circuitOpen, message: "Circuit breaker is open")
        }

        var attempts = 0
        var lastError: Error?

        while attempts < retryAttempts {
            attempts += 1

            do {
                let result = try await executeRequest(method, path: path, params: params, body: body)
                await circuitBreaker.recordSuccess()
                return result
            } catch let error as FlagKitError where error.code == .authInvalidKey {
                // Try failover to secondary key on 401 errors
                if let secondaryKey = secondaryApiKey, !hasFailedOverToSecondary {
                    currentApiKey = secondaryKey
                    hasFailedOverToSecondary = true
                    // Retry with secondary key without counting this attempt
                    attempts -= 1
                    continue
                }
                throw error
            } catch let error as FlagKitError where !error.isRecoverable {
                throw error
            } catch {
                lastError = error

                if attempts < retryAttempts {
                    let backoff = calculateBackoff(attempt: attempts)
                    try await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                }
            }
        }

        await circuitBreaker.recordFailure()
        throw lastError ?? FlagKitError.networkError("Request failed after \(retryAttempts) attempts")
    }

    private func executeRequest(
        _ method: HTTPMethod,
        path: String,
        params: [String: String]?,
        body: [String: Any]?
    ) async throws -> [String: Any] {
        let effectiveBaseURL = Self.getBaseUrl(localPort: localPort)
        var urlString = "\(effectiveBaseURL)\(path)"

        if let params = params, !params.isEmpty {
            let queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
            var components = URLComponents(string: urlString)
            components?.queryItems = queryItems
            urlString = components?.url?.absoluteString ?? urlString
        }

        guard let url = URL(string: urlString) else {
            throw FlagKitError.configError(code: .configInvalidUrl, message: "Invalid URL: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(currentApiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("FlagKit-Swift/1.0.3", forHTTPHeaderField: "User-Agent")
        request.setValue("1.0.3", forHTTPHeaderField: "X-FlagKit-SDK-Version")
        request.setValue("swift", forHTTPHeaderField: "X-FlagKit-SDK-Language")

        if let body = body {
            let bodyData = try JSONSerialization.data(withJSONObject: body)
            request.httpBody = bodyData

            // Add request signing headers for POST requests
            if enableRequestSigning, method == .post {
                let bodyString = String(data: bodyData, encoding: .utf8) ?? ""
                let signature = createRequestSignature(body: bodyString, apiKey: currentApiKey)
                request.setValue(signature.signature, forHTTPHeaderField: "X-Signature")
                request.setValue(String(signature.timestamp), forHTTPHeaderField: "X-Timestamp")
                request.setValue(signature.keyId, forHTTPHeaderField: "X-Key-Id")
            }
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FlagKitError.networkError("Invalid response")
        }

        // Extract and process usage metrics from response headers
        let usageMetrics = extractUsageMetrics(from: httpResponse)
        if let metrics = usageMetrics {
            // Log warnings for high usage
            logUsageWarnings(metrics)

            // Notify callback if set
            onUsageUpdate?(metrics)
        }

        return try parseResponse(data: data, statusCode: httpResponse.statusCode)
    }

    /// Extracts usage metrics from HTTP response headers.
    /// - Parameter response: The HTTP response.
    /// - Returns: UsageMetrics if any usage headers are present, nil otherwise.
    private func extractUsageMetrics(from response: HTTPURLResponse) -> UsageMetrics? {
        let headers = response.allHeaderFields

        let apiUsageHeader = headers["X-API-Usage-Percent"] as? String ?? headers["x-api-usage-percent"] as? String
        let evalUsageHeader = headers["X-Evaluation-Usage-Percent"] as? String ?? headers["x-evaluation-usage-percent"] as? String
        let rateLimitWarningHeader = headers["X-Rate-Limit-Warning"] as? String ?? headers["x-rate-limit-warning"] as? String
        let subscriptionStatusHeader = headers["X-Subscription-Status"] as? String ?? headers["x-subscription-status"] as? String

        // Return nil if no usage headers are present
        guard apiUsageHeader != nil || evalUsageHeader != nil || rateLimitWarningHeader != nil || subscriptionStatusHeader != nil else {
            return nil
        }

        var apiUsagePercent: Double?
        if let header = apiUsageHeader {
            apiUsagePercent = Double(header)
        }

        var evaluationUsagePercent: Double?
        if let header = evalUsageHeader {
            evaluationUsagePercent = Double(header)
        }

        let rateLimitWarning = rateLimitWarningHeader == "true"

        var subscriptionStatus: SubscriptionStatus?
        if let header = subscriptionStatusHeader {
            subscriptionStatus = SubscriptionStatus(rawValue: header)
        }

        return UsageMetrics(
            apiUsagePercent: apiUsagePercent,
            evaluationUsagePercent: evaluationUsagePercent,
            rateLimitWarning: rateLimitWarning,
            subscriptionStatus: subscriptionStatus
        )
    }

    /// Logs warnings for high usage metrics.
    /// - Parameter metrics: The usage metrics to check.
    private func logUsageWarnings(_ metrics: UsageMetrics) {
        if let apiUsage = metrics.apiUsagePercent, apiUsage >= 80 {
            logger?.warn("[FlagKit] API usage at \(apiUsage)%")
        }

        if let evalUsage = metrics.evaluationUsagePercent, evalUsage >= 80 {
            logger?.warn("[FlagKit] Evaluation usage at \(evalUsage)%")
        }

        if metrics.subscriptionStatus == .suspended {
            logger?.error("[FlagKit] Subscription suspended - service degraded")
        }
    }

    private func parseResponse(data: Data, statusCode: Int) throws -> [String: Any] {
        switch statusCode {
        case 200...299:
            if data.isEmpty {
                return [:]
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw FlagKitError.networkError("Invalid JSON response")
            }
            return json

        case 401:
            throw FlagKitError.authError(code: .authInvalidKey, message: "Invalid API key")

        case 403:
            throw FlagKitError.authError(code: .authPermissionDenied, message: "Permission denied")

        case 404:
            throw FlagKitError(code: .evalFlagNotFound, message: "Resource not found")

        case 429:
            throw FlagKitError(code: .networkRetryLimit, message: "Rate limit exceeded")

        case 500...599:
            throw FlagKitError.networkError("Server error: \(statusCode)")

        default:
            throw FlagKitError.networkError("Unexpected response status: \(statusCode)")
        }
    }

    private func calculateBackoff(attempt: Int) -> TimeInterval {
        let delay = Self.baseRetryDelay * pow(Self.retryMultiplier, Double(attempt - 1))
        let cappedDelay = min(delay, Self.maxRetryDelay)
        let jitter = cappedDelay * Self.jitterFactor * Double.random(in: 0...1)
        return cappedDelay + jitter
    }
}
