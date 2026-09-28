import Foundation
import Combine

/// Dashboard-only session state. Home and the connection orb stay isolated
/// from the once-per-second statistics publisher.
@MainActor
final class SessionMonitor: ObservableObject {
    @Published private(set) var stats = LiveStats()
    @Published private(set) var hasTrafficMeasurements: Bool

    private var timer: Task<Void, Never>?
    private var startedAt: Date?
    private var lastTick = Date()
    private var lastTransferSampleAt: Date?
    private var totalReceivedBytes: Int64 = 0
    private var totalSentBytes: Int64 = 0
    private var connected = false
    private var foreground = true

    init() {
        #if targetEnvironment(simulator)
        hasTrafficMeasurements = true
        #else
        hasTrafficMeasurements = false
        #endif
    }

    func setConnected(_ connected: Bool, since: Date? = nil) {
        guard self.connected != connected else { return }
        self.connected = connected

        if connected {
            startedAt = since ?? Date()
            lastTransferSampleAt = nil
            totalReceivedBytes = 0
            totalSentBytes = 0
            stats = LiveStats()

            #if targetEnvironment(simulator)
            hasTrafficMeasurements = true
            stats.downloadMbps = 84.2
            stats.uploadMbps = 21.4
            #else
            hasTrafficMeasurements = false
            #endif
        } else {
            lastTransferSampleAt = nil
        }

        updateTimer()
    }

    func setForeground(_ active: Bool) {
        foreground = active
        updateTimer()
    }

    func applyTransfer(_ delta: TunnelTrafficDelta) {
        #if !targetEnvironment(simulator)
        guard connected else { return }

        let now = Date()
        let interval = max(
            0.25,
            min(
                3.0,
                now.timeIntervalSince(
                    lastTransferSampleAt ?? now.addingTimeInterval(-1)
                )
            )
        )

        let received = max(Int64(0), delta.received)
        let sent = max(Int64(0), delta.sent)

        totalReceivedBytes += received
        totalSentBytes += sent

        var next = stats
        next.downloadMbps = Double(received) * 8 / 1_000_000 / interval
        next.uploadMbps = Double(sent) * 8 / 1_000_000 / interval
        next.downloadedMB = Double(totalReceivedBytes) / 1_048_576
        next.uploadedMB = Double(totalSentBytes) / 1_048_576

        lastTransferSampleAt = now
        hasTrafficMeasurements = true
        stats = next
        #endif
    }

    func reset() {
        connected = false
        startedAt = nil
        lastTransferSampleAt = nil
        totalReceivedBytes = 0
        totalSentBytes = 0
        timer?.cancel()
        timer = nil
        stats = LiveStats()

        #if targetEnvironment(simulator)
        hasTrafficMeasurements = true
        #else
        hasTrafficMeasurements = false
        #endif
    }

    private func updateTimer() {
        timer?.cancel()
        timer = nil
        guard connected, foreground else { return }

        lastTick = Date()
        tick()

        timer = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                self?.tick()
            }
        }
    }

    private func tick() {
        guard let startedAt, connected else { return }

        let now = Date()
        let elapsed = min(2, max(0, now.timeIntervalSince(lastTick)))
        var next = stats
        next.sessionSeconds = max(
            0,
            Int(now.timeIntervalSince(startedAt))
        )

        #if targetEnvironment(simulator)
        next.downloadMbps = min(
            98,
            max(68, next.downloadMbps + Double.random(in: -3.2...3.2))
        )
        next.uploadMbps = min(
            29,
            max(16, next.uploadMbps + Double.random(in: -1.3...1.3))
        )
        next.downloadedMB += next.downloadMbps * elapsed / 8
        next.uploadedMB += next.uploadMbps * elapsed / 8
        #endif

        lastTick = now
        stats = next
    }

    deinit {
        timer?.cancel()
    }
}
