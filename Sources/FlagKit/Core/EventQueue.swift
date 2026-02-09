import Foundation

/// Event types supported by FlagKit.
public enum EventType: String, Sendable {
    case evaluation = "evaluation"
    case identify = "identify"
    case track = "track"
    case pageView = "page_view"
    case sdkInitialized = "sdk_initialized"
    case contextChanged = "context_changed"
    case custom = "custom"
}

/// Configuration for the event queue.
public struct EventQueueConfig: Sendable {
    /// Maximum events per batch. Default: 10.
    public let batchSize: Int

    /// Seconds between flushes. Default: 30.
    public let flushInterval: TimeInterval

    /// Maximum queue size before dropping oldest events. Default: 1000.
    public let maxQueueSize: Int

    /// Maximum retry attempts for failed flushes. Default: 3.
    public let maxRetryAttempts: Int

    /// Sample rate for events (0.0 - 1.0). Default: 1.0 (all events).
    public let sampleRate: Double

    /// Enable crash-resilient event persistence.
    public let persistEvents: Bool

    /// Directory path for event storage.
    public let eventStoragePath: String?

    /// Maximum number of events to persist.
    public let maxPersistedEvents: Int

    /// Interval between disk flushes in seconds.
    public let persistenceFlushInterval: TimeInterval

    /// Creates event queue configuration.
    public init(
        batchSize: Int = 10,
        flushInterval: TimeInterval = 30,
        maxQueueSize: Int = 1000,
        maxRetryAttempts: Int = 3,
        sampleRate: Double = 1.0,
        persistEvents: Bool = false,
        eventStoragePath: String? = nil,
        maxPersistedEvents: Int = 10000,
        persistenceFlushInterval: TimeInterval = 1.0
    ) {
        self.batchSize = batchSize
        self.flushInterval = flushInterval
        self.maxQueueSize = maxQueueSize
        self.maxRetryAttempts = maxRetryAttempts
        self.sampleRate = min(1.0, max(0.0, sampleRate))
        self.persistEvents = persistEvents
        self.eventStoragePath = eventStoragePath
        self.maxPersistedEvents = maxPersistedEvents
        self.persistenceFlushInterval = persistenceFlushInterval
    }
}

/// An analytics event to be sent to FlagKit.
public struct AnalyticsEvent: Sendable {
    /// The event type.
    public let eventType: String

    /// Event data.
    public let eventData: [String: Any]?

    /// Timestamp when the event occurred.
    public let timestamp: Date

    /// User ID associated with the event.
    public let userId: String?

    /// Session ID.
    public let sessionId: String?

    /// SDK version.
    public let sdkVersion: String

    /// Creates a new analytics event.
    public init(
        eventType: String,
        eventData: [String: Any]? = nil,
        timestamp: Date = Date(),
        userId: String? = nil,
        sessionId: String? = nil,
        sdkVersion: String = "1.0.5"
    ) {
        self.eventType = eventType
        self.eventData = eventData
        self.timestamp = timestamp
        self.userId = userId
        self.sessionId = sessionId
        self.sdkVersion = sdkVersion
    }

    /// Converts to a dictionary for API requests.
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "eventType": eventType,
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "sdkVersion": sdkVersion,
            "sdkLanguage": "swift"
        ]

        if let userId = userId {
            dict["userId"] = userId
        }

        if let sessionId = sessionId {
            dict["sessionId"] = sessionId
        }

        if let eventData = eventData {
            dict["eventData"] = eventData
        }

        return dict
    }
}

