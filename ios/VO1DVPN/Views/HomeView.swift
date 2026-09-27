import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppViewModel
    @EnvironmentObject private var preferences: Preferences
    @Environment(\.vo1dReduceMotion) private var reduceMotion
    let openLocations: () -> Void
    let openProfile: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                VStack(spacing: 0) {
                    HStack {
                        Eyebrow(text: "01 / CONNECTION")
                        Spacer()
                        if model.isDemoMode { Text("DEMO").font(VO1DStyle.mono(9)).foregroundStyle(VO1DStyle.secondary) }
                    }
                    ConnectionOrb(phase: model.phase, action: model.toggleConnection)
                        .padding(.top, 2)
                    Text(model.phase.rawValue)
                        .font(.system(size: 23, weight: .medium, design: .monospaced)).tracking(1)
                        .contentTransition(.opacity).accessibilityIdentifier("connection.status")
                    Text(subtitle).font(.subheadline).foregroundStyle(VO1DStyle.secondary)
                        .multilineTextAlignment(.center).padding(.top, 9)
                }
                QuickActions()
                SelectedRouteCard(action: openLocations)
                if !model.isDemoMode && model.account == nil {
                    PrimaryButton(title: model.isRefreshingAccount ? "Syncing account…" : "Retry account sync", icon: "arrow.clockwise") {
                        Task { await model.refresh() }
                    }.disabled(model.isRefreshingAccount)
                }
                if model.isConnected {
                    ConnectionDashboard()
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "point.3.connected.trianglepath.dotted").font(.system(size: 19)).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Your route. Your choice.").font(.subheadline.weight(.medium))
                            Text(model.isDemoMode ? "Explore every control. Connections and traffic are simulated on this device." : "Choose a location, or let Fastest select the lowest measured latency.")
                                .font(.caption).foregroundStyle(VO1DStyle.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }.padding(18).vo1dSurface()
                }
                HStack {
                    Image(systemName: "waveform.path")
                    Text(model.isDemoMode ? "SIMULATED NETWORK / NO VPN TRAFFIC" : "VLESS / REALITY")
                }.font(VO1DStyle.mono(9)).tracking(0.5).foregroundStyle(VO1DStyle.secondary)
            }
            .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 24)
        }
        .background(VO1DStyle.background).scrollIndicators(.hidden)
        .animation(reduceMotion ? nil : .snappy(duration: 0.35), value: model.isConnected)
        .accessibilityIdentifier("home.screen")
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 7) {
                Text("VO1D_VPN").font(.system(size: 21, weight: .bold, design: .monospaced)).tracking(0.7)
                StatusPill(text: model.isConnected ? "CONNECTED" : model.phase.isBusy ? "CONNECTING" : "READY", connected: model.isConnected)
            }
            Spacer()
            IconButton(icon: preferences.avatar, label: "Open profile", action: openProfile)
        }
    }
    private var subtitle: String {
        switch model.phase {
        case .connected: return model.isDemoMode ? "Demo route established" : "Tunnel established"
        case .preparing: return "Preparing your connection"
        case .routing: return "Finding a path to your location"
        case .securing: return "Establishing the tunnel"
        case .switching: return "Moving to \(model.selectedServer?.name ?? "your location")"
        case .disconnecting: return "Closing the current session"
        case .failed: return "Choose a location and try again"
        case .ready: return "One tap to your next connection"
        }
    }
}

private struct QuickActions: View {
    @EnvironmentObject private var model: AppViewModel
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var pings: PingStore
    var body: some View {
        HStack(spacing: 8) {
            action("FASTEST", icon: "bolt", detail: model.fastestServer?.code ?? "FIND", active: preferences.autoFastest) {
                preferences.autoFastest = true
                Task { await model.connectFastest() }
            }.disabled(model.phase.isBusy).accessibilityIdentifier("quick.fastest")
            action("REFRESH PING", icon: "arrow.clockwise", detail: pings.isRefreshing ? "CHECKING" : "MEASURE", active: pings.isRefreshing) {
                Task { await pings.refresh() }
            }.disabled(pings.isRefreshing).accessibilityIdentifier("quick.ping")
            action("AUTO CONNECT", icon: "power.circle", detail: preferences.autoConnect ? "ON" : "OFF", active: preferences.autoConnect) {
                preferences.autoConnect.toggle()
                Haptics.play(.selection, enabled: preferences.haptics)
            }.accessibilityIdentifier("quick.auto")
        }
    }
    private func action(_ title: String, icon: String, detail: String, active: Bool, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 9) {
                HStack {
                    Image(systemName: icon).font(.system(size: 17, weight: .light))
                    Spacer(minLength: 0)
                    Circle().fill(.white.opacity(active ? 0.9 : 0.13)).frame(width: 4, height: 4)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(VO1DStyle.mono(8)).tracking(0.15).lineLimit(1).minimumScaleFactor(0.8)
                    Text(detail).font(VO1DStyle.mono(9)).foregroundStyle(VO1DStyle.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(12).frame(maxWidth: .infinity).vo1dSurface(highlighted: active, radius: 16)
        }.buttonStyle(ScaleButtonStyle()).accessibilityLabel(title).accessibilityValue(detail)
    }
}

private struct SelectedRouteCard: View {
    @EnvironmentObject private var model: AppViewModel
    @EnvironmentObject private var pings: PingStore
    @EnvironmentObject private var preferences: Preferences
    let action: () -> Void
    var body: some View {
        let route = model.isConnected ? model.activeServer : preferences.autoFastest ? (model.fastestServer ?? model.selectedServer) : model.selectedServer
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Eyebrow(text: model.isConnected ? "CURRENT ROUTE" : "SELECTED LOCATION")
                    Spacer()
                    Image(systemName: "arrow.up.right").foregroundStyle(VO1DStyle.secondary)
                }
                HStack(spacing: 12) {
                    Text(route?.flag ?? "◎").font(.system(size: 30)).frame(width: 46, height: 46)
                        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(route?.name ?? "Choose location").font(.system(size: 18, weight: .medium))
                        Text(preferences.autoFastest ? "FASTEST · AUTOMATIC" : (route?.protocolName.uppercased() ?? "AVAILABLE LOCATIONS"))
                            .font(VO1DStyle.mono(9)).foregroundStyle(VO1DStyle.secondary)
                    }
                    Spacer(minLength: 4)
                    if preferences.livePing { PingBadge(ping: route.flatMap { pings.values[$0.code] }) }
                }
            }.padding(18).vo1dSurface()
        }.buttonStyle(ScaleButtonStyle()).accessibilityIdentifier("home.route")
    }
}
