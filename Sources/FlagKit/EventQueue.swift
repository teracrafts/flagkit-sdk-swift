import Foundation

/// Batches and sends analytics events.
actor EventQueue {
    private let batchSize: Int
    private let flushInterval: TimeInterval
    private let onFlush: ([[String: Any]]) async throws -> Void

    private var queue: [[String: Any]] = []
    private var isRunning = false
    private var task: Task<Void, Never>?

    /// Creates a new event queue.
    /// - Parameters:
    ///   - batchSize: Maximum events per batch.
    ///   - flushInterval: Seconds between flushes.
    ///   - onFlush: Callback to send events.
    init(
        batchSize: Int,
        flushInterval: TimeInterval,
        onFlush: @escaping ([[String: Any]]) async throws -> Void
    ) {
        self.batchSize = batchSize
        self.flushInterval = flushInterval
        self.onFlush = onFlush
    }

    /// Starts the background flush task.
    func start() {
        guard !isRunning else { return }

        isRunning = true
        task = Task { [weak self] in
            await self?.flushLoop()
        }
    }

    /// Stops the background flush task.
    func stop() async {
        isRunning = false
        task?.cancel()
        task = nil
        await flush()
    }

    /// Adds an event to the queue.
    func enqueue(_ event: [String: Any]) async {
        queue.append(event)

        if queue.count >= batchSize {
            await flush()
        }
    }

    /// Flushes all pending events.
    func flush() async {
        guard !queue.isEmpty else { return }

        let events = queue
        queue.removeAll()

        do {
            try await onFlush(events)
        } catch {
            // Re-queue events on failure
            queue = events + queue
        }
    }

    /// Returns the number of pending events.
    var count: Int {
        queue.count
    }

    /// Whether the queue is running.
    var running: Bool {
        isRunning
    }

    private func flushLoop() async {
        while isRunning {
            try? await Task.sleep(nanoseconds: UInt64(flushInterval * 1_000_000_000))

            guard isRunning else { break }

            await flush()
        }
    }
}
