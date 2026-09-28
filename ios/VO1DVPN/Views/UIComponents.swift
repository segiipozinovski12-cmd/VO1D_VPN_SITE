import SwiftUI

struct ScaleButtonStyle: ButtonStyle {
    @Environment(\.vo1dReduceMotion) private var reduceMotion
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .brightness(configuration.isPressed ? 0.035 : 0)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: configuration.isPressed)
    }
}

struct IconButton: View {
    let icon: String
    let label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 44, height: 44)
                .vo1dGlassCircle()
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.93))
        .accessibilityLabel(label)
    }
}

struct PrimaryButton: View {
    let title: String
    var icon = "arrow.up.right"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(18)
            .foregroundStyle(.black)
            .background(
                LinearGradient(
                    colors: [.white, Color(white: 0.90)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.9), lineWidth: 1)
            }
            .shadow(color: VO1DStyle.ice.opacity(0.12), radius: 14, y: 8)
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.97))
    }
}

struct EmptyState: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "globe.europe.africa")
                .font(.system(size: 32, weight: .ultraLight))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(VO1DStyle.ice)

            Text(title).font(.headline)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(VO1DStyle.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 38)
        .padding(.horizontal, 20)
        .vo1dSurface()
    }
}
