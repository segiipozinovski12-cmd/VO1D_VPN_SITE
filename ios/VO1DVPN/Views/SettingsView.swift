import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("vo1d.secureDNS") private var secureDNS = true
    @AppStorage("vo1d.ipv6Protection") private var ipv6Protection = true
    @AppStorage("vo1d.appearance") private var appearance = "Dark"
    @AppStorage("vo1d.language") private var language = "English"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    topBar

                    VStack(spacing: 0) {
                        toggleRow("Auto-connect", isOn: $model.autoConnect)
                        divider
                        toggleRow("Kill Switch", isOn: $model.killSwitch)
                        divider
                        toggleRow("Secure DNS", isOn: $secureDNS)
                        divider
                        toggleRow("IPv6 Protection", isOn: $ipv6Protection)
                        divider
                        valueRow("Protocol", value: protocolText)
                        divider
                        valueRow("Appearance", value: appearance)
                        divider
                        valueRow("Language", value: language)
                    }
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.045))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.07), lineWidth: 1)
                    )
                    .padding(.top, 18)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        ZStack {
            Text("Settings")
                .font(.system(size: 16, weight: .semibold))

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                }
                Spacer()
            }
        }
        .frame(height: 38)
        .padding(.top, 6)
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.9))

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.white)
                .scaleEffect(0.78)
        }
        .frame(height: 48)
    }

    private func valueRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.9))

            Spacer()

            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.22))
        }
        .frame(height: 48)
    }

    private var divider: some View {
        Divider()
            .overlay(.white.opacity(0.065))
    }

    private var protocolText: String {
        let raw = model.selectedServer?.protocolName.uppercased() ?? "VLESS"
        return raw.isEmpty ? "VLESS" : raw
    }
}
