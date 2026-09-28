import SwiftUI

struct ConnectionOrb: View {
    @Environment(\.vo1dReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    let phase: ConnectionPhase
    let action: () -> Void

    private var connected: Bool { phase == .connected }
    private var motion: Bool { !reduceMotion && scenePhase == .active }

    private var accent: Color {
        switch phase {
        case .connected: return VO1DStyle.green
        case .failed: return VO1DStyle.red
        case .preparing, .routing, .securing, .switching, .disconnecting: return VO1DStyle.ice
        case .ready: return .white
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(connected ? 0.15 : phase.isBusy ? 0.11 : 0.055),
                            VO1DStyle.violet.opacity(0.045),
                            .clear
                        ],
                        center: .center,
                        startRadius: 18,
                        endRadius: 150
                    )
                )

            OrbTicks()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.08), accent.opacity(0.25), .white.opacity(0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .padding(8)

            Circle().stroke(.white.opacity(0.055), lineWidth: 1).padding(18)
            Circle().stroke(.white.opacity(0.075), lineWidth: 1).padding(28)

            if motion && !phase.isBusy {
                BreathingHalo(color: accent, connected: connected)
                    .padding(34)
            }

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            accent.opacity(connected ? 0.92 : 0.30),
                            .white.opacity(connected ? 0.28 : 0.08),
                            accent.opacity(connected ? 0.62 : 0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: connected ? 1.9 : 0.9
                )
                .padding(39)
                .shadow(color: accent.opacity(connected ? 0.28 : 0.06), radius: connected ? 12 : 4)

            Circle().stroke(.white.opacity(0.08), lineWidth: 0.7).padding(48)

            if phase.isBusy {
                OrbitSegments(animated: motion, color: accent)
                    .id(phase.rawValue + String(motion))
                    .padding(27)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if phase == .ready && motion {
                // The previously static white arc is now only a short ignition gesture.
                // It draws in, travels a little, then fully disappears.
                IgnitionTrace(color: VO1DStyle.ice)
                    .padding(24)
                    .id("ignition-\(phase.rawValue)")
            } else if connected {
                ConnectedSweep(animated: motion, color: accent)
                    .padding(26)
            }

            Button(action: action) {
                VStack(spacing: 13) {
                    Image(systemName: connected ? "checkmark.shield" : "power")
                        .font(.system(size: 42, weight: .ultraLight))
                        .symbolRenderingMode(.hierarchical)
                        .contentTransition(.opacity)

                    Text(connected ? "DISCONNECT" : phase.isBusy ? "CANCEL" : "CONNECT")
                        .font(VO1DStyle.mono(9))
                        .tracking(2.2)
                }
                .foregroundStyle(.white)
                .frame(width: 154, height: 154)
                .background(.ultraThinMaterial, in: Circle())
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(connected ? 0.14 : 0.07),
                                Color(red: 0.055, green: 0.064, blue: 0.078).opacity(0.92),
                                Color.black.opacity(0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .overlay {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.23), .white.opacity(0.06), accent.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: accent.opacity(connected ? 0.19 : 0.07), radius: 20)
                .contentShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.94))
            .accessibilityLabel(connected ? "Disconnect VPN" : phase.isBusy ? "Cancel connection" : "Connect VPN")
            .accessibilityIdentifier("connection.control")
            .accessibilityValue(phase.rawValue)
        }
        .frame(width: 286, height: 286)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.34), value: phase)
    }
}

private struct IgnitionTrace: View {
    let color: Color

    @State private var end: CGFloat = 0.02
    @State private var rotation: Double = -54
    @State private var alpha: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0.02, to: end)
            .stroke(
                LinearGradient(
                    colors: [.white.opacity(0.96), color.opacity(0.75), .white.opacity(0.12)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
            )
            .rotationEffect(.degrees(rotation))
            .opacity(alpha)
            .shadow(color: color.opacity(0.28), radius: 5)
            .onAppear {
                end = 0.02
                rotation = -54
                alpha = 0

                withAnimation(.easeOut(duration: 0.28)) {
                    end = 0.22
                    alpha = 1
                }

                withAnimation(.easeInOut(duration: 0.82).delay(0.14)) {
                    rotation = 72
                }

                withAnimation(.easeOut(duration: 0.34).delay(0.82)) {
                    alpha = 0
                }
            }
            .allowsHitTesting(false)
    }
}

private struct BreathingHalo: View {
    let color: Color
    let connected: Bool

    @State private var expanded = false

    var body: some View {
        Circle()
            .stroke(color.opacity(expanded ? 0.025 : connected ? 0.22 : 0.10), lineWidth: 1)
            .scaleEffect(expanded ? 1.065 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: connected ? 3.4 : 4.2).repeatForever(autoreverses: true)) {
                    expanded = true
                }
            }
            .allowsHitTesting(false)
    }
}

private struct ConnectedSweep: View {
    let animated: Bool
    let color: Color

    @State private var rotation = false

    var body: some View {
        Circle()
            .trim(from: 0.02, to: 0.16)
            .stroke(
                LinearGradient(
                    colors: [color.opacity(0.06), color.opacity(0.68), .white.opacity(0.15)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
            )
            .rotationEffect(.degrees(rotation ? 360 : 0))
            .opacity(animated ? 1 : 0.45)
            .onAppear {
                guard animated else { return }
                withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
                    rotation = true
                }
            }
            .allowsHitTesting(false)
    }
}

private struct OrbitSegments: View {
    let animated: Bool
    let color: Color

    @State private var rotation = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.03, to: 0.25)
                .stroke(
                    LinearGradient(
                        colors: [.white, color.opacity(0.62), .white.opacity(0.12)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(rotation ? 360 : 0))

            Circle()
                .trim(from: 0.40, to: 0.62)
                .stroke(
                    color.opacity(pulse ? 0.52 : 0.24),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round)
                )
                .padding(17)
                .rotationEffect(.degrees(rotation ? -360 : 0))

            Circle()
                .fill(.white)
                .frame(width: 4, height: 4)
                .shadow(color: color.opacity(0.70), radius: 7)
                .offset(y: -116)
                .rotationEffect(.degrees(rotation ? 360 : 0))
        }
        .onAppear {
            guard animated else { return }
            withAnimation(.linear(duration: 1.65).repeatForever(autoreverses: false)) {
                rotation = true
            }
            withAnimation(.easeInOut(duration: 0.78).repeatForever(autoreverses: true)) {
                pulse = true
            }
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
            path.move(
                to: CGPoint(
                    x: rect.midX + CGFloat(cos(angle)) * inner,
                    y: rect.midY + CGFloat(sin(angle)) * inner
                )
            )
            path.addLine(
                to: CGPoint(
                    x: rect.midX + CGFloat(cos(angle)) * radius,
                    y: rect.midY + CGFloat(sin(angle)) * radius
                )
            )
        }

        return path
    }
}
