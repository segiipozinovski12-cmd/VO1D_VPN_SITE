import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var model: AppViewModel
    @EnvironmentObject private var preferences: Preferences
    @State private var showAvatars = false
    @State private var showKey = false
    @State private var showLogout = false
    @State private var showSettings = false
    @FocusState private var editingName: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                PageHeading(number: "03", title: "Your space", subtitle: "A connection that feels like yours.")
                identity
                subscription
                sessionCard
                Button {
                    showSettings = true
                } label: {
                    actionRow("Settings", subtitle: "Connection & interface", icon: "slider.horizontal.3")
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("profile.settings")
                VStack(spacing: 0) {
                    Button { showKey = true } label: { actionRow("Change Key", subtitle: "Update your access", icon: "key", surface: false) }
                        .buttonStyle(ScaleButtonStyle()).accessibilityIdentifier("profile.changeKey")
                    DividerLine().padding(.horizontal, 18)
                    Button { showLogout = true } label: { actionRow("Log Out", subtitle: model.isDemoMode ? "Leave this demo session" : "Remove this device session", icon: "rectangle.portrait.and.arrow.right", surface: false) }
                        .buttonStyle(ScaleButtonStyle()).accessibilityIdentifier("profile.logout")
                }.vo1dSurface()
                if model.isDemoMode { Eyebrow(text: "DEMO / IPHONE SIMULATOR") }
            }.padding(.horizontal, 22).padding(.bottom, 28)
        }
        .background(VO1DStyle.background).scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)
        .navigationDestination(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showAvatars) { avatarPicker }
        .sheet(isPresented: $showKey) { ChangeKeyView() }
        .confirmationDialog("Log out of VO1D?", isPresented: $showLogout, titleVisibility: .visible) {
            Button("Log Out", role: .destructive) { Task { await model.logout() } }
        }
        .accessibilityIdentifier("profile.screen")
    }
    private var identity: some View {
        HStack(spacing: 18) {
            Button { showAvatars = true } label: {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: preferences.avatar).font(.system(size: 30, weight: .light))
                        .frame(width: 74, height: 74).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 25))
                    Image(systemName: "pencil").font(.system(size: 9, weight: .semibold)).padding(6)
                        .background(VO1DStyle.raised, in: Circle())
                }
            }.buttonStyle(ScaleButtonStyle()).accessibilityLabel("Change avatar").accessibilityIdentifier("profile.avatar")
            VStack(alignment: .leading, spacing: 8) {
                TextField("Your nickname", text: $preferences.nickname)
                    .font(.system(size: 20, weight: .medium)).focused($editingName).submitLabel(.done)
                    .onSubmit { editingName = false }.accessibilityIdentifier("profile.nickname")
                    .onChange(of: preferences.nickname) { _, value in
                        if value.count > 32 { preferences.nickname = String(value.prefix(32)) }
                    }
                Text("USER ID / \(model.account?.id ?? 0)").font(VO1DStyle.mono(10)).foregroundStyle(VO1DStyle.secondary)
                Text("Tap your name to edit").font(.caption2).foregroundStyle(VO1DStyle.secondary)
            }
            Spacer(minLength: 0)
        }.padding(.vertical, 8)
    }
    private var subscription: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Eyebrow(text: "MEMBERSHIP")
                Spacer()
                StatusPill(text: model.account?.active == true ? "ACTIVE" : "INACTIVE", connected: model.account?.active == true)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(remainingDays)").font(.system(size: 54, weight: .light, design: .rounded)).tracking(-2)
                Text("days remaining").font(.subheadline).foregroundStyle(VO1DStyle.secondary)
            }
            DividerLine()
            HStack {
                Text("Expires").font(.subheadline).foregroundStyle(VO1DStyle.secondary)
                Spacer()
                Text(expiration).font(.subheadline.weight(.medium))
            }
        }.padding(22).vo1dSurface(highlighted: true)
    }
    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(text: "CURRENT SESSION")
                Spacer()
                Circle().fill(model.isConnected ? VO1DStyle.green : VO1DStyle.secondary).frame(width: 5, height: 5)
            }
            DetailRow(title: "State", value: model.phase.rawValue)
            DividerLine()
            DetailRow(title: "Location", value: model.activeServer?.name ?? "Not connected")
            DividerLine()
            ProfileTrafficRow()
            DividerLine()
            DetailRow(title: "Favorites", value: String(model.favoriteCodes.count))
        }.padding(18).vo1dSurface()
    }
    private func actionRow(_ title: String, subtitle: String, icon: String, surface: Bool = true) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 19, weight: .light)).frame(width: 25)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.subheadline.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(VO1DStyle.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(VO1DStyle.secondary)
        }.padding(18).background(surface ? VO1DStyle.panel : .clear, in: RoundedRectangle(cornerRadius: 22))
    }
    private var avatarPicker: some View {
        VStack(spacing: 26) {
            Text("Make it yours").font(.title2.weight(.semibold))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                ForEach(Preferences.avatars, id: \.self) { symbol in
                    Button {
                        preferences.avatar = symbol
                        Haptics.play(.selection, enabled: preferences.haptics)
                        showAvatars = false
                    } label: {
                        Image(systemName: symbol).font(.system(size: 27, weight: .light)).frame(maxWidth: .infinity).frame(height: 74)
                            .vo1dSurface(highlighted: preferences.avatar == symbol, radius: 18)
                    }.buttonStyle(ScaleButtonStyle()).accessibilityLabel(symbol).accessibilityIdentifier("avatar.\(symbol)")
                }
            }
        }.padding(24).presentationDetents([.height(310)]).presentationDragIndicator(.visible)
            .presentationBackground(VO1DStyle.background)
    }
    private var remainingDays: Int {
        guard let until = model.account?.until else { return 0 }
        return max(0, Int(ceil((Double(until) - Date().timeIntervalSince1970) / 86_400)))
    }
    private var expiration: String {
        guard let until = model.account?.until else { return "—" }
        return Date(timeIntervalSince1970: Double(until)).formatted(.dateTime.day().month(.abbreviated).year())
    }
}

private struct ProfileTrafficRow: View {
    @EnvironmentObject private var session: SessionMonitor
    var body: some View {
        DetailRow(title: "Traffic", value: session.hasTrafficMeasurements ? "\(session.stats.trafficValue) \(session.stats.trafficUnit) · Demo" : "Unavailable")
    }
}

private struct ChangeKeyView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("Change access key").font(.title2.weight(.semibold))
                Spacer()
                IconButton(icon: "xmark", label: "Close") { dismiss() }
            }
            Text(model.isDemoMode ? "This starts a fresh demo session. No key or backend is required." : "Your current key remains active until the new key is accepted.")
                .font(.subheadline).foregroundStyle(VO1DStyle.secondary)
            if !model.isDemoMode {
                TextField("VOID-… or VO1D1.…", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(VO1DStyle.mono(13)).padding(18).vo1dSurface(radius: 14)
            }
            PrimaryButton(title: model.isActivating ? "Activating…" : model.isDemoMode ? "Restart demo session" : "Activate new key", icon: "key") {
                Task { if await model.activate(key: key) { dismiss() } }
            }.disabled(model.isActivating || (!model.isDemoMode && key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            if let error = model.errorMessage { Text(error).font(.caption).foregroundStyle(VO1DStyle.red) }
            Spacer(minLength: 0)
        }.padding(24).presentationDetents([.medium]).presentationDragIndicator(.visible).presentationBackground(VO1DStyle.background)
    }
}
