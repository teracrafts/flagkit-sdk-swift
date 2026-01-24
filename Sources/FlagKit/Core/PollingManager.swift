import Foundation

/// Polling state enumeration.
public enum PollingState: Sendable {
    case stopped
    case running
    case paused
}

/// Configuration for the polling manager.
public struct PollingConfig: Sendable {
    /// Polling interval in seconds. Default: 30.
    public let interval: TimeInterval

    /// Jitter in seconds to prevent thundering herd. Default: 1.
    public let jitter: TimeInterval

    /// Backoff multiplier for consecutive errors. Default: 2.
    public let backoffMultiplier: Double

    /// Maximum interval in seconds (after backoff). Default: 300 (5 minutes).
    public let maxInterval: TimeInterval

    /// Maximum consecutive errors before stopping. Default: 10 (0 = never stop).
    public let maxConsecutiveErrors: Int

    /// Creates polling configuration.
    public init(
        interval: TimeInterval = 30,
        jitter: TimeInterval = 1,
        backoffMultiplier: Double = 2,
        maxInterval: TimeInterval = 300,
        maxConsecutiveErrors: Int = 0
    ) {
        self.interval = interval
        self.jitter = jitter
        self.backoffMultiplier = backoffMultiplier
        self.maxInterval = maxInterval
        self.maxConsecutiveErrors = maxConsecutiveErrors
    }
}

/// Manages background polling for flag updates with exponential backoff.
public actor PollingManager {
    private let config: PollingConfig
    private let onUpdate: (Date?) async throws -> Void
    private let onError: ((Error) -> Void)?

    private var state: PollingState = .stopped
    private var lastUpdateTime: Date?
    private var lastPollTime: Date?
    private var consecutiveErrors = 0
    private var currentInterval: TimeInterval
    private var task: Task<Void, Never>?

    /// Creates a new polling manager.
    /// - Parameters:
    ///   - config: Polling configuration.
    ///   - onUpdate: Callback when updates should be fetched.
    ///   - onError: Optional callback for error handling.
    public init(
        config: PollingConfig = PollingConfig(),
        onUpdate: @escaping (Date?) async throws -> Void,
        onError: ((Error) -> Void)? = nil
    ) {
        self.config = config
        self.onUpdate = onUpdate
        self.onError = onError
        self.currentInterval = config.interval
    }

    /// Creates a new polling manager with basic parameters.
    /// - Parameters:
    ///   - interval: Polling interval in seconds.
    ///   - onUpdate: Callback when updates should be fetched.
    public init(
        interval: TimeInterval,
        onUpdate: @escaping (Date?) async throws -> Void
    ) {
        self.config = PollingConfig(interval: interval)
        self.onUpdate = onUpdate
        self.onError = nil
        self.currentInterval = interval
    }

    /// Starts the polling loop.
    public func start() {
        guard state == .stopped else { return }

        state = .running
        consecutiveErrors = 0
        currentInterval = config.interval

        task = Task { [weak self] in
            await self?.pollingLoop()
        }
    }

    /// Stops the polling loop.
    public func stop() {
        state = .stopped
        task?.cancel()
        task = nil
    }

    /// Pauses the polling loop temporarily.
    public func pause() {
        guard state == .running else { return }
        state = .paused
    }

    /// Resumes the polling loop after pausing.
    public func resume() {
        guard state == .paused else { return }
        state = .running
    }

    /// Returns the current polling state.
    public var pollingState: PollingState {
        state
    }

    /// Whether polling is running.
    public var running: Bool {
        state == .running
    }

    /// The last successful update timestamp.
    public func getLastUpdateTime() -> Date? {
        lastUpdateTime
    }

    /// The last poll attempt timestamp.
    public func getLastPollTime() -> Date? {
        lastPollTime
    }

    /// The current polling interval (may be increased due to backoff).
    public func getCurrentInterval() -> TimeInterval {
        currentInterval
    }

    /// The number of consecutive errors.
    public func getConsecutiveErrors() -> Int {
        consecutiveErrors
    }

    /// Manually triggers a poll immediately.
    /// - Returns: True if the poll succeeded.
    @discardableResult
    public func pollNow() async -> Bool {
        return await performPoll()
    }

    /// Resets the polling manager to initial state.
    public func reset() {
        consecutiveErrors = 0
        currentInterval = config.interval
        lastUpdateTime = nil
        lastPollTime = nil

        if state == .running {
            // Restart with reset interval
            task?.cancel()
            task = Task { [weak self] in
                await self?.pollingLoop()
            }
        }
    }

    // MARK: - Private Methods

    private func pollingLoop() async {
        while state != .stopped {
            // Skip polling if paused
            if state == .paused {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                continue
            }

            let sleepDuration = getNextDelay()
            try? await Task.sleep(nanoseconds: UInt64(sleepDuration * 1_000_000_000))

            guard state == .running else { continue }

            await performPoll()
        }
    }

    @discardableResult
    private func performPoll() async -> Bool {
        lastPollTime = Date()

        do {
            try await onUpdate(lastUpdateTime)
            onSuccess()
            return true
        } catch {
            onFailure(error)
            return false
        }
    }

    private func onSuccess() {
        consecutiveErrors = 0
        currentInterval = config.interval
        lastUpdateTime = Date()
    }

    private func onFailure(_ error: Error) {
        consecutiveErrors += 1
        onError?(error)

        // Apply exponential backoff
        currentInterval = min(
            currentInterval * config.backoffMultiplier,
            config.maxInterval
        )

        // Stop if max consecutive errors reached (if configured)
        if config.maxConsecutiveErrors > 0 && consecutiveErrors >= config.maxConsecutiveErrors {
            stop()
        }
    }

    private func getNextDelay() -> TimeInterval {
        // Add jitter to prevent thundering herd
        let jitter = Double.random(in: 0...config.jitter)
        return currentInterval + jitter
    }
}
