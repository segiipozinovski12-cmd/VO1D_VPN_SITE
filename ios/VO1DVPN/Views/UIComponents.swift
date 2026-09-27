import SwiftUI

struct ScaleButtonStyle: ButtonStyle {
    @Environment(\.vo1dReduceMotion) private var reduceMotion
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: configuration.isPressed)
    }
}

struct IconButton: View {
    let icon: String
    let label: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16, weight: .medium))
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.06), in: Circle())
        }.buttonStyle(ScaleButtonStyle()).accessibilityLabel(label)
    }
}

struct PrimaryButton: View {
    let title: String
    var icon = "arrow.up.right"
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 15, weight: .semibold))
                Spacer()
                Image(systemName: icon)
            }
            .padding(18).foregroundStyle(.black)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(ScaleButtonStyle())
    }
}

struct EmptyState: View {
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "globe.europe.africa").font(.system(size: 32, weight: .ultraLight))
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(VO1DStyle.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 38).padding(.horizontal, 20).vo1dSurface()
    }
}
