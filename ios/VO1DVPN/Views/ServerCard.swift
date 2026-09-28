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
        ReferenceGlassCard(
            radius: 18,
            highlighted: selected
        ) {
            HStack(spacing: 12) {
                Button(action: select) {
                    HStack(spacing: 12) {
                        Text(server.flag)
                            .font(.system(size: compact ? 23 : 28))
                            .frame(
                                width: compact ? 38 : 44,
                                height: compact ? 38 : 44
                            )

                        VStack(alignment: .leading, spacing: 5) {
                            Text(server.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            if !compact {
                                Text("\(server.code) / \(server.protocolName)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .tracking(0.4)
                                    .foregroundStyle(.white.opacity(0.34))
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 8)

                        if showPing {
                            Text(ping.map { "\($0) ms" } ?? "— ms")
                                .font(.system(size: 10, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.52))
                        }

                        ZStack {
                            Circle()
                                .stroke(
                                    .white.opacity(selected ? 0.40 : 0.14),
                                    lineWidth: 1
                                )
                                .frame(width: 17, height: 17)

                            if selected {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 7, height: 7)
                                    .shadow(color: .white.opacity(0.48), radius: 5)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.985))
                .disabled(busy)
                .accessibilityLabel("\(server.name), \(server.code), \(server.protocolName)")
                .accessibilityValue(selected ? "Selected" : "Not selected")
                .accessibilityIdentifier("server.\(server.code)")

                Button(action: toggleFavorite) {
                    Image(systemName: favorite ? "star.fill" : "star")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(
                            favorite
                            ? .white.opacity(0.88)
                            : .white.opacity(0.24)
                        )
                        .frame(width: 34, height: 42)
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.92))
                .accessibilityLabel(
                    favorite
                    ? "Remove \(server.name) from favorites"
                    : "Favorite \(server.name)"
                )
                .accessibilityIdentifier("favorite.\(server.code)")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, compact ? 10 : 13)
        }
        .animation(
            reduceMotion
            ? nil
            : .snappy(duration: 0.24),
            value: selected
        )
        .animation(
            reduceMotion
            ? nil
            : .snappy(duration: 0.20),
            value: favorite
        )
    }
}
