import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppViewModel
    @EnvironmentObject private var preferences: Preferences
    @Environment(\.dismiss) private var dismiss
    private var pendingOptions: Bool { model.isConnected && model.appliedOptions != preferences.connectionOptions }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack {
                    IconButton(icon: "chevron.left", label: "Back") { dismiss() }
                    Spacer()
                    Eyebrow(text: "VO1D / PREFERENCES")
                }
                Text("Fine-tune\nyour connection.").font(.system(size: 34, weight: .medium)).tracking(-1)
                section("CONNECTION", detail: "Route options apply on the next connection.") {
                    toggle("Auto Connect", detail: "Connect when the app starts", icon: "power", value: $preferences.autoConnect, id: "autoConnect")
                    DividerLine()
                    toggle("Auto Fastest Server", detail: "Use the lowest ping on Connect", icon: "bolt", value: $preferences.autoFastest, id: "autoFastest")
                    DividerLine()
                    toggle("Kill Switch", detail: "Route all networks through the VPN", icon: "shield", value: $preferences.killSwitch, id: "killSwitch")
                    DividerLine()
                    toggle("Secure DNS", detail: "DNS over HTTPS in the tunnel", icon: "lock", value: $preferences.secureDNS, id: "secureDNS")
                    DividerLine()
                    toggle("IPv6 Protection", detail: "Include IPv6 in the tunnel route", icon: "network", value: $preferences.ipv6Protection, id: "ipv6Protection")
                }
                if pendingOptions {
                    PrimaryButton(title: "Reconnect to apply changes", icon: "arrow.triangle.2.circlepath", action: model.reconnect)
                        .accessibilityIdentifier("settings.apply")
                }
                section("INTERFACE", detail: "Make VO1D work your way.") {
                    toggle("Live Ping", detail: "Measure routes every eight seconds", icon: "waveform.path.ecg", value: $preferences.livePing, id: "livePing")
                    DividerLine()
                    toggle("Reduce Animations", detail: "Stop looping motion and transitions", icon: "circle.dotted", value: $preferences.reduceAnimations, id: "reduceMotion")
                    DividerLine()
                    toggle("Compact Server List", detail: "Show more locations at a glance", icon: "line.3.horizontal", value: $preferences.compactServers, id: "compactServers")
                    DividerLine()
                    toggle("Haptic Feedback", detail: "Tactile responses on iPhone", icon: "hand.tap", value: $preferences.haptics, id: "haptics")
                }
                section("NETWORK", detail: "Current session information.") {
                    DetailRow(title: "Protocol", value: model.activeServer?.protocolName ?? model.selectedServer?.protocolName ?? "—")
                    DividerLine()
                    DetailRow(title: "Current Route", value: model.activeServer?.name ?? "Not connected")
                    DividerLine()
                    SettingsQualityRow(code: model.activeServer?.code)
                }
                if model.isDemoMode {
                    Text("DEMO / Changes are saved locally. No VPN traffic is generated.")
                        .font(.caption).foregroundStyle(VO1DStyle.secondary)
                }
            }.padding(22)
        }
        .background(VO1DStyle.background).scrollIndicators(.hidden)
        .toolbar(.hidden, for: .navigationBar).accessibilityIdentifier("settings.screen")
    }
    private func section<Content: View>(_ title: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Eyebrow(text: title)
            Text(detail).font(.caption).foregroundStyle(VO1DStyle.secondary)
            VStack(spacing: 0, content: content).padding(.horizontal, 16).vo1dSurface()
        }
    }
    private func toggle(_ title: String, detail: String, icon: String, value: Binding<Bool>, id: String) -> some View {
        Toggle(isOn: value) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 17, weight: .light)).frame(width: 22)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.subheadline.weight(.medium))
                    Text(detail).font(.caption2).foregroundStyle(VO1DStyle.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(Color(white: 0.42)).padding(.vertical, 15).accessibilityIdentifier("settings.\(id)")
    }
}

private struct SettingsQualityRow: View {
    @EnvironmentObject private var pings: PingStore
    let code: String?
    var body: some View {
        DetailRow(title: "Connection Quality", value: code.map { VO1DStyle.quality(pings.values[$0]) } ?? "Not connected")
    }
}
