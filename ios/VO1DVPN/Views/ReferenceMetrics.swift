import SwiftUI

struct ReferenceMetricCard: View {
    let title: String
    let value: String
    var unit: String = ""
    var large = false
    var sparkline = false

    var body: some View {
        ReferenceGlassCard(radius: 16) {
            VStack(alignment: .leading, spacing: large ? 10 : 6) {
                Text(title)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.66))

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(
                            .system(
                                size: large ? 22 : 17,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)

                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: large ? 12 : 10))
                            .foregroundStyle(.white.opacity(0.46))
                    }
                }

                if sparkline {
                    MiniSparkline()
                        .frame(height: 36)
                        .padding(.top, 3)
                }
            }
            .frame(
                maxWidth: .infinity,
                minHeight: large ? 116 : 78,
                alignment: .topLeading
            )
            .padding(14)
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
        let code = model.activeServer?.code ?? model.selectedServer?.code
        let ping = code.flatMap { pings.values[$0] }

        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ReferenceMetricCard(
                    title: "Download",
                    value:
                        available
                        ? String(format: "%.1f", data.downloadMbps)
                        : "—",
                    unit: "Mbps",
                    large: true,
                    sparkline: true
                )

                ReferenceMetricCard(
                    title: "Upload",
                    value:
                        available
                        ? String(format: "%.1f", data.uploadMbps)
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
