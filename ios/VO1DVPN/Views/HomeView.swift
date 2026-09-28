import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppViewModel
    @EnvironmentObject private var preferences: Preferences
    @Environment(\.vo1dReduceMotion) private var reduceMotion

    let openLocations: () -> Void
    let openProfile: () -> Void

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                    .entrance(appeared, reduceMotion: reduceMotion, delay: 0.00)

                connectionSection
                    .entrance(appeared, reduceMotion: reduceMotion, delay: 0.04)

                QuickActions()
                    .entrance(appeared, reduceMotion: reduceMotion, delay: 0.10)

                SelectedRouteCard(action: openLocations)
                    .entrance(appeared, reduceMotion: reduceMotion, delay: 0.15)

                if !model.isDemoMode && model.account == nil {
                    PrimaryButton(
                        title: model.isRefreshingAccount ? "Syncing account…" : "Retry account sync",
                        icon: "arrow.clockwise"
                    ) {
                        Task { await model.refresh() }
                    }
                    .disabled(model.isRefreshingAccount)
                }

                if model.isConnected {
                    ConnectionDashboard()
                        .transition(
                            reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .move(edge: .bottom))
                        )
                } else {
                    readinessCard
                        .transition(.opacity)
                }

                HStack(spacing: 8) {
                    Image(systemName: "waveform.path")
                        .symbolRenderingMode(.hierarchical)

                    Text(model.isDemoMode ? "SIMULATED NETWORK / NO VPN TRAFFIC" : "VLESS / REALITY")
                }
                .font(VO1DStyle.mono(9))
                .tracking(0.5)
                .foregroundStyle(VO1DStyle.secondary)
                .entrance(appeared, reduceMotion: reduceMotion, delay: 0.20)
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background {
            ZStack {
                DeepSpaceBackdrop()
                RadialGradient(
                    colors: [atmosphereColor.opacity(atmosphereOpacity), .clear],
                    center: UnitPoint(x: 0.5, y: 0.27),
                    startRadius: 12,
                    endRadius: 290
                )
            }
            .ignoresSafeArea()
        }
        .scrollIndicators(.hidden)
        .animation(reduceMotion ? nil : .snappy(duration: 0.35), value: model.isConnected)
        .animation(reduceMotion ? nil : .snappy(duration: 0.30), value: model.phase)
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.45)) {
                    appeared = true
                }
            }
        }
        .accessibilityIdentifier("home.screen")
    }

    private var connectionSection: some View {
        VStack(spacing: 0) {
            HStack {
                Eyebrow(text: "01 / CONNECTION")
                Spacer()

                if model.isDemoMode {
                    Text("DEMO")
                        .font(VO1DStyle.mono(9))
                        .foregroundStyle(VO1DStyle.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .vo1dSystemGlass(in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    .white.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                }
            }

            ConnectionOrb(
                phase: model.phase,
                action: model.toggleConnection
            )
            .padding(.top, 2)

            Text(model.phase.rawValue)
                .font(.system(size: 23, weight: .medium, design: .monospaced))
                .tracking(1)
                .contentTransition(.opacity)
                .accessibilityIdentifier("connection.status")

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(VO1DStyle.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 9)

            if model.phase.isBusy {
                ConnectionStageRail(phase: model.phase)
                    .padding(.top, 18)
                    .transition(
                        reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .move(edge: .bottom))
                    )
            }
        }
    }

    private var readinessCard: some View {
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                Color.clear
                    .frame(width: 38, height: 38)
                    .vo1dSystemGlass(in: Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    )

                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(VO1DStyle.ice)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Your route. Your choice.")
                    .font(.subheadline.weight(.medium))

                Text(
                    model.isDemoMode
                    ? "Explore every control. Connections and traffic are simulated on this device."
                    : "Choose a location, or let Fastest select the lowest measured latency."
                )
                .font(.caption)
                .foregroundStyle(VO1DStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .vo1dSurface()
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 7) {
                Text("VO1D_VPN")
                    .font(.system(size: 21, weight: .bold, design: .monospaced))
                    .tracking(0.7)

                StatusPill(
                    text: model.isConnected ? "CONNECTED" : model.phase.isBusy ? "CONNECTING" : "READY",
                    connected: model.isConnected
                )
            }

            Spacer()

            IconButton(
                icon: preferences.avatar,
                label: "Open profile",
                action: openProfile
            )
        }
    }

    private var atmosphereColor: Color {
        switch model.phase {
        case .connected:
            return VO1DStyle.frost
        case .preparing, .routing, .securing, .switching:
            return VO1DStyle.ice
        case .failed:
            return VO1DStyle.red
        case .disconnecting:
            return .white
        case .ready:
            return .white
        }
    }

    private var atmosphereOpacity: Double {
        switch model.phase {
        case .connected: return 0.050
        case .preparing, .routing, .securing, .switching: return 0.045
        case .failed: return 0.060
        case .disconnecting: return 0.035
        case .ready: return 0.022
        }
    }

    private var subtitle: String {
        switch model.phase {
        case .connected:
            return model.isDemoMode ? "Demo route established" : "Tunnel established"
        case .preparing:
            return "Preparing your connection"
        case .routing:
            return "Finding the cleanest route"
        case .securing:
            return "Establishing the secure tunnel"
        case .switching:
            return "Moving to \(model.selectedServer?.name ?? "your location")"
        case .disconnecting:
            return "Closing the current session"
        case .failed:
            return "Choose a location and try again"
        case .ready:
            return "One tap to your next connection"
        }
    }
}

private struct ConnectionStageRail: View {
    let phase: ConnectionPhase
    @Namespace private var activeStage

    private let stages = ["PREPARE", "ROUTE", "SECURE"]

