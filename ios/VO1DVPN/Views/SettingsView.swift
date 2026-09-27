import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("vo1d.secureDNS") private var secureDNS = true
    @AppStorage("vo1d.ipv6Protection") private var ipv6Protection = true
    @AppStorage("vo1d.reduceAnimations") private var reduceAnimations = false
    @AppStorage("vo1d.showLivePing") private var showLivePing = true
    @AppStorage("vo1d.compactServers") private var compactServers = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    topBar

                    section(
                        title: "CONNECTION",
                        subtitle: "Automatic protection and routing"
                    ) {
                        toggleRow("Auto-connect", icon: "bolt.horizontal.fill", isOn: $model.autoConnect)
                        divider
                        toggleRow("Kill Switch", icon: "shield.fill", isOn: $model.killSwitch)
                        divider
                        toggleRow("Secure DNS", icon: "lock.shield.fill", isOn: $secureDNS)
                        divider
                        toggleRow("IPv6 Protection", icon: "network", isOn: $ipv6Protection)
                    }

                    section(
                        title: "INTERFACE",
                        subtitle: "Tune the app for your device"
                    ) {
                        toggleRow("Live Ping", icon: "waveform.path.ecg", isOn: $showLivePing)
                        divider
                        toggleRow("Reduce Animations", icon: "figure.walk.motion", isOn: $reduceAnimations)
                        divider
                        toggleRow("Compact Server List", icon: "rectangle.compress.vertical", isOn: $compactServers)
                    }

                    section(
                        title: "CURRENT ROUTE",
                        subtitle: "Read-only connection information"
                    ) {
                        valueRow(
                            "Protocol",
                            icon: "point.3.connected.trianglepath.dotted",
                            value: protocolText
                        )
                        divider
                        valueRow(
                            "Location",
                            icon: "mappin.and.ellipse",
                            value: model.selectedServer?.name ?? "Automatic"
                        )
                        divider
                        valueRow(
                            "Quality",
                            icon: "gauge.with.dots.needle.67percent",
                            value: model.connectionQuality
                        )
                    }

                    if model.isDemoMode {
                        HStack(spacing: 9) {
                            Image(systemName: "info.circle")
                            Text("Simulator mode uses local demo data. Real VPN behavior is unchanged on a physical iPhone.")
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.34))
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        ZStack {
            Text("Settings")
                .font(.system(size: 17, weight: .semibold))

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(ScaleButtonStyle())

                Spacer()
            }
        }
        .frame(height: 42)
        .padding(.top, 6)
    }

    private func section<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.46))

                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.25))
            }

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white.opacity(0.038))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.065), lineWidth: 1)
            )
        }
    }

    private func toggleRow(
        _ label: String,
        icon: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))
                .frame(width: 19)

            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.90))

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.white)
                .scaleEffect(0.78)
        }
        .frame(height: 50)
    }

    private func valueRow(
        _ label: String,
        icon: String,
        value: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))
                .frame(width: 19)

            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.90))

            Spacer()

            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.46))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(height: 50)
    }

    private var divider: some View {
        Divider()
            .overlay(.white.opacity(0.055))
            .padding(.leading, 31)
    }

    private var protocolText: String {
        let raw = model.selectedServer?.protocolName.uppercased() ?? "VLESS"
        return raw.isEmpty ? "VLESS" : raw
    }
}
