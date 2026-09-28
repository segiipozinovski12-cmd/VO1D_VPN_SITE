import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var model: AppViewModel
    @EnvironmentObject private var session: SessionMonitor
    @EnvironmentObject private var pings: PingStore
    @Environment(\.vo1dReduceMotion) private var reduceMotion

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                    .referenceStatsReveal(appeared, delay: 0.00, reduceMotion: reduceMotion)

                sessionHero
                    .referenceStatsReveal(appeared, delay: 0.05, reduceMotion: reduceMotion)

                ReferenceTrafficGrid()
                    .referenceStatsReveal(appeared, delay: 0.10, reduceMotion: reduceMotion)

                transferBreakdown
                    .referenceStatsReveal(appeared, delay: 0.15, reduceMotion: reduceMotion)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .background { ReferenceBackdrop() }
        .onAppear {
            guard !appeared else { return }

            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.42)) {
                    appeared = true
                }
            }
        }
        .accessibilityIdentifier("stats.screen")
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("NETWORK STATS")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(.white.opacity(0.42))

                Text("Live Session")
                    .font(.system(size: 28, weight: .semibold))
                    .tracking(-0.6)
            }

            Spacer()

            VO1DBrandLockup(compact: true)
                .scaleEffect(0.80, anchor: .trailing)
        }
    }

    private var sessionHero: some View {
        let server = model.activeServer ?? model.selectedServer
        let ping = server.flatMap { pings.values[$0.code] }

        return ReferenceGlassCard(radius: 24, highlighted: model.isConnected) {
            VStack(spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.isConnected ? "CONNECTED" : "NOT CONNECTED")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .tracking(1.8)
                            .foregroundStyle(.white.opacity(0.78))

                        Text(session.stats.durationText)
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                            .frame(width: 58, height: 58)

                        ReferenceVortex(
                            active: model.isConnected,
                            busy: model.phase.isBusy
                        )
                        .frame(width: 52, height: 52)
                    }
                }

                Divider()
                    .overlay(.white.opacity(0.08))

                HStack {
                    statLabel("LOCATION", server?.name ?? "—")
                    Spacer()
                    statLabel("PING", ping.map { "\($0) ms" } ?? "—")
                    Spacer()
                    statLabel("PROTOCOL", server?.protocolName ?? "VLESS")
                }
            }
            .padding(20)
        }
    }

    private var transferBreakdown: some View {
        let data = session.stats
        let available = session.hasTrafficMeasurements

        return ReferenceGlassCard(radius: 22) {
            VStack(spacing: 18) {
                HStack {
                    Text("TRANSFER BREAKDOWN")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(.white.opacity(0.46))

                    Spacer()

                    Text(available ? "LIVE" : "WAITING")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.56))
                }

                transferRow(
                    title: "Downloaded",
                    value:
                        available
                        ? formattedMegabytes(data.downloadedMB)
                        : "—"
                )

                transferRow(
                    title: "Uploaded",
                    value:
                        available
                        ? formattedMegabytes(data.uploadedMB)
                        : "—"
                )

                transferRow(
                    title: "Total",
                    value:
                        available
                        ? "\(data.trafficValue) \(data.trafficUnit)"
                        : "—"
                )
            }
            .padding(18)
        }
    }

    private func transferRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.50))

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.88))
        }
    }

    private func statLabel(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.36))

            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func formattedMegabytes(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.2f GB", mb / 1024)
        }

        return String(format: "%.0f MB", mb)
    }
}

private extension View {
    func referenceStatsReveal(
        _ visible: Bool,
        delay: Double,
        reduceMotion: Bool
    ) -> some View {
        opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 12)
            .animation(
                reduceMotion
                ? nil
                : .easeOut(duration: 0.42).delay(delay),
                value: visible
            )
    }
}
