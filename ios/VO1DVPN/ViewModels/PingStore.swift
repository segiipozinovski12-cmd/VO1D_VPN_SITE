import Foundation
import Combine

@MainActor
final class PingStore: ObservableObject {
    @Published private(set) var values: [String: Int] = [:]
    @Published private(set) var isRefreshing = false
    @Published private(set) var measuredAt: Date?
    private let pinger = PingService()
    private var servers: [VO1DServer] = []
    private var loop: Task<Void, Never>?
    private var revision = UUID()
    private var refreshID: UUID?

    func configure(_ servers: [VO1DServer]) {
        stop()
        self.servers = servers
        values = values.filter { code, _ in servers.contains { $0.code == code } }
        measuredAt = nil
    }
    func start(live: Bool) {
        loop?.cancel()
        guard live, !servers.isEmpty else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                do { try await Task.sleep(for: .seconds(8)) } catch { return }
            }
        }
    }
    func stop() {
        revision = UUID()
        loop?.cancel()
        loop = nil
        refreshID = nil
        isRefreshing = false
    }
    func refresh() async {
        guard !isRefreshing, !servers.isEmpty else { return }
        let epoch = revision
        let requestID = UUID()
        refreshID = requestID
        isRefreshing = true
        defer { if refreshID == requestID { isRefreshing = false; refreshID = nil } }
        var next: [String: Int] = [:]
        #if targetEnvironment(simulator)
        let base = ["DE": 31, "NL": 36, "RU": 40, "FI": 48, "FR": 53,
                    "UK": 59, "TR": 67, "US": 94, "CA": 102, "SG": 141, "JP": 155]
        do { try await Task.sleep(for: .milliseconds(240)) } catch { return }
        for server in servers {
            let center = base[server.code] ?? 75
            let previous = values[server.code] ?? center
            next[server.code] = min(center + 12, max(center - 12, previous + Int.random(in: -4...4)))
        }
        #else
        let snapshot = servers
        await withTaskGroup(of: (String, Int?).self) { group in
            for server in snapshot {
                group.addTask { [pinger] in
                    (server.code, await pinger.ping(host: server.probeHost, port: server.probePort))
                }
            }
            for await (code, value) in group { if let value { next[code] = value } }
        }
        #endif
        guard !Task.isCancelled, revision == epoch else { return }
        values = next // One batch, without animating the entire list.
        measuredAt = Date()
    }
    deinit { loop?.cancel() }
}
