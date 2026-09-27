import SwiftUI

enum VO1DStyle {
    static let background = Color(red: 0.025, green: 0.027, blue: 0.032)
    static let panel = Color(red: 0.066, green: 0.072, blue: 0.08)
    static let raised = Color(red: 0.105, green: 0.112, blue: 0.124)
    static let secondary = Color(white: 0.61)
    static let green = Color(red: 0.53, green: 0.79, blue: 0.64)
    static let amber = Color(red: 0.83, green: 0.69, blue: 0.44)
    static let red = Color(red: 0.87, green: 0.48, blue: 0.47)
    static func latencyColor(_ ping: Int?) -> Color {
        guard let ping else { return secondary }
        return ping < 70 ? green : ping < 120 ? amber : red
    }
    static func quality(_ ping: Int?) -> String {
        guard let ping else { return "UNAVAILABLE" }
        return ping < 50 ? "EXCELLENT" : ping < 80 ? "GOOD" : ping < 120 ? "FAIR" : "HIGH LATENCY"
    }
    static func mono(_ size: CGFloat = 10) -> Font { .system(size: size, weight: .medium, design: .monospaced) }
}

private struct MotionKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var vo1dReduceMotion: Bool {
        get { self[MotionKey.self] }
        set { self[MotionKey.self] = newValue }
    }
}

struct Surface: ViewModifier {
    var highlighted = false
    var radius: CGFloat = 22
    func body(content: Content) -> some View {
        content
            .background(highlighted ? VO1DStyle.raised : VO1DStyle.panel, in: RoundedRectangle(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(highlighted ? 0.27 : 0.12), .white.opacity(0.045)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}
extension View {
    func vo1dSurface(highlighted: Bool = false, radius: CGFloat = 22) -> some View {
        modifier(Surface(highlighted: highlighted, radius: radius))
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text).font(VO1DStyle.mono()).tracking(1.7).foregroundStyle(VO1DStyle.secondary)
    }
}

struct StatusPill: View {
    let text: String
    var connected = false
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(connected ? VO1DStyle.green : VO1DStyle.secondary).frame(width: 5, height: 5)
            Text(text).font(VO1DStyle.mono(9)).tracking(0.6)
        }
        .foregroundStyle(connected ? VO1DStyle.green : VO1DStyle.secondary)
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(.white.opacity(0.045), in: Capsule())
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
            Text(title).font(.system(size: 34, weight: .semibold)).tracking(-1.2)
            Text(subtitle).font(.subheadline).foregroundStyle(VO1DStyle.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 16)
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
        }.font(.subheadline).padding(.vertical, 12)
    }
}

struct DividerLine: View {
    var body: some View { Rectangle().fill(.white.opacity(0.07)).frame(height: 1).accessibilityHidden(true) }
}
