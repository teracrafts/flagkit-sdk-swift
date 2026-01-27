import Foundation

/// Connection states for streaming.
public enum StreamingState: String, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed
}

/// Response from the stream token endpoint.
private struct StreamTokenResponse: Codable {
    let token: String
    let expiresIn: Int
}

/// Streaming configuration.
public struct StreamingConfig: Sendable {
    public let enabled: Bool
    public let reconnectInterval: TimeInterval
    public let maxReconnectAttempts: Int
    public let heartbeatInterval: TimeInterval

    public init(
        enabled: Bool = true,
        reconnectInterval: TimeInterval = 3.0,
        maxReconnectAttempts: Int = 3,
        heartbeatInterval: TimeInterval = 30.0
    ) {
        self.enabled = enabled
        self.reconnectInterval = reconnectInterval
        self.maxReconnectAttempts = maxReconnectAttempts
        self.heartbeatInterval = heartbeatInterval
    }

    public static let `default` = StreamingConfig()
}

/// Manages Server-Sent Events (SSE) connection for real-time flag updates.
///
/// Security: Uses token exchange pattern to avoid exposing API keys in URLs.
/// 1. Fetches short-lived token via POST with API key in header
/// 2. Connects to SSE endpoint with disposable token in URL
///
/// Features:
/// - Secure token-based authentication
/// - Automatic token refresh before expiry
/// - Automatic reconnection with exponential backoff
/// - Graceful degradation to polling after max failures
/// - Heartbeat monitoring for connection health
public actor StreamingManager {
    private let baseURL: String
    private let getAPIKey: @Sendable () -> String
    private let config: StreamingConfig
    private let onFlagUpdate: @Sendable (FlagState) -> Void
    private let onFlagDelete: @Sendable (String) -> Void
    private let onFlagsReset: @Sendable ([FlagState]) -> Void
    private let onFallbackToPolling: @Sendable () -> Void

    private var state: StreamingState = .disconnected
    private var consecutiveFailures = 0
    private var lastHeartbeat = Date()
    private var urlSession: URLSession
    private var currentTask: URLSessionDataTask?
    private var tokenRefreshTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?

    public init(
        baseURL: String,
        getAPIKey: @escaping @Sendable () -> String,
        config: StreamingConfig = .default,
        onFlagUpdate: @escaping @Sendable (FlagState) -> Void,
        onFlagDelete: @escaping @Sendable (String) -> Void,
        onFlagsReset: @escaping @Sendable ([FlagState]) -> Void,
        onFallbackToPolling: @escaping @Sendable () -> Void
    ) {
        self.baseURL = baseURL
        self.getAPIKey = getAPIKey
        self.config = config
        self.onFlagUpdate = onFlagUpdate
        self.onFlagDelete = onFlagDelete
        self.onFlagsReset = onFlagsReset
        self.onFallbackToPolling = onFallbackToPolling

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = .infinity
        sessionConfig.timeoutIntervalForResource = .infinity
        self.urlSession = URLSession(configuration: sessionConfig)
    }

    /// Gets the current connection state.
    public func getState() -> StreamingState {
        return state
    }

    /// Checks if streaming is connected.
    public func isConnected() -> Bool {
        return state == .connected
    }

    /// Starts the streaming connection.
    public func connect() {
        guard state != .connected && state != .connecting else { return }

        state = .connecting
        Task { await initiateConnection() }
    }

    /// Stops the streaming connection.
    public func disconnect() {
        cleanup()
        state = .disconnected
        consecutiveFailures = 0
    }

    /// Retries the streaming connection.
    public func retryConnection() {
        guard state != .connected && state != .connecting else { return }
        consecutiveFailures = 0
        connect()
    }

    private func initiateConnection() async {
        do {
            // Step 1: Fetch short-lived stream token
            let tokenResponse = try await fetchStreamToken()

            // Step 2: Schedule token refresh at 80% of TTL
            scheduleTokenRefresh(delay: Double(tokenResponse.expiresIn) * 0.8)

            // Step 3: Create SSE connection with token
            await createConnection(token: tokenResponse.token)
        } catch {
            await handleConnectionFailure()
        }
    }

    private func fetchStreamToken() async throws -> StreamTokenResponse {
        let tokenURL = URL(string: "\(baseURL)/sdk/stream/token")!

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(getAPIKey(), forHTTPHeaderField: "X-API-Key")
        request.httpBody = "{}".data(using: .utf8)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "StreamingManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to fetch stream token"])
        }

        return try JSONDecoder().decode(StreamTokenResponse.self, from: data)
    }

    private func scheduleTokenRefresh(delay: Double) {
        tokenRefreshTask?.cancel()

        tokenRefreshTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }

            do {
                let tokenResponse = try await fetchStreamToken()
                scheduleTokenRefresh(delay: Double(tokenResponse.expiresIn) * 0.8)
            } catch {
                disconnect()
                connect()
            }
        }
    }

    private func createConnection(token: String) async {
        let streamURL = URL(string: "\(baseURL)/sdk/stream?token=\(token)")!

        var request = URLRequest(url: streamURL)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        do {
            let (bytes, response) = try await urlSession.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                await handleConnectionFailure()
                return
            }

            handleOpen()

            var eventType: String?
            var dataBuffer = ""

            for try await line in bytes.lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)

                // Empty line = end of event
                if trimmedLine.isEmpty {
                    if let type = eventType, !dataBuffer.isEmpty {
                        processEvent(type: type, data: dataBuffer)
                        eventType = nil
                        dataBuffer = ""
                    }
                    continue
                }

                // Parse SSE format
                if trimmedLine.hasPrefix("event:") {
                    eventType = String(trimmedLine.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                } else if trimmedLine.hasPrefix("data:") {
                    dataBuffer += String(trimmedLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                }
            }

            // Connection closed
            if state == .connected {
                await handleConnectionFailure()
            }
        } catch {
            if !Task.isCancelled {
                await handleConnectionFailure()
            }
        }
    }

    private func handleOpen() {
        state = .connected
        consecutiveFailures = 0
        lastHeartbeat = Date()
        startHeartbeatMonitor()
    }

    private func processEvent(type: String, data: String) {
        guard let jsonData = data.data(using: .utf8) else { return }

        do {
            switch type {
            case "flag_updated":
                let flag = try JSONDecoder().decode(FlagState.self, from: jsonData)
                onFlagUpdate(flag)

            case "flag_deleted":
                struct DeleteData: Codable { let key: String }
                let deleteData = try JSONDecoder().decode(DeleteData.self, from: jsonData)
                onFlagDelete(deleteData.key)

            case "flags_reset":
                let flags = try JSONDecoder().decode([FlagState].self, from: jsonData)
                onFlagsReset(flags)

            case "heartbeat":
                lastHeartbeat = Date()

            default:
                break
            }
        } catch {
            // Failed to parse event
        }
    }

    private func handleConnectionFailure() async {
        cleanup()
        consecutiveFailures += 1

        if consecutiveFailures >= config.maxReconnectAttempts {
            state = .failed
            onFallbackToPolling()
            scheduleStreamingRetry()
        } else {
            state = .reconnecting
            scheduleReconnect()
        }
    }

    private func scheduleReconnect() {
        let delay = getReconnectDelay()

        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            connect()
        }
    }

    private func getReconnectDelay() -> Double {
        let baseDelay = config.reconnectInterval
        let backoff = pow(2.0, Double(consecutiveFailures - 1))
        let delay = baseDelay * backoff
        // Cap at 30 seconds
        return min(delay, 30.0)
    }

    private func scheduleStreamingRetry() {
        retryTask?.cancel()

        retryTask = Task {
            try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000) // 5 minutes
            guard !Task.isCancelled else { return }
            retryConnection()
        }
    }

    private func startHeartbeatMonitor() {
        stopHeartbeatMonitor()

        let checkInterval = config.heartbeatInterval * 1.5

        heartbeatTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            guard !Task.isCancelled else { return }

            let timeSince = Date().timeIntervalSince(lastHeartbeat)
            let threshold = config.heartbeatInterval * 2

            if timeSince > threshold {
                await handleConnectionFailure()
            } else {
                startHeartbeatMonitor()
            }
        }
    }

    private func stopHeartbeatMonitor() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    private func cleanup() {
        currentTask?.cancel()
        currentTask = nil
        tokenRefreshTask?.cancel()
        tokenRefreshTask = nil
        stopHeartbeatMonitor()
        retryTask?.cancel()
        retryTask = nil
    }
}
