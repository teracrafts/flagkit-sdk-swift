import Foundation
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin.C
#elseif os(Linux)
import Glibc
#endif

/// Status of a persisted event.
public enum PersistedEventStatus: String, Codable, Sendable {
    case pending = "pending"
    case sending = "sending"
    case sent = "sent"
    case failed = "failed"
}

/// A persisted event with status tracking.
public struct PersistedEvent: Codable, Sendable {
    /// Unique identifier for the event.
    public let id: String

    /// The event type.
    public let eventType: String

    /// Event data as JSON-encoded string.
    public let eventData: String?

    /// Timestamp when the event occurred (milliseconds since epoch).
    public let timestamp: Int64

    /// User ID associated with the event.
    public let userId: String?

    /// Session ID.
    public let sessionId: String?

    /// SDK version.
    public let sdkVersion: String

    /// Current status of the event.
    public var status: PersistedEventStatus

    /// Timestamp when the event was sent (milliseconds since epoch).
    public var sentAt: Int64?

    /// Creates a new persisted event from an analytics event.
    public init(from event: AnalyticsEvent, id: String = UUID().uuidString) {
        self.id = id
        self.eventType = event.eventType
        self.timestamp = Int64(event.timestamp.timeIntervalSince1970 * 1000)
        self.userId = event.userId
        self.sessionId = event.sessionId
        self.sdkVersion = event.sdkVersion
        self.status = .pending
        self.sentAt = nil

        // Encode event data as JSON string
        if let data = event.eventData {
            self.eventData = try? String(data: JSONSerialization.data(withJSONObject: data), encoding: .utf8)
        } else {
            self.eventData = nil
        }
    }

    /// Creates a status update entry for the event.
    public static func statusUpdate(id: String, status: PersistedEventStatus, sentAt: Int64? = nil) -> PersistedEvent {
        PersistedEvent(
            id: id,
            eventType: "",
            eventData: nil,
            timestamp: 0,
            userId: nil,
            sessionId: nil,
            sdkVersion: "",
            status: status,
            sentAt: sentAt
        )
    }

    private init(
        id: String,
        eventType: String,
        eventData: String?,
        timestamp: Int64,
        userId: String?,
        sessionId: String?,
        sdkVersion: String,
        status: PersistedEventStatus,
        sentAt: Int64?
    ) {
        self.id = id
        self.eventType = eventType
        self.eventData = eventData
        self.timestamp = timestamp
        self.userId = userId
        self.sessionId = sessionId
        self.sdkVersion = sdkVersion
        self.status = status
        self.sentAt = sentAt
    }

    /// Converts back to an AnalyticsEvent.
    public func toAnalyticsEvent() -> AnalyticsEvent {
        var eventDataDict: [String: Any]? = nil
        if let dataString = eventData,
           let data = dataString.data(using: .utf8),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            eventDataDict = decoded
        }

        return AnalyticsEvent(
            eventType: eventType,
            eventData: eventDataDict,
            timestamp: Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000),
            userId: userId,
            sessionId: sessionId,
            sdkVersion: sdkVersion
        )
    }
}

/// Configuration for event persistence.
public struct EventPersistenceConfig: Sendable {
    /// Storage directory path.
    public let storagePath: String

    /// Maximum number of events to persist.
    public let maxEvents: Int

    /// Interval between disk flushes in seconds.
    public let flushInterval: TimeInterval

    /// Buffer size before forcing a flush.
    public let bufferSize: Int

    /// Creates event persistence configuration.
    public init(
        storagePath: String? = nil,
        maxEvents: Int = 10000,
        flushInterval: TimeInterval = 1.0,
        bufferSize: Int = 100
    ) {
        if let path = storagePath {
            self.storagePath = path
        } else {
            self.storagePath = NSTemporaryDirectory().appending("flagkit-events")
        }
        self.maxEvents = maxEvents
        self.flushInterval = flushInterval
        self.bufferSize = bufferSize
    }
}

/// Logger protocol for event persistence.
public protocol EventPersistenceLogger: Sendable {
    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}

/// Default no-op logger.
public struct DefaultEventPersistenceLogger: EventPersistenceLogger {
    public init() {}
    public func debug(_ message: String) {}
    public func info(_ message: String) {}
    public func warning(_ message: String) {}
    public func error(_ message: String) {}
}

