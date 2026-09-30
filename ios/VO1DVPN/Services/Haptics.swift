import UIKit

@MainActor
enum Haptics {
    enum Event { case selection, connect, success, error }
    static func play(_ event: Event, enabled: Bool) {
        guard enabled else { return }
        #if !targetEnvironment(simulator)
        switch event {
        case .selection: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .connect: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error: UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        #endif
    }
}
