import SwiftUI

/// UI state. Applies changes optimistically (the UI reacts immediately) and syncs with the device.
@MainActor
public final class ClimateStore: ObservableObject {
    @Published public private(set) var snapshot: Snapshot?
    @Published public private(set) var error: BackendError?
    @Published public private(set) var busy = false
    @Published public private(set) var lastUpdate: Date?

    public var state: DeviceState? { snapshot?.state }
    public var capabilities: Capabilities? { snapshot?.capabilities }
    var tint: Color { Style.mode(state?.mode).color }

    private let backend: ClimateBackend
    private let debounceNanos: UInt64
    private var inFlight = 0
    private var localEditAt = Date.distantPast
    private var pendingTarget: Task<Void, Never>?
    private var hasUnsentTarget = false

    /// - Parameters:
    ///   - autoRefresh: reads the device on start and every `pollInterval` seconds.
    ///   - debounce: wait after the last temperature click before sending.
    public init(backend: ClimateBackend, autoRefresh: Bool = true, debounce: TimeInterval = 0.6,
                pollInterval: TimeInterval = 60) {
        self.backend = backend
        self.debounceNanos = UInt64(debounce * 1_000_000_000)
        guard autoRefresh else { return }
        Task { await refresh() }
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                await self?.refresh()
            }
        }
    }

    // MARK: - Reading

    public func refresh() async {
        await run(requestedAt: Date()) { try await self.backend.snapshot() }
    }

    /// Re-reads when the panel opens, if the last reading is older than 5 s.
    public func refreshIfStale() {
        if let lastUpdate, Date().timeIntervalSince(lastUpdate) < 5 { return }
        Task { await refresh() }
    }

    // MARK: - Commands

    /// Shows the result immediately and sends it to the device in the background.
    public func apply(_ changes: Changes) {
        guard let snapshot else { return }
        self.snapshot?.state = snapshot.state.applying(changes)
        localEditAt = Date()
        Task { await send(changes) }
    }

    /// +1 / −1 degree, debounced: rapid clicks become a single command.
    public func stepTarget(_ delta: Double) {
        guard let state, let capabilities, state.usesTargetTemperature,
              capabilities.supports(.targetTemperature), let current = state.targetTemperature else { return }
        let target = min(capabilities.maxTemperature, max(capabilities.minTemperature, current + delta))
        guard target != current else { return }

        snapshot?.state.targetTemperature = target
        localEditAt = Date()
        hasUnsentTarget = true
        pendingTarget?.cancel()
        pendingTarget = Task {
            try? await Task.sleep(nanoseconds: debounceNanos)
            guard !Task.isCancelled else { return }
            hasUnsentTarget = false
            await send(Changes(targetTemperature: target))
        }
    }

    // MARK: - Internals

    /// If sending fails, re-read the device so the UI doesn't show a value that wasn't applied.
    private func send(_ changes: Changes) async {
        let ok = await run(requestedAt: Date()) { try await self.backend.apply(changes) }
        if !ok {
            await run(requestedAt: Date(), keepError: true) { try await self.backend.snapshot() }
        }
    }

    @discardableResult
    private func run(requestedAt: Date, keepError: Bool = false,
                     _ operation: @escaping () async throws -> Snapshot) async -> Bool {
        inFlight += 1
        busy = true
        defer {
            inFlight -= 1
            busy = inFlight > 0
        }
        do {
            let result = try await operation()
            // Discard responses requested before a local edit (or while an adjustment is still unsent),
            // so the old value doesn't "flicker" on screen
            if requestedAt >= localEditAt && !hasUnsentTarget {
                snapshot = result
            }
            if !keepError { error = nil }
            lastUpdate = Date()
            return true
        } catch {
            self.error = error as? BackendError ?? BackendError(error.localizedDescription, kind: .unexpected)
            return false
        }
    }
}
