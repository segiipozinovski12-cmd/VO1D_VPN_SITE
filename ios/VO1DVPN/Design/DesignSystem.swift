import SwiftUI

enum VO1DStyle {
    static let background = Color(red: 0.014, green: 0.017, blue: 0.024)
    static let backgroundRaised = Color(red: 0.025, green: 0.031, blue: 0.043)
    static let panel = Color(red: 0.055, green: 0.064, blue: 0.079)
    static let raised = Color(red: 0.092, green: 0.105, blue: 0.127)
    static let secondary = Color(red: 0.62, green: 0.65, blue: 0.70)

    // Muted, deep accents. They are intentionally not neon.
    static let ice = Color(red: 0.58, green: 0.76, blue: 0.82)
    static let teal = Color(red: 0.34, green: 0.66, blue: 0.61)
    static let violet = Color(red: 0.36, green: 0.34, blue: 0.55)
    static let green = Color(red: 0.49, green: 0.84, blue: 0.63)
    static let amber = Color(red: 0.88, green: 0.71, blue: 0.40)
    static let red = Color(red: 0.88, green: 0.42, blue: 0.45)

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

private struct MotionKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    var vo1dReduceMotion: Bool {
        get { self[MotionKey.self] }
        set { self[MotionKey.self] = newValue }
    }
}

struct DeepSpaceBackdrop: View {
    var body: some View {
        ZStack {
            VO1DStyle.background

            RadialGradient(
                colors: [VO1DStyle.violet.opacity(0.16), .clear],
                center: UnitPoint(x: 0.12, y: 0.08),
                startRadius: 0,
                endRadius: 420
            )

            RadialGradient(
                colors: [VO1DStyle.teal.opacity(0.10), .clear],
                center: UnitPoint(x: 0.88, y: 0.30),
                startRadius: 0,
                endRadius: 360
            )

            LinearGradient(
                colors: [
                    .white.opacity(0.018),
                    .clear,
                    Color.black.opacity(0.20)
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

        content
            .background(
                reduceTransparency
                ? AnyShapeStyle(VO1DStyle.panel.opacity(0.98))
                : AnyShapeStyle(.ultraThinMaterial),
                in: shape
            )
            .background(
                shape.fill(
                    LinearGradient(
                        colors: [
                            highlighted ? VO1DStyle.raised.opacity(0.78) : VO1DStyle.panel.opacity(0.68),
                            VO1DStyle.backgroundRaised.opacity(0.54)
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
                                .white.opacity(highlighted ? 0.075 : 0.048),
                                .clear,
                                VO1DStyle.ice.opacity(highlighted ? 0.045 : 0.018)
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
                                .white.opacity(highlighted ? 0.28 : 0.14),
                                .white.opacity(0.055),
                                VO1DStyle.ice.opacity(highlighted ? 0.12 : 0.035)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
            .shadow(
                color: .black.opacity(highlighted ? 0.24 : 0.15),
                radius: highlighted ? 15 : 8,
                y: highlighted ? 8 : 4
            )
    }
}

struct GlassCircle: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var highlighted = false

    func body(content: Content) -> some View {
        content
            .background(
                reduceTransparency
                ? AnyShapeStyle(VO1DStyle.raised.opacity(0.98))
                : AnyShapeStyle(.ultraThinMaterial),
                in: Circle()
            )
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(highlighted ? 0.12 : 0.075),
                            VO1DStyle.backgroundRaised.opacity(0.72)
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
                            colors: [.white.opacity(0.22), .white.opacity(0.045)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.26), radius: 12, y: 7)
    }
}

extension View {
    func vo1dSurface(highlighted: Bool = false, radius: CGFloat = 22) -> some View {
        modifier(Surface(highlighted: highlighted, radius: radius))
    }

    func vo1dGlassCircle(highlighted: Bool = false) -> some View {
        modifier(GlassCircle(highlighted: highlighted))
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
                .shadow(color: connected ? VO1DStyle.green.opacity(0.55) : .clear, radius: 5)

            Text(text)
                .font(VO1DStyle.mono(9))
                .tracking(0.6)
        }
        .foregroundStyle(connected ? VO1DStyle.green : VO1DStyle.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
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
            Text(title).foregroundStyle(VO1DStyle.secondary)
            Spacer(minLength: 4)
            Text(value).multilineTextAlignment(.trailing)
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
                    colors: [.white.opacity(0.03), .white.opacity(0.10), .white.opacity(0.03)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}
