import Foundation

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

    private let apiKey: String
    private let timeout: TimeInterval
    private let retryAttempts: Int
    private let circuitBreaker: CircuitBreaker
    private let session: URLSession
    private let localPort: Int?

    init(
        apiKey: String,
        timeout: TimeInterval,
        retryAttempts: Int,
        circuitBreaker: CircuitBreaker,
        localPort: Int? = nil
    ) {
        self.apiKey = apiKey
        self.timeout = timeout
        self.retryAttempts = retryAttempts
        self.circuitBreaker = circuitBreaker
        self.localPort = localPort

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        self.session = URLSession(configuration: config)
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
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("FlagKit-Swift/1.0.0", forHTTPHeaderField: "User-Agent")

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FlagKitError.networkError("Invalid response")
        }

        return try parseResponse(data: data, statusCode: httpResponse.statusCode)
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
