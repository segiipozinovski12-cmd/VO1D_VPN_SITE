import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showKeyHelp = false
    @State private var avatarPulse = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    topBar
                    identityCard
                    subscriptionCard
                    sessionCard
                    preferencesCard
                    actionsCard
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("Change Key", isPresented: $showKeyHelp) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Create a new iPhone key in the VO1D Telegram bot, then log out and activate the app with the new key.")
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                avatarPulse = true
            }
        }
    }

    private var topBar: some View {
        ZStack {
            Text("Profile")
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

    private var identityCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(avatarPulse ? 0.05 : 0.18), lineWidth: 1)
                    .frame(width: avatarPulse ? 64 : 56, height: avatarPulse ? 64 : 56)

                Circle()
                    .fill(.white.opacity(0.07))
                    .frame(width: 52, height: 52)

                Image(systemName: "person.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 5) {
                TextField("Nickname", text: $model.nickname)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 7) {
                    Text("ID \(model.account?.id ?? 0)")
                    Text("•")
                    Text(model.isDemoMode ? "SIMULATOR" : "IPHONE")
                }
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.33))

                Text("VOID-••••-••••-••••")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.24))
            }

            Spacer()
        }
        .padding(14)
        .background(cardBackground)
    }

    private var subscriptionCard: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("SUBSCRIPTION")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.36))

                    Text(model.account?.active == true ? "Active" : "Inactive")
                        .font(.system(size: 15, weight: .semibold))
                }

                Spacer()

                Image(systemName: model.account?.active == true ? "checkmark.shield.fill" : "xmark.shield")
                    .font(.system(size: 24))
                    .foregroundStyle(model.account?.active == true ? activeGreen : .red.opacity(0.75))
            }
            .padding(.vertical, 13)

            divider

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("EXPIRES")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(.white.opacity(0.32))

                    Text(expiryText)
                        .font(.system(size: 12, weight: .medium))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("REMAINING")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(.white.opacity(0.32))

                    Text(remainingText)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
            }
            .padding(.vertical, 13)
        }
        .padding(.horizontal, 14)
        .background(cardBackground)
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CURRENT SESSION")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.36))

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(model.vpn.isConnected ? activeGreen : .white.opacity(0.20))
                        .frame(width: 6, height: 6)

                    Text(model.vpn.isConnected ? "CONNECTED" : "OFFLINE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.48))
                }
            }

            HStack(spacing: 8) {
                miniStat(
                    title: "LOCATION",
                    value: model.selectedServer?.code ?? "—",
                    icon: "mappin.and.ellipse"
                )

                miniStat(
                    title: "TRAFFIC",
                    value: trafficText,
                    icon: "arrow.up.arrow.down"
                )

                miniStat(
                    title: "FAVORITES",
                    value: "\(model.favoriteCodes.count)",
                    icon: "star.fill"
                )
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    private func miniStat(
        title: String,
        value: String,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.42))

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.30))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(.white.opacity(0.035))
        )
    }

    private var preferencesCard: some View {
        VStack(spacing: 0) {
            toggleRow("Auto-connect", icon: "bolt.horizontal.fill", isOn: $model.autoConnect)
            divider
            toggleRow("Kill Switch", icon: "shield.fill", isOn: $model.killSwitch)
            divider

            NavigationLink {
                SettingsView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.50))
                        .frame(width: 19)

                    Text("Settings")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.28))
                }
                .frame(height: 50)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .background(cardBackground)
    }

    private var actionsCard: some View {
        VStack(spacing: 0) {
            Button {
                showKeyHelp = true
            } label: {
                actionRow("Change Key", icon: "key.fill", destructive: false)
            }
            .buttonStyle(.plain)

            divider

            Button(role: .destructive) {
                Task {
                    await model.logout()
                    dismiss()
                }
            } label: {
                actionRow("Log out", icon: "rectangle.portrait.and.arrow.right", destructive: true)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .background(cardBackground)
    }

    private func toggleRow(
        _ label: String,
        icon: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.50))
                .frame(width: 19)

            Text(label)
                .font(.system(size: 13))

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.white)
                .scaleEffect(0.78)
        }
        .frame(height: 50)
    }

    private func actionRow(
        _ title: String,
        icon: String,
        destructive: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(destructive ? .red.opacity(0.82) : .white.opacity(0.50))
                .frame(width: 19)

            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(destructive ? .red.opacity(0.88) : .white)

            Spacer()

            if !destructive {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.28))
            }
        }
        .frame(height: 50)
        .contentShape(Rectangle())
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.white.opacity(0.038))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.065), lineWidth: 1)
            )
    }

    private var divider: some View {
        Divider()
            .overlay(.white.opacity(0.055))
            .padding(.leading, 31)
    }

    private var activeGreen: Color {
        Color(red: 0.39, green: 0.84, blue: 0.48)
    }

    private var expiryText: String {
        guard let until = model.account?.until, until > 0 else {
            return "—"
        }

        return Date(timeIntervalSince1970: TimeInterval(until))
            .formatted(.dateTime.day().month(.abbreviated).year())
    }

    private var remainingText: String {
        guard let seconds = model.account?.remainingSeconds else {
            return "—"
        }

        let days = max(0, seconds) / 86_400
        return "\(days)d"
    }

    private var trafficText: String {
        let total = model.liveStats.downloadedMB + model.liveStats.uploadedMB
        if total < 1024 {
            return String(format: "%.0f MB", total)
        }
        return String(format: "%.1f GB", total / 1024)
    }
}
