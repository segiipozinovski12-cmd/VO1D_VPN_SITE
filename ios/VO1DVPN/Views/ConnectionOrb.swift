import SwiftUI

struct ConnectionOrb: View {
    @Environment(\.vo1dReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    let phase: ConnectionPhase
    let action: () -> Void

    @State private var appeared = false

    private var connected: Bool { phase == .connected }
    private var motion: Bool { !reduceMotion && scenePhase == .active }

    private var accent: Color {
        switch phase {
        case .connected:
            return VO1DStyle.green
        case .failed:
            return VO1DStyle.red
        default:
            return .white
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(connected ? 0.115 : phase.isBusy ? 0.070 : 0.035),
                            .white.opacity(0.012),
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
                        colors: [
                            .white.opacity(0.055),
                            .white.opacity(phase.isBusy ? 0.20 : 0.115),
                            .white.opacity(0.045)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .padding(8)

            Circle()
                .stroke(.white.opacity(0.045), lineWidth: 1)
                .padding(18)

            Circle()
                .stroke(.white.opacity(0.070), lineWidth: 1)
                .padding(28)

            if motion && !phase.isBusy {
                BreathingHalo(
                    color: accent,
                    connected: connected
                )
                .padding(34)
            }

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            accent.opacity(connected ? 0.88 : 0.28),
                            .white.opacity(connected ? 0.24 : 0.08),
                            accent.opacity(connected ? 0.55 : 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: connected ? 1.8 : 0.85
                )
                .padding(39)
                .shadow(
                    color: accent.opacity(connected ? 0.20 : phase.isBusy ? 0.09 : 0.03),
                    radius: connected ? 12 : 5
                )

            Circle()
                .stroke(.white.opacity(0.07), lineWidth: 0.7)
                .padding(48)

            if phase.isBusy {
                OrbitSegments(
                    animated: motion,
                    accent: accent
                )
                .id("busy-\(phase.rawValue)-\(motion)")
                .padding(27)
                .transition(
                    reduceMotion
                    ? .opacity
                    : .opacity.combined(with: .scale(scale: 0.985))
                )
            } else if phase == .ready && motion {
                // Nothing remains frozen in the idle state. This trace appears,
                // travels once, and fully disappears.
                IgnitionTrace()
                    .padding(24)
                    .id("ignition-\(phase.rawValue)")
            } else if connected {
                ZStack {
                    ConnectedArrivalBurst(
                        animated: motion,
                        color: accent
                    )
                    .id("connected-arrival")

                    ConnectedSweep(
                        animated: motion,
                        color: accent
                    )
                    .id("connected-sweep-\(motion)")
                }
                .padding(26)
            }

            Button(action: action) {
                VStack(spacing: 13) {
                    Image(systemName: connected ? "checkmark.shield" : "power")
                        .font(.system(size: 42, weight: .ultraLight))
                        .symbolRenderingMode(.hierarchical)
                        .contentTransition(.symbolEffect(.replace))

                    Text(connected ? "DISCONNECT" : phase.isBusy ? "CANCEL" : "CONNECT")
                        .font(VO1DStyle.mono(9))
                        .tracking(2.2)
                        .contentTransition(.opacity)
                }
                .foregroundStyle(.white)
                .frame(width: 154, height: 154)
                .vo1dSystemGlass(
                    in: Circle(),
                    interactive: true
                )
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(connected ? 0.085 : 0.050),
                                    VO1DStyle.raised.opacity(0.74),
                                    Color.black.opacity(0.82)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.060),
                                    .clear,
                                    .black.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .allowsHitTesting(false)
                }
                .overlay {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.24),
                                    .white.opacity(0.060),
                                    accent.opacity(connected ? 0.13 : 0.045)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(
                    color: .black.opacity(0.36),
                    radius: 18,
                    y: 10
                )
                .shadow(
                    color: accent.opacity(connected ? 0.12 : 0.025),
                    radius: connected ? 18 : 6
                )
                .contentShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.94))
            .accessibilityLabel(
                connected
                ? "Disconnect VPN"
                : phase.isBusy
                    ? "Cancel connection"
                    : "Connect VPN"
            )
            .accessibilityIdentifier("connection.control")
            .accessibilityValue(phase.rawValue)
        }
        .frame(width: 286, height: 286)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared || reduceMotion ? 1 : 0.965)
        .onAppear {
            guard !appeared else { return }

            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.46)) {
                    appeared = true
                }
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.34),
            value: phase
        )
    }
}

