import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showKeyHelp = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    topBar

                    avatarBlock
                        .padding(.top, 18)

                    subscriptionCard
                        .padding(.top, 20)

                    preferencesCard
                        .padding(.top, 14)

                    actionsCard
                        .padding(.top, 14)
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
    }

    private var topBar: some View {
        ZStack {
            Text("Profile")
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

    private var avatarBlock: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 62, height: 62)

                Image(systemName: "person.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
            }

            TextField("Nickname", text: $model.nickname)
                .multilineTextAlignment(.center)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 180)

            Text("ID \(model.account?.id ?? 0)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.38))

            Text("VOID-••••-••••-••••")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.28))
        }
    }

    private var subscriptionCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Subscription")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.52))

                Spacer()

                Text(model.account?.active == true ? "Active" : "Inactive")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(model.account?.active == true ? activeGreen : .red.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(
                                model.account?.active == true
                                ? activeGreen.opacity(0.13)
                                : Color.red.opacity(0.12)
                            )
                    )
            }
            .frame(height: 44)

            divider

            HStack {
                Text("Expires")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.52))

                Spacer()

                Text(expiryText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(height: 44)
        }
        .padding(.horizontal, 14)
        .background(cardBackground)
    }

    private var preferencesCard: some View {
        VStack(spacing: 0) {
            toggleRow("Auto-connect", isOn: $model.autoConnect)
            divider
            toggleRow("Kill Switch", isOn: $model.killSwitch)
            divider

            NavigationLink {
                SettingsView()
            } label: {
                HStack {
                    Text("Settings")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .frame(height: 46)
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
                actionRow("Change Key", destructive: false)
            }
            .buttonStyle(.plain)

            divider

            Button(role: .destructive) {
                Task {
                    await model.logout()
                    dismiss()
                }
            } label: {
                actionRow("Log out", destructive: true)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .background(cardBackground)
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.white)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.white)
                .scaleEffect(0.78)
        }
        .frame(height: 46)
    }

    private func actionRow(_ title: String, destructive: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(destructive ? .red.opacity(0.9) : .white)

            Spacer()

            if !destructive {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .frame(height: 46)
        .contentShape(Rectangle())
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.white.opacity(0.045))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.07), lineWidth: 1)
            )
    }

    private var divider: some View {
        Divider()
            .overlay(.white.opacity(0.065))
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
}
