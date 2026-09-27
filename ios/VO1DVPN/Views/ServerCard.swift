import SwiftUI

struct ServerCard: View {
    @Environment(\.vo1dReduceMotion) private var reduceMotion
    let server: VO1DServer
    let ping: Int?
    let selected: Bool
    let favorite: Bool
    let compact: Bool
    let showPing: Bool
    let busy: Bool
    let select: () -> Void
    let toggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: select) {
                HStack(spacing: 12) {
                    Text(server.flag).font(.system(size: compact ? 24 : 29))
                        .frame(width: compact ? 34 : 44, height: 44)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(server.name).font(.system(size: 15, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
                        if !compact {
                            Text("\(server.code) / \(server.protocolName)")
                                .font(VO1DStyle.mono(9)).foregroundStyle(VO1DStyle.secondary).lineLimit(1).minimumScaleFactor(0.7)
                        }
                    }
                    Spacer(minLength: 6)
                    VStack(alignment: .trailing, spacing: 8) {
                        if showPing { PingBadge(ping: ping) }
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 13)).foregroundStyle(.white.opacity(selected ? 0.95 : 0.25))
                    }
                }
                .padding(.leading, 12).padding(.vertical, compact ? 8 : 15)
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle()).disabled(busy)
            .accessibilityLabel("\(server.name), \(server.code), \(server.protocolName)")
            .accessibilityValue(selected ? "Selected" : "Not selected")
            .accessibilityIdentifier("server.\(server.code)")
            Button(action: toggleFavorite) {
                Image(systemName: favorite ? "star.fill" : "star")
                    .font(.system(size: 15)).foregroundStyle(.white.opacity(favorite ? 0.95 : 0.35))
                    .contentTransition(.opacity)
                    .frame(width: 44, height: 52)
            }.buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(favorite ? "Remove \(server.name) from favorites" : "Favorite \(server.name)")
                .accessibilityIdentifier("favorite.\(server.code)")
        }
        .vo1dSurface(highlighted: selected, radius: 18)
        .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: selected)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: favorite)
    }
}
