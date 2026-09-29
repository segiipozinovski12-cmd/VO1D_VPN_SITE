import SwiftUI

struct StatCard: View {
    @Environment(\.vo1dReduceMotion) private var reduceMotion

    let title: String
    let value: String
    var unit = ""
    var icon = "waveform.path"
    var tint: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))

                Spacer()

                Text(title)
                    .font(VO1DStyle.mono(9))
                    .tracking(0.7)
            }
            .foregroundStyle(VO1DStyle.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 0.3),
                        value: value
                    )
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                if !unit.isEmpty {
                    Text(unit)
                        .font(VO1DStyle.mono(10))
                        .foregroundStyle(VO1DStyle.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .vo1dSurface(radius: 18)
        .accessibilityElement(children: .combine)
    }
}

struct ConnectionDashboard: View {
    @EnvironmentObject private var model: AppViewModel
    @EnvironmentObject private var preferences: Preferences

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Eyebrow(text: "LIVE SESSION")

                Spacer()

                Text(model.isDemoMode ? "SIMULATED" : "CONNECTED")
                    .font(VO1DStyle.mono(9))
                    .foregroundStyle(VO1DStyle.secondary)
            }

            TrafficStatsGrid()

            RouteQualityGrid(
                code: model.activeServer?.code
            )

            sessionControls

            if !model.isDemoMode {
                Text("Traffic is measured directly by the running Packet Tunnel.")
                    .font(.caption)
                    .foregroundStyle(VO1DStyle.secondary)
            }
        }
        .accessibilityIdentifier("connection.dashboard")
    }

    private var sessionControls: some View {
        let options = model.appliedOptions ?? preferences.connectionOptions

        return HStack(spacing: 12) {
            Button {
                model.reconnect()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .medium))

                    Text("RECONNECT")
                        .font(VO1DStyle.mono(9))
                        .tracking(0.6)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .vo1dSurface(highlighted: true, radius: 15)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(model.phase.isBusy)
            .accessibilityIdentifier("connection.reconnect")

            VStack(alignment: .leading, spacing: 5) {
                Text("ACTIVE PROFILE")
                    .font(VO1DStyle.mono(8))
                    .foregroundStyle(VO1DStyle.secondary)

                HStack(spacing: 7) {
                    optionDot(enabled: options.killSwitch)
                    Text("KILL")
                    optionDot(enabled: options.secureDNS)
                    Text("DNS")
                    optionDot(enabled: options.ipv6Protection)
                    Text("IPv6")
                }
                .font(VO1DStyle.mono(8))
                .foregroundStyle(.white.opacity(0.74))
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .vo1dSurface(radius: 15)
        }
    }

    private func optionDot(enabled: Bool) -> some View {
        Circle()
            .fill(enabled ? .white.opacity(0.78) : .white.opacity(0.18))
            .frame(width: 4, height: 4)
    }
}

private struct TrafficStatsGrid: View {
    @EnvironmentObject private var session: SessionMonitor

    var body: some View {
        let data = session.stats
        let available = session.hasTrafficMeasurements

        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                StatCard(
                    title: "DOWNLOAD",
                    value: available ? String(format: "%.1f", data.downloadMbps) : "—",
                    unit: "Mbps",
                    icon: "arrow.down"
                )

                StatCard(
                    title: "UPLOAD",
                    value: available ? String(format: "%.1f", data.uploadMbps) : "—",
                    unit: "Mbps",
                    icon: "arrow.up"
                )
            }

            GridRow {
                StatCard(
                    title: "SESSION",
                    value: data.durationText,
                    icon: "clock"
                )

                StatCard(
                    title: "TRAFFIC",
                    value: available ? data.trafficValue : "—",
                    unit: available ? data.trafficUnit : "",
                    icon: "arrow.up.arrow.down"
                )
            }
        }
    }
}

private struct RouteQualityGrid: View {
    @EnvironmentObject private var pings: PingStore
    @EnvironmentObject private var preferences: Preferences

    let code: String?

    var body: some View {
        let ping = code.flatMap { pings.values[$0] }

        HStack(spacing: 10) {
            StatCard(
                title: preferences.livePing ? "PING" : "LAST PING",
                value: ping.map(String.init) ?? "—",
                unit: "ms",
                icon: "waveform.path.ecg",
                tint: .white.opacity(0.90)
            )

            StatCard(
                title: "QUALITY",
                value: VO1DStyle.quality(ping),
                icon: "chart.bar.fill",
                tint: .white.opacity(0.90)
            )
        }
    }
}

struct PingBadge: View {
    @Environment(\.vo1dReduceMotion) private var reduceMotion
    let ping: Int?

    var body: some View {
        HStack(spacing: 5) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<3) { bar in
                    Capsule()
                        .fill(
                            VO1DStyle.latencyColor(ping)
                                .opacity(ping == nil ? 0.18 : 0.72)
                        )
                        .frame(
                            width: 2,
                            height: CGFloat(4 + bar * 3)
                        )
                }
            }
            .accessibilityHidden(true)

            Text(ping.map { "\($0) ms" } ?? "— ms")
                .font(VO1DStyle.mono(11))
                .monospacedDigit()
                .foregroundStyle(
                    .white.opacity(ping == nil ? 0.42 : 0.76)
                )
                .contentTransition(.numericText())
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.25),
                    value: ping
                )
        }
        .fixedSize()
    }
}
