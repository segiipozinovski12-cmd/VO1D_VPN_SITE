import SwiftUI

struct ReferenceStatsView: View {
    @EnvironmentObject private var model: AppViewModel
    @EnvironmentObject private var session: SessionMonitor
    @EnvironmentObject private var pings: PingStore

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("VO1D_VPN")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .tracking(1.0)

                        Text("LIVE SESSION")
                            .font(VO1DStyle.mono(8))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.44))
                    }

                    Spacer()

                    StatusPill(
                        text: model.isConnected ? "CONNECTED" : "READY",
                        connected: model.isConnected
                    )
                }

                ReferenceGlassPanel(radius: 22) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("TRAFFIC")
                            .font(VO1DStyle.mono(9))
                            .tracking(1.4)
                            .foregroundStyle(.white.opacity(0.46))

                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(session.hasTrafficMeasurements ? session.stats.trafficValue : "—")
                                .font(.system(size: 42, weight: .medium, design: .rounded))
                                .monospacedDigit()

                            Text(session.hasTrafficMeasurements ? session.stats.trafficUnit : "")
                                .font(VO1DStyle.mono(11))
                                .foregroundStyle(.white.opacity(0.42))
                        }

                        MiniTrafficChart(seed: 1, rising: true)
                            .frame(height: 70)
                    }
                    .padding(20)
                }

                HStack(spacing: 10) {
                    metric(
                        "DOWNLOAD",
                        value: session.hasTrafficMeasurements
                            ? String(format: "%.1f", session.stats.downloadMbps)
                            : "—",
                        unit: "Mbps",
                        rising: false
                    )

                    metric(
                        "UPLOAD",
                        value: session.hasTrafficMeasurements
                            ? String(format: "%.1f", session.stats.uploadMbps)
                            : "—",
                        unit: "Mbps",
                        rising: true
                    )
                }

                HStack(spacing: 10) {
                    compactMetric("SESSION", session.stats.durationText)

                    compactMetric(
                        "PING",
                        activePing.map { "\($0) ms" } ?? "—"
                    )

                    compactMetric(
                        "QUALITY",
                        VO1DStyle.quality(activePing)
                            .capitalized
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .background {
            ReferenceBackdrop()
        }
        .scrollIndicators(.hidden)
    }

    private var activePing: Int? {
        guard let code = model.activeServer?.code else { return nil }
        return pings.values[code]
    }

    private func metric(
        _ title: String,
        value: String,
        unit: String,
        rising: Bool
    ) -> some View {
        ReferenceGlassPanel(radius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(VO1DStyle.mono(8))
                    .foregroundStyle(.white.opacity(0.45))

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 25, weight: .medium, design: .rounded))
                        .monospacedDigit()

                    Text(unit)
                        .font(VO1DStyle.mono(9))
                        .foregroundStyle(.white.opacity(0.42))
                }

                MiniTrafficChart(seed: rising ? 2 : 3, rising: rising)
                    .frame(height: 44)
            }
            .padding(16)
        }
    }

    private func compactMetric(
        _ title: String,
        _ value: String
    ) -> some View {
        ReferenceGlassPanel(radius: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(VO1DStyle.mono(7))
                    .foregroundStyle(.white.opacity(0.42))

                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
    }
}
