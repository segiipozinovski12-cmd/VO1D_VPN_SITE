import Foundation
import Network

actor PingService {
    func ping(host: String, port: Int, timeout: TimeInterval = 2) async -> Int? {
        guard !host.isEmpty, (1...65535).contains(port),
              let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else { return nil }
        let started = ContinuousClock.now
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        let result = PingResult(connection: connection)
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard result.install(continuation) else { return }
                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        let components = started.duration(to: .now).components
                        let ms = Int(components.seconds * 1000) + Int(components.attoseconds / 1_000_000_000_000_000)
                        result.finish(max(1, ms))
                    case .failed, .cancelled: result.finish(nil)
                    default: break
                    }
                }
                connection.start(queue: .global(qos: .utility))
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) { result.finish(nil) }
            }
        } onCancel: { result.finish(nil) }
    }
}

/// Cancellation, timeout and NWConnection callbacks may race. The lock protects
/// the continuation and completion flag; callbacks run after releasing the lock.
private final class PingResult: @unchecked Sendable {
    private let lock = NSLock()
    private let connection: NWConnection
    private var continuation: CheckedContinuation<Int?, Never>?
    private var finished = false
    init(connection: NWConnection) { self.connection = connection }
    func install(_ continuation: CheckedContinuation<Int?, Never>) -> Bool {
        lock.lock()
        if finished {
            lock.unlock()
            continuation.resume(returning: nil)
            return false
        }
        self.continuation = continuation
        lock.unlock()
        return true
    }
    func finish(_ value: Int?) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        let callback = continuation
        continuation = nil
        lock.unlock()
        connection.cancel()
        callback?.resume(returning: value)
    }
}
