import Foundation

/// Circuit breaker pattern implementation for resilient HTTP calls.
public actor CircuitBreaker {
    /// Circuit breaker states.
    public enum State: Sendable {
        case closed
        case open
        case halfOpen
    }

    private(set) public var state: State = .closed
    private var failureCount: Int = 0
    private var lastFailureTime: Date?

    private let failureThreshold: Int
    private let resetTimeout: TimeInterval

    /// Creates a new circuit breaker.
    /// - Parameters:
    ///   - failureThreshold: Number of failures before opening.
    ///   - resetTimeout: Seconds to wait before half-open.
    public init(failureThreshold: Int = 5, resetTimeout: TimeInterval = 30) {
        self.failureThreshold = failureThreshold
        self.resetTimeout = resetTimeout
    }

    /// Checks if the circuit allows requests.
    public func allowRequest() -> Bool {
        switch state {
        case .closed:
            return true
        case .open:
            checkResetTimeout()
            return state != .open
        case .halfOpen:
            return true
        }
    }

    /// Records a successful request.
    public func recordSuccess() {
        failureCount = 0
        state = .closed
    }

    /// Records a failed request.
    public func recordFailure() {
        failureCount += 1
        lastFailureTime = Date()

        if failureCount >= failureThreshold {
            state = .open
        }
    }

    /// Whether the circuit is open.
    public var isOpen: Bool {
        checkResetTimeout()
        return state == .open
    }

    /// Whether the circuit is closed.
    public var isClosed: Bool {
        state == .closed
    }

    /// Whether the circuit is half-open.
    public var isHalfOpen: Bool {
        checkResetTimeout()
        return state == .halfOpen
    }

    /// Resets the circuit breaker.
    public func reset() {
        state = .closed
        failureCount = 0
        lastFailureTime = nil
    }

    /// The current failure count.
    public func getFailureCount() -> Int {
        failureCount
    }

    /// Executes a closure with circuit breaker protection.
    public func execute<T>(_ operation: () async throws -> T) async throws -> T {
        guard allowRequest() else {
            throw FlagKitError(code: .circuitOpen, message: "Circuit breaker is open")
        }

        do {
            let result = try await operation()
            recordSuccess()
            return result
        } catch {
            recordFailure()
            throw error
        }
    }

    private func checkResetTimeout() {
        guard state == .open, let lastFailure = lastFailureTime else { return }

        if Date().timeIntervalSince(lastFailure) >= resetTimeout {
            state = .halfOpen
        }
    }
}
