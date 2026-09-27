import SwiftUI

struct ConnectionOrb: View {
    @Environment(\.vo1dReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let phase: ConnectionPhase
    let action: () -> Void
    private var connected: Bool { phase == .connected }
    private var motion: Bool { !reduceMotion && scenePhase == .active }

    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [.white.opacity(connected ? 0.12 : 0.055), .clear], center: .center, startRadius: 24, endRadius: 145))
            OrbTicks().stroke(.white.opacity(0.18), lineWidth: 1).padding(8)
            Circle().stroke(.white.opacity(0.08), lineWidth: 1).padding(24)
            if motion && !phase.isBusy {
                BreathingHalo(connected: connected).padding(32)
            }
            Circle().stroke(.white.opacity(connected ? 0.86 : 0.22), lineWidth: connected ? 1.6 : 0.7).padding(39)
            Circle().stroke(.white.opacity(0.10), lineWidth: 0.7).padding(47)
            if phase.isBusy {
                OrbitSegments(animated: motion).id(motion).padding(28)
                    .transition(.opacity)
            } else {
                Circle().trim(from: 0.57, to: 0.68).stroke(.white.opacity(0.72), style: StrokeStyle(lineWidth: 1.5, lineCap: .round)).padding(24)
            }
            Button(action: action) {
                VStack(spacing: 13) {
                    Image(systemName: connected ? "checkmark.shield" : "power")
                        .font(.system(size: 42, weight: .ultraLight))
                        .contentTransition(.opacity)
                    Text(connected ? "DISCONNECT" : phase.isBusy ? "CANCEL" : "CONNECT")
                        .font(VO1DStyle.mono(9)).tracking(2.2)
                }
                .foregroundStyle(.white)
                .frame(width: 154, height: 154)
                .background(LinearGradient(colors: [Color(white: 0.15), Color(white: 0.055)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
                .contentShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.95))
            .accessibilityLabel(connected ? "Disconnect VPN" : phase.isBusy ? "Cancel connection" : "Connect VPN")
            .accessibilityIdentifier("connection.control")
            .accessibilityValue(phase.rawValue)
        }
        .frame(width: 286, height: 286)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: phase)
    }
}

private struct BreathingHalo: View {
    let connected: Bool
    @State private var expanded = false
    var body: some View {
        Circle().stroke(.white.opacity(expanded ? 0.035 : 0.17), lineWidth: 1)
            .scaleEffect(expanded ? 1.055 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: connected ? 3.8 : 4.5).repeatForever(autoreverses: true)) { expanded = true }
            }
            .allowsHitTesting(false)
    }
}

private struct OrbitSegments: View {
    let animated: Bool
    @State private var rotation = false
    var body: some View {
        ZStack {
            Circle().trim(from: 0.04, to: 0.28).stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(rotation ? 360 : 0))
            Circle().trim(from: 0.42, to: 0.65).stroke(.white.opacity(0.45), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                .padding(18).rotationEffect(.degrees(rotation ? -360 : 0))
            Circle().fill(.white).frame(width: 4, height: 4).offset(y: -115)
                .rotationEffect(.degrees(rotation ? 360 : 0))
        }
        .onAppear {
            if animated { withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) { rotation = true } }
        }
        .allowsHitTesting(false)
    }
}

private struct OrbTicks: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        for tick in 0..<60 {
            let angle = Double(tick) * .pi / 30
            let inner = radius - (tick % 5 == 0 ? 7 : 3)
            path.move(to: CGPoint(x: rect.midX + CGFloat(cos(angle) as Double) * inner, y: rect.midY + CGFloat(sin(angle) as Double) * inner))
            path.addLine(to: CGPoint(x: rect.midX + CGFloat(cos(angle) as Double) * radius, y: rect.midY + CGFloat(sin(angle) as Double) * radius))
        }
        return path
    }
}
