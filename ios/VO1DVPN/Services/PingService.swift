import Foundation
import Network

actor PingService {
    func ping(host: String, port: Int, timeout: TimeInterval = 2.0) async -> Int? {
        guard !host.isEmpty, port > 0, let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            return nil
        }

        let started = ContinuousClock.now
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let lock = NSLock()
                var finished = false

                func finish(_ value: Int?) {
                    lock.lock()
                    defer { lock.unlock() }
                    guard !finished else { return }
                    finished = true
                    connection.cancel()
                    continuation.resume(returning: value)
                }

                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        let duration = started.duration(to: .now)
                        let components = duration.components
                        let milliseconds =
                            Int(components.seconds * 1000) +
                            Int(components.attoseconds / 1_000_000_000_000_000)
                        finish(max(1, milliseconds))
                    case .failed, .cancelled:
                        finish(nil)
                    default:
                        break
                    }
                }

                connection.start(queue: .global(qos: .utility))
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                    finish(nil)
                }
            }
        } onCancel: {
            connection.cancel()
        }
    }
}
