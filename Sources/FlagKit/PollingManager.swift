import Foundation

/// Manages background polling for flag updates.
actor PollingManager {
    private static let maxBackoffMultiplier: Double = 4.0

    private let interval: TimeInterval
    private let onUpdate: (Date?) async throws -> Void
    private var isRunning = false
    private var lastUpdateTime: Date?
    private var consecutiveErrors = 0
    private var task: Task<Void, Never>?

    /// Creates a new polling manager.
    /// - Parameters:
    ///   - interval: Polling interval in seconds.
    ///   - onUpdate: Callback when updates should be fetched.
    init(interval: TimeInterval, onUpdate: @escaping (Date?) async throws -> Void) {
        self.interval = interval
        self.onUpdate = onUpdate
    }

    /// Starts the polling loop.
    func start() {
        guard !isRunning else { return }

        isRunning = true
        task = Task { [weak self] in
            await self?.pollingLoop()
        }
    }

    /// Stops the polling loop.
    func stop() {
        isRunning = false
        task?.cancel()
        task = nil
    }

    /// Whether polling is running.
    var running: Bool {
        isRunning
    }

    /// The last update timestamp.
    func getLastUpdateTime() -> Date? {
        lastUpdateTime
    }

    /// Manually triggers a poll.
    @discardableResult
    func pollNow() async -> Bool {
        await performPoll()
    }

    private func pollingLoop() async {
        while isRunning {
            let sleepDuration = currentIntervalWithJitter()
            try? await Task.sleep(nanoseconds: UInt64(sleepDuration * 1_000_000_000))

            guard isRunning else { break }

            await performPoll()
        }
    }

    @discardableResult
    private func performPoll() async -> Bool {
        do {
            try await onUpdate(lastUpdateTime)
            lastUpdateTime = Date()
            consecutiveErrors = 0
            return true
        } catch {
            consecutiveErrors += 1
            return false
        }
    }

    private func currentIntervalWithJitter() -> TimeInterval {
        let base = interval * backoffMultiplier()
        let jitter = base * 0.1 * Double.random(in: 0...1)
        return base + jitter
    }

    private func backoffMultiplier() -> Double {
        min(pow(2.0, Double(consecutiveErrors)), Self.maxBackoffMultiplier)
    }
}
