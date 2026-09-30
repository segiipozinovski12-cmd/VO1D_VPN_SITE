import Foundation
import Combine

/// Only dashboard leaves observe this object. A tick never invalidates Home or its orb.
@MainActor
final class SessionMonitor: ObservableObject {
    @Published private(set) var stats = LiveStats()
    private var timer: Task<Void, Never>?
    private var startedAt: Date?
    private var lastTick = Date()
    private var connected = false
    private var foreground = true
    var hasTrafficMeasurements: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false // The production core currently exposes no byte-counter API.
        #endif
    }
    func setConnected(_ connected: Bool, since: Date? = nil) {
        guard self.connected != connected else { return }
        self.connected = connected
        if connected {
            startedAt = since ?? Date()
            stats = LiveStats()
            #if targetEnvironment(simulator)
            stats.downloadMbps = 84.2
            stats.uploadMbps = 21.4
            #endif
        }
        updateTimer()
    }
    func setForeground(_ active: Bool) { foreground = active; updateTimer() }
    func reset() {
        connected = false
        startedAt = nil
        timer?.cancel()
        timer = nil
        stats = LiveStats()
    }
    private func updateTimer() {
        timer?.cancel()
        timer = nil
        guard connected, foreground else { return }
        lastTick = Date()
        tick()
        timer = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                self?.tick()
            }
        }
    }
    private func tick() {
        guard let startedAt, connected else { return }
        let now = Date()
        let elapsed = min(2, max(0, now.timeIntervalSince(lastTick)))
        var next = stats
        next.sessionSeconds = max(0, Int(now.timeIntervalSince(startedAt)))
        #if targetEnvironment(simulator)
        next.downloadMbps = min(98, max(68, next.downloadMbps + Double.random(in: -3.2...3.2)))
        next.uploadMbps = min(29, max(16, next.uploadMbps + Double.random(in: -1.3...1.3)))
        next.downloadedMB += next.downloadMbps * elapsed / 8
        next.uploadedMB += next.uploadMbps * elapsed / 8
        #endif
        lastTick = now
        stats = next
    }
    deinit { timer?.cancel() }
}
