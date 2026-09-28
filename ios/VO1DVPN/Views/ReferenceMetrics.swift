import SwiftUI

struct ReferenceMetricCard: View {
    let title: String
    let value: String
    var unit: String = ""
    var large = false
    var sparkline = false

    var body: some View {
        ReferenceGlassCard(
            radius: 16,
            highlighted: false
        ) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: large ? 10 : 6) {
                    Text(title.uppercased())
                        .font(
                            .system(
                                size: 9,
                                weight: .medium,
                                design: .monospaced
                            )
                        )
                        .tracking(1.0)
                        .foregroundStyle(.white.opacity(0.46))

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(value)
                            .font(
                                .system(
                                    size: large ? 22 : 17,
                                    weight: .semibold,
                                    design: .rounded
                                )
                            )
                            .tracking(large ? -0.4 : -0.2)
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.96))
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)

                        if !unit.isEmpty {
                            Text(unit)
                                .font(
                                    .system(
                                        size: large ? 11 : 10,
                                        weight: .medium
                                    )
                                )
                                .foregroundStyle(.white.opacity(0.38))
                        }
                    }

                    if sparkline {
                        ZStack(alignment: .bottom) {
                            LinearGradient(
                                colors: [
                                    .clear,
                                    VO1DStyle.frost.opacity(0.055)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 8,
                                    style: .continuous
                                )
                            )

                            MiniSparkline(intensity: 1.0)
                                .padding(.vertical, 3)
                        }
                        .frame(height: 40)
                        .padding(.top, 1)
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: large ? 116 : 78,
                    alignment: .topLeading
                )
                .padding(14)

                if large {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(VO1DStyle.pearl)
                            .frame(width: 3.5, height: 3.5)
                            .shadow(
                                color: VO1DStyle.frost.opacity(0.72),
                                radius: 5
                            )

                        Text("LIVE")
                            .font(
                                .system(
                                    size: 7,
                                    weight: .semibold,
                                    design: .monospaced
                                )
                            )
                            .tracking(0.9)
                            .foregroundStyle(.white.opacity(0.34))
                    }
                    .padding(.top, 12)
                    .padding(.trailing, 12)
                }
            }
        }
    }
}

struct ReferenceTrafficGrid: View {
    @EnvironmentObject private var model: AppViewModel
    @EnvironmentObject private var session: SessionMonitor
    @EnvironmentObject private var pings: PingStore

    var body: some View {
        let data = session.stats
        let available = session.hasTrafficMeasurements
        let code =
            model.activeServer?.code ??
            model.selectedServer?.code
        let ping = code.flatMap { pings.values[$0] }

        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ReferenceMetricCard(
                    title: "Download",
                    value:
                        available
                        ? String(
                            format: "%.1f",
                            data.downloadMbps
                        )
                        : "—",
                    unit: "Mbps",
                    large: true,
                    sparkline: true
                )

                ReferenceMetricCard(
                    title: "Upload",
                    value:
                        available
                        ? String(
                            format: "%.1f",
                            data.uploadMbps
                        )
                        : "—",
                    unit: "Mbps",
                    large: true,
                    sparkline: true
                )
            }

            HStack(spacing: 10) {
                ReferenceMetricCard(
                    title: "Traffic",
                    value:
                        available
                        ? data.trafficValue
                        : "—",
                    unit:
                        available
                        ? data.trafficUnit
                        : ""
                )

                ReferenceMetricCard(
                    title: "Ping",
                    value: ping.map(String.init) ?? "—",
                    unit: "ms"
                )

                ReferenceMetricCard(
                    title: "Quality",
                    value: compactQuality(ping)
                )
            }
        }
    }

    private func compactQuality(_ ping: Int?) -> String {
        guard let ping else { return "—" }

        switch ping {
        case ..<50:
            return "Excellent"
        case ..<80:
            return "Good"
        case ..<120:
            return "Fair"
        default:
            return "High"
        }
    }
}