/// Batches and sends analytics events with retry support.
public actor EventQueue {
    private let config: EventQueueConfig
    private let onFlush: ([[String: Any]]) async throws -> Void

    private var queue: [AnalyticsEvent] = []
    private var eventIds: [String] = [] // Tracking IDs for persistence
    private var isRunning = false
    private var isFlushing = false
    private var task: Task<Void, Never>?
    private var consecutiveFailures = 0
    private var persistence: EventPersistence?

    /// Creates a new event queue.
    /// - Parameters:
    ///   - config: Event queue configuration.
    ///   - onFlush: Callback to send events to the server.
    public init(
        config: EventQueueConfig = EventQueueConfig(),
        onFlush: @escaping ([[String: Any]]) async throws -> Void
    ) {
        self.config = config
        self.onFlush = onFlush

        if config.persistEvents {
            let storagePath = config.eventStoragePath ?? NSTemporaryDirectory().appending("flagkit-events")
            self.persistence = EventPersistence(
                storagePath: storagePath,
                maxEvents: config.maxPersistedEvents,
                flushInterval: config.persistenceFlushInterval
            )
        }
    }

    /// Creates a new event queue with basic parameters.
    /// - Parameters:
    ///   - batchSize: Maximum events per batch.
    ///   - flushInterval: Seconds between flushes.
    ///   - onFlush: Callback to send events.
    public init(
        batchSize: Int,
        flushInterval: TimeInterval,
        onFlush: @escaping ([[String: Any]]) async throws -> Void
    ) {
        self.config = EventQueueConfig(batchSize: batchSize, flushInterval: flushInterval)
        self.onFlush = onFlush
    }

    /// Creates a new event queue with persistence support.
    /// - Parameters:
    ///   - config: Event queue configuration.
    ///   - persistence: Optional event persistence manager.
    ///   - onFlush: Callback to send events.
    public init(
        config: EventQueueConfig,
        persistence: EventPersistence?,
        onFlush: @escaping ([[String: Any]]) async throws -> Void
    ) {
        self.config = config
        self.persistence = persistence
        self.onFlush = onFlush
    }

    /// Starts the background flush task.
    public func start() async {
        guard !isRunning else { return }

        // Start persistence if enabled
        if let persistence = persistence {
            do {
                try await persistence.start()

                // Recover any pending events from previous crash
                let recoveredEvents = try await persistence.recover()
                for event in recoveredEvents {
                    queue.append(event)
                }
            } catch {
                // Log error but continue without persistence
            }
        }

        isRunning = true
        task = Task { [weak self] in
            await self?.flushLoop()
        }
    }

    /// Starts the background flush task (non-async for backward compatibility).
    public func startSync() {
        guard !isRunning else { return }

        isRunning = true
        task = Task { [weak self] in
            await self?.flushLoop()
        }
    }

    /// Stops the background flush task and flushes remaining events.
    public func stop() async {
        isRunning = false
        task?.cancel()
        task = nil

        // Flush any remaining events
        await flush()

        // Stop persistence
        if let persistence = persistence {
            await persistence.stop()
        }
    }

    /// Adds an event to the queue.
    /// - Parameter event: The event to add.
    public func add(_ event: AnalyticsEvent) async {
        // Apply sampling
        if config.sampleRate < 1.0 && Double.random(in: 0...1) > config.sampleRate {
            return
        }

        // Generate event ID for persistence tracking
        let eventId = UUID().uuidString

        // Persist event before queuing (crash-safe)
        if let persistence = persistence {
            do {
                try await persistence.persist(event, withId: eventId)
            } catch {
                // Log error but continue without persistence
            }
        }

        // Enforce max queue size
        if queue.count >= config.maxQueueSize {
            // Drop oldest event
            queue.removeFirst()
            if !eventIds.isEmpty {
                eventIds.removeFirst()
            }
        }

        queue.append(event)
        eventIds.append(eventId)

        // Flush if batch size reached
        if queue.count >= config.batchSize {
            await flush()
        }
    }

    /// Adds an event dictionary to the queue (legacy support).
    /// - Parameter event: The event dictionary to add.
    public func enqueue(_ event: [String: Any]) async {
        let analyticsEvent = AnalyticsEvent(
            eventType: event["type"] as? String ?? event["eventType"] as? String ?? "custom",
            eventData: event["data"] as? [String: Any] ?? event["eventData"] as? [String: Any],
            userId: event["userId"] as? String,
            sessionId: event["sessionId"] as? String
        )
        await add(analyticsEvent)
    }

    /// Flushes all pending events immediately.
    public func flush() async {
        guard !queue.isEmpty && !isFlushing else { return }

        isFlushing = true
        defer { isFlushing = false }

        let events = queue
        let ids = eventIds
        queue.removeAll()
        eventIds.removeAll()

        let eventDicts = events.map { $0.toDictionary() }

        // Mark events as sending if persistence is enabled
        if let persistence = persistence, !ids.isEmpty {
            do {
                try await persistence.markSending(ids)
            } catch {
                // Log error but continue
            }
        }

        do {
            try await sendWithRetry(eventDicts)
            consecutiveFailures = 0

            // Mark events as sent if persistence is enabled
            if let persistence = persistence, !ids.isEmpty {
                do {
                    try await persistence.markSent(ids)
                } catch {
                    // Log error but continue
                }
            }
        } catch {
            // Re-queue failed events (up to max size)
            let requeue = Array(events.prefix(config.maxQueueSize - queue.count))
            let requeueIds = Array(ids.prefix(config.maxQueueSize - eventIds.count))
            queue = requeue + queue
            eventIds = requeueIds + eventIds
            consecutiveFailures += 1

            // Revert events to pending status
            if let persistence = persistence, !ids.isEmpty {
                do {
                    try await persistence.markPending(ids)
                } catch {
                    // Log error but continue
                }
            }
        }
    }

    /// Clears all pending events without sending them.
    public func clearQueue() {
        queue.removeAll()
        eventIds.removeAll()
    }

    /// Returns the number of pending events.
    public var count: Int {
        queue.count
    }

    /// Whether the queue is running.
    public var running: Bool {
        isRunning
    }

    /// Gets queued events for debugging.
    public func getQueuedEvents() -> [AnalyticsEvent] {
        return queue
    }

    // MARK: - Private Methods

    private func sendWithRetry(_ events: [[String: Any]]) async throws {
        var lastError: Error?

        for attempt in 1...config.maxRetryAttempts {
            do {
                try await onFlush(events)
                return
            } catch {
                lastError = error

                if attempt < config.maxRetryAttempts {
                    // Exponential backoff with jitter
                    let delay = calculateBackoff(attempt: attempt)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? FlagKitError(code: .eventFlushFailed, message: "Failed to flush events after \(config.maxRetryAttempts) attempts")
    }

    private func calculateBackoff(attempt: Int) -> TimeInterval {
        let baseDelay: TimeInterval = 1.0
        let maxDelay: TimeInterval = 30.0
        let multiplier: Double = 2.0

        let exponentialDelay = baseDelay * pow(multiplier, Double(attempt - 1))
        let cappedDelay = min(exponentialDelay, maxDelay)
        let jitter = cappedDelay * 0.1 * Double.random(in: 0...1)

        return cappedDelay + jitter
    }

    private func flushLoop() async {
        while isRunning {
            // Add jitter to prevent thundering herd
            let jitter = config.flushInterval * 0.1 * Double.random(in: 0...1)
            let sleepDuration = config.flushInterval + jitter

            try? await Task.sleep(nanoseconds: UInt64(sleepDuration * 1_000_000_000))

            guard isRunning else { break }

            await flush()
        }
    }
}