    private var activeIndex: Int {
        switch phase {
        case .preparing: return 0
        case .routing, .switching: return 1
        case .securing, .disconnecting: return 2
        default: return 2
        }
    }

    var body: some View {
        HStack(spacing: 7) {
            ForEach(Array(stages.enumerated()), id: \.offset) { index, title in
                HStack(spacing: 6) {
                    Circle()
                        .fill(index <= activeIndex ? VO1DStyle.ice : .white.opacity(0.12))
                        .frame(width: 5, height: 5)
                        .shadow(
                            color: index == activeIndex ? VO1DStyle.ice.opacity(0.45) : .clear,
                            radius: 5
                        )

                    Text(title)
                        .font(VO1DStyle.mono(8))
                        .tracking(0.5)
                        .foregroundStyle(index <= activeIndex ? .white.opacity(0.82) : VO1DStyle.secondary.opacity(0.55))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .vo1dSystemGlass(in: Capsule())
                .background {
                    if index == activeIndex {
                        Capsule()
                            .fill(.white.opacity(0.055))
                            .matchedGeometryEffect(id: "active-stage", in: activeStage)
                    }
                }
                .overlay(
                    Capsule()
                        .strokeBorder(
                            .white.opacity(index == activeIndex ? 0.16 : 0.055),
                            lineWidth: 1
                        )
                )
            }
        }
        .accessibilityHidden(true)
    }
}

private struct QuickActions: View {
    @EnvironmentObject private var model: AppViewModel
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var pings: PingStore

    var body: some View {
        HStack(spacing: 8) {
            action(
                "FASTEST",
                icon: "bolt",
                detail: model.fastestServer?.code ?? "FIND",
                active: preferences.autoFastest
            ) {
                preferences.autoFastest = true
                Task { await model.connectFastest() }
            }
            .disabled(model.phase.isBusy)
            .accessibilityIdentifier("quick.fastest")

            action(
                "REFRESH PING",
                icon: "arrow.clockwise",
                detail: pings.isRefreshing ? "CHECKING" : "MEASURE",
                active: pings.isRefreshing
            ) {
                Haptics.play(
                    .selection,
                    enabled: preferences.haptics
                )
                Task { await pings.refresh() }
            }
            .disabled(pings.isRefreshing)
            .accessibilityIdentifier("quick.ping")

            action(
                "AUTO CONNECT",
                icon: "power.circle",
                detail: preferences.autoConnect ? "ON" : "OFF",
                active: preferences.autoConnect
            ) {
                preferences.autoConnect.toggle()
                Haptics.play(.selection, enabled: preferences.haptics)
            }
            .accessibilityIdentifier("quick.auto")
        }
    }

    private func action(
        _ title: String,
        icon: String,
        detail: String,
        active: Bool,
        perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            VStack(spacing: 9) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .light))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: active)
                        .rotationEffect(
                            .degrees(
                                title == "REFRESH PING" && pings.isRefreshing
                                ? 360
                                : 0
                            )
                        )
                        .animation(
                            title == "REFRESH PING" && pings.isRefreshing
                            ? .linear(duration: 0.85).repeatForever(autoreverses: false)
                            : .easeOut(duration: 0.16),
                            value: pings.isRefreshing
                        )

                    Spacer(minLength: 0)

                    Circle()
                        .fill(active ? VO1DStyle.ice : .white.opacity(0.13))
                        .frame(width: 5, height: 5)
                        .shadow(color: active ? VO1DStyle.ice.opacity(0.45) : .clear, radius: 5)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(VO1DStyle.mono(8))
                        .tracking(0.15)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(detail)
                        .font(VO1DStyle.mono(9))
                        .foregroundStyle(active ? .white.opacity(0.82) : VO1DStyle.secondary)
                        .contentTransition(.opacity)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .vo1dSurface(highlighted: active, radius: 16)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue(detail)
    }
}

private struct SelectedRouteCard: View {
    @EnvironmentObject private var model: AppViewModel
    @EnvironmentObject private var pings: PingStore
    @EnvironmentObject private var preferences: Preferences

    let action: () -> Void

    var body: some View {
        let route = model.isConnected
            ? model.activeServer
            : preferences.autoFastest
                ? (model.fastestServer ?? model.selectedServer)
                : model.selectedServer

        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Eyebrow(text: model.isConnected ? "CURRENT ROUTE" : "SELECTED LOCATION")
                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(VO1DStyle.secondary)
                }

                HStack(spacing: 12) {
                    Text(route?.flag ?? "◎")
                        .font(.system(size: 30))
                        .frame(width: 48, height: 48)
                        .vo1dSystemGlass(in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(.white.opacity(0.09), lineWidth: 1)
                        }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(route?.name ?? "Choose location")
                            .font(.system(size: 18, weight: .medium))

                        Text(
                            preferences.autoFastest
                            ? "FASTEST · AUTOMATIC"
                            : (route?.protocolName.uppercased() ?? "AVAILABLE LOCATIONS")
                        )
                        .font(VO1DStyle.mono(9))
                        .foregroundStyle(VO1DStyle.secondary)
                    }

                    Spacer(minLength: 4)

                    if preferences.livePing {
                        PingBadge(
                            ping: route.flatMap { pings.values[$0.code] }
                        )
                    }
                }
            }
            .padding(18)
            .vo1dSurface(highlighted: model.isConnected)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("home.route")
    }
}

private extension View {
    func entrance(
        _ visible: Bool,
        reduceMotion: Bool,
        delay: Double
    ) -> some View {
        self
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 9)
            .animation(
                reduceMotion
                ? nil
                : .easeOut(duration: 0.42).delay(delay),
                value: visible
            )
    }
}
