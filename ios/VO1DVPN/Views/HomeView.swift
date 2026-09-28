import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppViewModel
    @EnvironmentObject private var session: SessionMonitor
    @EnvironmentObject private var pings: PingStore
    @EnvironmentObject private var preferences: Preferences
    @Environment(\.vo1dReduceMotion) private var reduceMotion

    let openLocations: () -> Void
    let openProfile: () -> Void

    @State private var reveal = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                    .referenceEntrance(
                        reveal,
                        reduceMotion: reduceMotion,
                        delay: 0.00
                    )

                serverCard
                    .referenceEntrance(
                        reveal,
                        reduceMotion: reduceMotion,
                        delay: 0.04
                    )

                connectionHero
                    .referenceEntrance(
                        reveal,
                        reduceMotion: reduceMotion,
                        delay: 0.08
                    )

                speedRow
                    .referenceEntrance(
                        reveal,
                        reduceMotion: reduceMotion,
                        delay: 0.12
                    )

                compactStats
                    .referenceEntrance(
                        reveal,
                        reduceMotion: reduceMotion,
                        delay: 0.16
                    )
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
        .background {
            ZStack {
                ReferenceBackdrop()

                RadialGradient(
                    colors: [
                        .white.opacity(
                            model.isConnected ? 0.055 : 0.018
                        ),
                        .clear
                    ],
                    center: UnitPoint(x: 0.50, y: 0.42),
                    startRadius: 10,
                    endRadius: 310
                )
            }
        }
        .scrollIndicators(.hidden)
        .onAppear {
            if reduceMotion {
                reveal = true
            } else {
                withAnimation(.easeOut(duration: 0.44)) {
                    reveal = true
                }
            }
        }
        .accessibilityIdentifier("home.screen")
    }

    private var header: some View {
        ZStack {
            HStack {
                chromeButton(
                    "line.3.horizontal",
                    label: "Open locations",
                    action: openLocations
                )

                Spacer()

                chromeButton(
                    "gearshape",
                    label: "Open settings",
                    action: openProfile
                )
            }

            VStack(spacing: 3) {
                Text("VO1D_VPN")
                    .font(
                        .system(
                            size: 20,
                            weight: .black,
                            design: .monospaced
                        )
                    )
                    .tracking(1.0)

                Text("ZERO LOGS")
                    .font(VO1DStyle.mono(6))
                    .tracking(3.0)
                    .foregroundStyle(.white.opacity(0.42))
            }
        }
        .frame(height: 48)
    }

    private func chromeButton(
        _ icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))
                .frame(width: 38, height: 38)
                .background(
                    .black.opacity(0.42),
                    in: RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                    .strokeBorder(
                        .white.opacity(0.09),
                        lineWidth: 1
                    )
                }
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.93))
        .accessibilityLabel(label)
    }

    private var serverCard: some View {
        Button(action: openLocations) {
            ReferenceGlassPanel(radius: 22) {
                HStack(spacing: 13) {
                    Text(currentServer?.flag ?? "◌")
                        .font(.system(size: 30))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(currentServer?.name ?? "Fastest location")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)

                        Text(currentServer?.label ?? "Select your route")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.42))
                            .lineLimit(1)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Text(activePing.map { "\($0) ms" } ?? "— ms")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.54))
                            .monospacedDigit()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 70)
            }
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.985))
        .accessibilityIdentifier("home.server")
    }

    private var connectionHero: some View {
        ZStack {
            ReferenceVortexView(
                connected: model.isConnected,
                busy: model.phase.isBusy
            )
            .frame(width: 330, height: 330)

            VStack(spacing: 10) {
                Button {
                    Haptics.play(
                        .connect,
                        enabled: preferences.haptics
                    )
                    model.toggleConnection()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.black.opacity(0.38))
                            .frame(width: 74, height: 74)
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                .white.opacity(0.36),
                                                .white.opacity(0.06)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                            .shadow(
                                color: .white.opacity(
                                    model.isConnected ? 0.08 : 0.02
                                ),
                                radius: 12
                            )

                        Image(
                            systemName:
                                model.isConnected
                                ? "stop.fill"
                                : "power"
                        )
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                    }
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.93))
                .disabled(model.phase.isBusy)
                .accessibilityIdentifier("connection.control")
                .accessibilityValue(connectionTitle)

                Text(connectionTitle)
                    .accessibilityIdentifier("connection.status")
                    .font(
                        .system(
                            size: 14,
                            weight: .semibold,
                            design: .monospaced
                        )
                    )
                    .tracking(2.4)
                    .contentTransition(.opacity)

                Text(
                    model.isConnected
                    ? session.stats.durationText
                    : connectionSubtitle
                )
                .font(
                    .system(
                        size: model.isConnected ? 12 : 10,
                        design: .monospaced
                    )
                )
                .foregroundStyle(.white.opacity(0.52))
                .monospacedDigit()
                .contentTransition(.numericText())
            }
        }
        .frame(height: 324)
    }

    private var speedRow: some View {
        HStack(spacing: 10) {
            speedCard(
                title: "Download",
                value:
                    session.hasTrafficMeasurements
                    ? String(
                        format: "%.1f",
                        session.stats.downloadMbps
                    )
                    : "—",
                unit: "Mbps",
                rising: false
            )

            speedCard(
                title: "Upload",
                value:
                    session.hasTrafficMeasurements
                    ? String(
                        format: "%.1f",
                        session.stats.uploadMbps
                    )
                    : "—",
                unit: "Mbps",
                rising: true
            )
        }
    }

    private func speedCard(
        title: String,
        value: String,
        unit: String,
        rising: Bool
    ) -> some View {
        ReferenceGlassPanel(radius: 19) {
            VStack(alignment: .leading, spacing: 9) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.62))

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(
                            .system(
                                size: 23,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.44))
                }

                MiniTrafficChart(
                    seed: rising ? 8 : 4,
                    rising: rising
                )
                .frame(height: 40)
            }
            .padding(14)
        }
    }

    private var compactStats: some View {
        HStack(spacing: 9) {
            compactCard(
                "Traffic",
                session.hasTrafficMeasurements
                    ? "\(session.stats.trafficValue) \(session.stats.trafficUnit)"
                    : "—"
            )

            compactCard(
                "Ping",
                activePing.map { "\($0) ms" } ?? "—"
            )

            compactCard(
                "Quality",
                qualityLabel
            )
        }
    }

    private func compactCard(
        _ title: String,
        _ value: String
    ) -> some View {
        ReferenceGlassPanel(radius: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.54))

                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
        }
    }

    private var currentServer: VO1DServer? {
        model.activeServer ?? model.selectedServer
    }

    private var activePing: Int? {
        guard let code = currentServer?.code else {
            return nil
        }
        return pings.values[code]
    }

    private var qualityLabel: String {
        let raw = VO1DStyle.quality(activePing)
        return raw
            .lowercased()
            .capitalized
    }

    private var connectionTitle: String {
        switch model.phase {
        case .connected:
            return "CONNECTED"
        case .ready:
            return "CONNECT"
        case .preparing:
            return "PREPARING"
        case .routing:
            return "ROUTING"
        case .securing:
            return "SECURING"
        case .disconnecting:
            return "DISCONNECTING"
        case .switching:
            return "SWITCHING"
        case .failed:
            return "TRY AGAIN"
        }
    }

    private var connectionSubtitle: String {
        switch model.phase {
        case .ready:
            return "Tap to connect"
        case .preparing:
            return "Initializing core..."
        case .routing:
            return "Routing network..."
        case .securing:
            return "Establishing tunnel..."
        case .disconnecting:
            return "Closing session..."
        case .switching:
            return "Switching route..."
        case .failed:
            return "Connection failed"
        case .connected:
            return ""
        }
    }
}

private extension View {
    func referenceEntrance(
        _ visible: Bool,
        reduceMotion: Bool,
        delay: Double
    ) -> some View {
        opacity(visible ? 1 : 0)
            .offset(
                y:
                    visible || reduceMotion
                    ? 0
                    : 9
            )
            .animation(
                reduceMotion
                ? nil
                : .easeOut(duration: 0.42)
                    .delay(delay),
                value: visible
            )
    }
}