/// Crash-resilient event persistence using write-ahead logging.
///
/// Uses JSON Lines format and file locking to ensure durability across crashes.
public actor EventPersistence {
    private let config: EventPersistenceConfig
    private let logger: EventPersistenceLogger
    private let fileManager: FileManager

    private var buffer: [PersistedEvent] = []
    private var flushTask: Task<Void, Never>?
    private var isRunning = false
    private var eventCount = 0

    private var lockFilePath: String {
        config.storagePath.appending("/flagkit-events.lock")
    }

    private var currentLogFilePath: String {
        config.storagePath.appending("/flagkit-events-current.jsonl")
    }

    /// Creates a new event persistence manager.
    /// - Parameters:
    ///   - storagePath: Directory path for event storage.
    ///   - maxEvents: Maximum events to persist.
    ///   - flushInterval: Seconds between disk writes.
    ///   - logger: Optional logger for debugging.
    public init(
        storagePath: String,
        maxEvents: Int = 10000,
        flushInterval: TimeInterval = 1.0,
        logger: EventPersistenceLogger? = nil
    ) {
        self.config = EventPersistenceConfig(
            storagePath: storagePath,
            maxEvents: maxEvents,
            flushInterval: flushInterval
        )
        self.logger = logger ?? DefaultEventPersistenceLogger()
        self.fileManager = FileManager.default
    }

    /// Creates a new event persistence manager with configuration.
    /// - Parameters:
    ///   - config: Persistence configuration.
    ///   - logger: Optional logger for debugging.
    public init(
        config: EventPersistenceConfig,
        logger: EventPersistenceLogger? = nil
    ) {
        self.config = config
        self.logger = logger ?? DefaultEventPersistenceLogger()
        self.fileManager = FileManager.default
    }

    /// Starts the background flush task.
    public func start() throws {
        guard !isRunning else { return }

        // Ensure storage directory exists
        try ensureStorageDirectory()

        isRunning = true
        flushTask = Task { [weak self] in
            await self?.flushLoop()
        }

        logger.info("EventPersistence started")
    }

    /// Stops the background flush task and flushes remaining events.
    public func stop() async {
        isRunning = false
        flushTask?.cancel()
        flushTask = nil

        // Flush remaining buffered events
        do {
            try await flush()
        } catch {
            logger.error("Failed to flush on stop: \(error)")
        }

        logger.info("EventPersistence stopped")
    }

    /// Persists an event to the buffer.
    /// - Parameter event: The analytics event to persist.
    public func persist(_ event: AnalyticsEvent) throws {
        let persistedEvent = PersistedEvent(from: event)
        buffer.append(persistedEvent)

        // Flush if buffer is full
        if buffer.count >= config.bufferSize {
            try flushSync()
        }
    }

    /// Persists an event with a specific ID.
    /// - Parameters:
    ///   - event: The analytics event to persist.
    ///   - id: The event ID.
    public func persist(_ event: AnalyticsEvent, withId id: String) throws {
        let persistedEvent = PersistedEvent(from: event, id: id)
        buffer.append(persistedEvent)

        if buffer.count >= config.bufferSize {
            try flushSync()
        }
    }

    /// Flushes buffered events to disk.
    public func flush() async throws {
        try flushSync()
    }

    /// Synchronously flushes buffered events to disk with file locking.
    private func flushSync() throws {
        guard !buffer.isEmpty else { return }

        let eventsToFlush = buffer
        buffer.removeAll()

        try withFileLock {
            try writeEvents(eventsToFlush)
        }

        eventCount += eventsToFlush.count
        logger.debug("Flushed \(eventsToFlush.count) events to disk")
    }

    /// Marks events as sent after successful batch transmission.
    /// - Parameter eventIds: IDs of events that were successfully sent.
    public func markSent(_ eventIds: [String]) throws {
        guard !eventIds.isEmpty else { return }

        let sentAt = Int64(Date().timeIntervalSince1970 * 1000)
        let statusUpdates = eventIds.map { id in
            PersistedEvent.statusUpdate(id: id, status: .sent, sentAt: sentAt)
        }

        try withFileLock {
            try writeEvents(statusUpdates)
        }

        logger.debug("Marked \(eventIds.count) events as sent")
    }

    /// Marks events as sending (in-flight).
    /// - Parameter eventIds: IDs of events being sent.
    public func markSending(_ eventIds: [String]) throws {
        guard !eventIds.isEmpty else { return }

        let statusUpdates = eventIds.map { id in
            PersistedEvent.statusUpdate(id: id, status: .sending)
        }

        try withFileLock {
            try writeEvents(statusUpdates)
        }
    }

    /// Marks events as pending (revert from sending on failure).
    /// - Parameter eventIds: IDs of events to mark as pending.
    public func markPending(_ eventIds: [String]) throws {
        guard !eventIds.isEmpty else { return }

        let statusUpdates = eventIds.map { id in
            PersistedEvent.statusUpdate(id: id, status: .pending)
        }

        try withFileLock {
            try writeEvents(statusUpdates)
        }
    }

    /// Recovers pending events from disk on startup.
    /// - Returns: Array of pending analytics events.
    public func recover() throws -> [AnalyticsEvent] {
        var events: [PersistedEvent] = []

        try withFileLock {
            events = try readAllEvents()
        }

        // Build final state for each event
        var eventState: [String: PersistedEvent] = [:]

        for event in events {
            if event.eventType.isEmpty {
                // This is a status update
                if var existing = eventState[event.id] {
                    existing.status = event.status
                    existing.sentAt = event.sentAt
                    eventState[event.id] = existing
                }
            } else {
                // This is a full event
                eventState[event.id] = event
            }
        }

        // Return pending and sending events (sending = crashed mid-send)
        let pendingEvents = eventState.values
            .filter { $0.status == .pending || $0.status == .sending }
            .sorted { $0.timestamp < $1.timestamp }
            .map { $0.toAnalyticsEvent() }

        logger.info("Recovered \(pendingEvents.count) pending events")
        return pendingEvents
    }

    /// Cleans up old sent events from disk.
    public func cleanup() throws {
        try withFileLock {
            try compactEventLog()
        }

        logger.info("Cleaned up sent events")
    }

    /// Returns the current number of buffered events.
    public var bufferedCount: Int {
        buffer.count
    }

    /// Returns the storage path.
    public var storagePath: String {
        config.storagePath
    }

    // MARK: - Private Methods

    private func ensureStorageDirectory() throws {
        if !fileManager.fileExists(atPath: config.storagePath) {
            try fileManager.createDirectory(
                atPath: config.storagePath,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
    }

    private func withFileLock<T>(_ operation: () throws -> T) throws -> T {
        // Create lock file if it doesn't exist
        if !fileManager.fileExists(atPath: lockFilePath) {
            fileManager.createFile(atPath: lockFilePath, contents: nil, attributes: nil)
        }

        guard let lockFile = FileHandle(forWritingAtPath: lockFilePath) else {
            throw FlagKitError(
                code: .cacheStorageError,
                message: "Failed to open lock file"
            )
        }

        defer {
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(Linux)
            _ = flock(lockFile.fileDescriptor, LOCK_UN)
            #endif
            try? lockFile.close()
        }

        // Acquire exclusive lock
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(Linux)
        let lockResult = flock(lockFile.fileDescriptor, LOCK_EX)
        if lockResult != 0 {
            throw FlagKitError(
                code: .cacheStorageError,
                message: "Failed to acquire file lock"
            )
        }
        #endif

        return try operation()
    }

    private func writeEvents(_ events: [PersistedEvent]) throws {
        let encoder = JSONEncoder()
        var lines: [String] = []

        for event in events {
            let data = try encoder.encode(event)
            if let line = String(data: data, encoding: .utf8) {
                lines.append(line)
            }
        }

        let content = lines.joined(separator: "\n") + "\n"

        // Append to current log file
        if fileManager.fileExists(atPath: currentLogFilePath) {
            guard let fileHandle = FileHandle(forWritingAtPath: currentLogFilePath) else {
                throw FlagKitError(
                    code: .cacheWriteError,
                    message: "Failed to open event log file"
                )
            }
            defer { try? fileHandle.close() }

            try fileHandle.seekToEnd()
            if let data = content.data(using: .utf8) {
                try fileHandle.write(contentsOf: data)
                try fileHandle.synchronize()
            }
        } else {
            try content.write(toFile: currentLogFilePath, atomically: false, encoding: .utf8)
        }
    }

    private func readAllEvents() throws -> [PersistedEvent] {
        guard fileManager.fileExists(atPath: currentLogFilePath) else {
            return []
        }

        let content = try String(contentsOfFile: currentLogFilePath, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        let decoder = JSONDecoder()
        var events: [PersistedEvent] = []

        for line in lines {
            if let data = line.data(using: .utf8),
               let event = try? decoder.decode(PersistedEvent.self, from: data) {
                events.append(event)
            }
        }

        return events
    }

    private func compactEventLog() throws {
        let events = try readAllEvents()

        // Build final state
        var eventState: [String: PersistedEvent] = [:]

        for event in events {
            if event.eventType.isEmpty {
                if var existing = eventState[event.id] {
                    existing.status = event.status
                    existing.sentAt = event.sentAt
                    eventState[event.id] = existing
                }
            } else {
                eventState[event.id] = event
            }
        }

        // Keep only pending and sending events
        let pendingEvents = eventState.values
            .filter { $0.status == .pending || $0.status == .sending }
            .sorted { $0.timestamp < $1.timestamp }

        // Enforce max events limit
        let eventsToKeep = Array(pendingEvents.suffix(config.maxEvents))

        // Rewrite the log file
        if eventsToKeep.isEmpty {
            try fileManager.removeItem(atPath: currentLogFilePath)
        } else {
            let encoder = JSONEncoder()
            var lines: [String] = []

            for event in eventsToKeep {
                let data = try encoder.encode(event)
                if let line = String(data: data, encoding: .utf8) {
                    lines.append(line)
                }
            }

            let content = lines.joined(separator: "\n") + "\n"
            try content.write(toFile: currentLogFilePath, atomically: true, encoding: .utf8)
        }

        eventCount = eventsToKeep.count
    }

    private func flushLoop() async {
        while isRunning {
            let sleepNanos = UInt64(config.flushInterval * 1_000_000_000)
            try? await Task.sleep(nanoseconds: sleepNanos)

            guard isRunning else { break }

            do {
                try flushSync()
            } catch {
                logger.error("Background flush failed: \(error)")
            }
        }
    }
}
