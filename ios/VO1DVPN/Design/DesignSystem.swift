import SwiftUI

enum VO1DStyle {
    // VO1D stays intentionally near-monochrome. Color is reserved for state and errors.
    static let background = Color(red: 0.010, green: 0.011, blue: 0.014)
    static let backgroundRaised = Color(red: 0.022, green: 0.024, blue: 0.029)
    static let panel = Color(red: 0.050, green: 0.053, blue: 0.061)
    static let raised = Color(red: 0.088, green: 0.091, blue: 0.102)
    static let secondary = Color(white: 0.64)

    static let ice = Color(white: 0.92)
    static let teal = Color(white: 0.72)
    static let violet = Color(white: 0.54)

    // Functional colors only.
    static let green = Color(red: 0.52, green: 0.82, blue: 0.62)
    static let amber = Color(red: 0.87, green: 0.70, blue: 0.42)
    static let red = Color(red: 0.88, green: 0.44, blue: 0.46)

    static func latencyColor(_ ping: Int?) -> Color {
        guard let ping else { return secondary }
        return ping < 70 ? green : ping < 120 ? amber : red
    }

    static func quality(_ ping: Int?) -> String {
        guard let ping else { return "UNAVAILABLE" }
        return ping < 50 ? "EXCELLENT" : ping < 80 ? "GOOD" : ping < 120 ? "FAIR" : "HIGH LATENCY"
    }

    static func mono(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

private struct MotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var vo1dReduceMotion: Bool {
        get { self[MotionKey.self] }
        set { self[MotionKey.self] = newValue }
    }
}

extension View {
    @ViewBuilder
    func vo1dSystemGlass<S: Shape>(
        in shape: S,
        interactive: Bool = false
    ) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            if interactive {
                self.glassEffect(
                    .regular.interactive(),
                    in: shape
                )
            } else {
                self.glassEffect(
                    .regular,
                    in: shape
                )
            }
        } else {
            self.background(
                .ultraThinMaterial,
                in: shape
            )
        }
        #else
        self.background(
            .ultraThinMaterial,
            in: shape
        )
        #endif
    }
}

struct DeepSpaceBackdrop: View {
    var body: some View {
        ZStack {
            VO1DStyle.background

            RadialGradient(
                colors: [.white.opacity(0.035), .clear],
                center: UnitPoint(x: 0.16, y: 0.05),
                startRadius: 0,
                endRadius: 410
            )

            RadialGradient(
                colors: [.white.opacity(0.020), .clear],
                center: UnitPoint(x: 0.88, y: 0.32),
                startRadius: 0,
                endRadius: 350
            )

            LinearGradient(
                colors: [
                    .white.opacity(0.010),
                    .clear,
                    Color.black.opacity(0.30)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .accessibilityHidden(true)
    }
}

struct Surface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var highlighted = false
    var radius: CGFloat = 22

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        Group {
            if reduceTransparency {
                content.background(
                    VO1DStyle.panel.opacity(0.98),
                    in: shape
                )
            } else {
                content.vo1dSystemGlass(
                    in: shape
                )
            }
        }
            .background(
                shape.fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(highlighted ? 0.070 : 0.038),
                            VO1DStyle.panel.opacity(highlighted ? 0.78 : 0.64),
                            VO1DStyle.backgroundRaised.opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .overlay {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(highlighted ? 0.080 : 0.046),
                                .clear,
                                .black.opacity(0.050)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .allowsHitTesting(false)
            }
            .overlay {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(highlighted ? 0.30 : 0.15),
                                .white.opacity(0.060),
                                .white.opacity(highlighted ? 0.12 : 0.030)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
            .shadow(
                color: .black.opacity(highlighted ? 0.28 : 0.17),
                radius: highlighted ? 16 : 9,
                y: highlighted ? 8 : 4
            )
    }
}

struct GlassCircle: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var highlighted = false

    func body(content: Content) -> some View {
        Group {
            if reduceTransparency {
                content.background(
                    VO1DStyle.raised.opacity(0.98),
                    in: Circle()
                )
            } else {
                content.vo1dSystemGlass(
                    in: Circle(),
                    interactive: true
                )
            }
        }
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(highlighted ? 0.14 : 0.075),
                            VO1DStyle.backgroundRaised.opacity(0.82),
                            .black.opacity(0.18)
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
                            colors: [.white.opacity(0.24), .white.opacity(0.045)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.28), radius: 12, y: 7)
    }
}

private struct RevealModifier: ViewModifier {
    let visible: Bool
    let reduceMotion: Bool
    let delay: Double
    let distance: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : distance)
            .scaleEffect(visible || reduceMotion ? 1 : 0.992)
            .animation(
                reduceMotion
                ? nil
                : .easeOut(duration: 0.44).delay(delay),
                value: visible
            )
    }
}

extension View {
    func vo1dSurface(highlighted: Bool = false, radius: CGFloat = 22) -> some View {
        modifier(Surface(highlighted: highlighted, radius: radius))
    }

    func vo1dGlassCircle(highlighted: Bool = false) -> some View {
        modifier(GlassCircle(highlighted: highlighted))
    }

    func vo1dReveal(
        _ visible: Bool,
        reduceMotion: Bool,
        delay: Double = 0,
        distance: CGFloat = 10
    ) -> some View {
        modifier(
            RevealModifier(
                visible: visible,
                reduceMotion: reduceMotion,
                delay: delay,
                distance: distance
            )
        )
    }
}

struct Eyebrow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(VO1DStyle.mono())
            .tracking(1.7)
            .foregroundStyle(VO1DStyle.secondary)
    }
}

struct StatusPill: View {
    let text: String
    var connected = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connected ? VO1DStyle.green : VO1DStyle.secondary)
                .frame(width: 5, height: 5)
                .shadow(color: connected ? VO1DStyle.green.opacity(0.42) : .clear, radius: 4)

            Text(text)
                .font(VO1DStyle.mono(9))
                .tracking(0.6)
        }
        .foregroundStyle(connected ? VO1DStyle.green : VO1DStyle.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .vo1dSystemGlass(in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.09), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

struct PageHeading: View {
    let number: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "VO1D / \(number)")

            Text(title)
                .font(.system(size: 34, weight: .semibold))
                .tracking(-1.2)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(VO1DStyle.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 16)
    }
}

struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            Text(title)
                .foregroundStyle(VO1DStyle.secondary)

            Spacer(minLength: 4)

            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.vertical, 12)
    }
}

struct DividerLine: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(0.025),
                        .white.opacity(0.095),
                        .white.opacity(0.025)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}