private struct IgnitionTrace: View {
    @State private var end: CGFloat = 0.015
    @State private var rotation: Double = -62
    @State private var alpha: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0.015, to: end)
            .stroke(
                LinearGradient(
                    colors: [
                        .white.opacity(0.98),
                        .white.opacity(0.60),
                        .white.opacity(0.08)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(
                    lineWidth: 1.55,
                    lineCap: .round
                )
            )
            .rotationEffect(.degrees(rotation))
            .opacity(alpha)
            .shadow(color: .white.opacity(0.12), radius: 5)
            .onAppear {
                end = 0.015
                rotation = -62
                alpha = 0

                withAnimation(.easeOut(duration: 0.24)) {
                    end = 0.20
                    alpha = 1
                }

                withAnimation(.easeInOut(duration: 0.76).delay(0.10)) {
                    rotation = 60
                }

                withAnimation(.easeOut(duration: 0.30).delay(0.72)) {
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
            .stroke(
                color.opacity(
                    expanded
                    ? 0.018
                    : connected
                        ? 0.16
                        : 0.065
                ),
                lineWidth: 1
            )
            .scaleEffect(expanded ? 1.055 : 1)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: connected ? 3.5 : 4.3)
                    .repeatForever(autoreverses: true)
                ) {
                    expanded = true
                }
            }
            .allowsHitTesting(false)
    }
}


private struct ConnectedArrivalBurst: View {
    let animated: Bool
    let color: Color

    @State private var outerScale: CGFloat = 0.82
    @State private var innerScale: CGFloat = 0.90
    @State private var alpha = 0.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(alpha * 0.28), lineWidth: 1)
                .scaleEffect(outerScale)

            Circle()
                .stroke(color.opacity(alpha * 0.22), lineWidth: 1.2)
                .scaleEffect(innerScale)
                .padding(18)
        }
        .onAppear {
            guard animated else { return }

            outerScale = 0.82
            innerScale = 0.90
            alpha = 0.9

            withAnimation(.easeOut(duration: 0.72)) {
                outerScale = 1.11
                innerScale = 1.04
                alpha = 0
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
            .trim(from: 0.02, to: 0.14)
            .stroke(
                LinearGradient(
                    colors: [
                        color.opacity(0.025),
                        color.opacity(0.52),
                        .white.opacity(0.10)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(
                    lineWidth: 1.15,
                    lineCap: .round
                )
            )
            .rotationEffect(.degrees(rotation ? 360 : 0))
            .opacity(animated ? 1 : 0.30)
            .onAppear {
                guard animated else { return }

                withAnimation(
                    .linear(duration: 10)
                    .repeatForever(autoreverses: false)
                ) {
                    rotation = true
                }
            }
            .allowsHitTesting(false)
    }
}

private struct OrbitSegments: View {
    let animated: Bool
    let accent: Color

    @State private var rotation = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.03, to: 0.24)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white,
                            .white.opacity(0.58),
                            .white.opacity(0.10)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(
                        lineWidth: 1.9,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(rotation ? 360 : 0))

            Circle()
                .trim(from: 0.41, to: 0.61)
                .stroke(
                    .white.opacity(pulse ? 0.34 : 0.16),
                    style: StrokeStyle(
                        lineWidth: 0.9,
                        lineCap: .round
                    )
                )
                .padding(17)
                .rotationEffect(.degrees(rotation ? -360 : 0))

            Circle()
                .fill(.white)
                .frame(width: 4, height: 4)
                .shadow(color: accent.opacity(0.22), radius: 5)
                .offset(y: -116)
                .rotationEffect(.degrees(rotation ? 360 : 0))
        }
        .onAppear {
            guard animated else { return }

            withAnimation(
                .linear(duration: 1.7)
                .repeatForever(autoreverses: false)
            ) {
                rotation = true
            }

            withAnimation(
                .easeInOut(duration: 0.78)
                .repeatForever(autoreverses: true)
            ) {
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
