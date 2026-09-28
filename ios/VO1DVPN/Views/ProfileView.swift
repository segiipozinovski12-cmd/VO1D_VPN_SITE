import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var model: AppViewModel
    @EnvironmentObject private var preferences: Preferences
    @Environment(\.vo1dReduceMotion) private var reduceMotion

    @State private var showKey = false
    @State private var showLogout = false
    @State private var showSettings = false
    @State private var appeared = false

    @FocusState private var editingName: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                brandHeader
                    .profileReveal(appeared, delay: 0.00, reduceMotion: reduceMotion)

                titleBlock
                    .profileReveal(appeared, delay: 0.03, reduceMotion: reduceMotion)

                identityCard
                    .profileReveal(appeared, delay: 0.06, reduceMotion: reduceMotion)

                membershipCard
                    .profileReveal(appeared, delay: 0.09, reduceMotion: reduceMotion)

                sessionCard
                    .profileReveal(appeared, delay: 0.12, reduceMotion: reduceMotion)

                actionStack
                    .profileReveal(appeared, delay: 0.15, reduceMotion: reduceMotion)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 22)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .navigationDestination(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showKey) {
            ChangeKeyView()
        }
        .confirmationDialog(
            "Log out of VO1D?",
            isPresented: $showLogout,
            titleVisibility: .visible
        ) {
            Button("Log Out", role: .destructive) {
                Task { await model.logout() }
            }
        }
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
        .accessibilityIdentifier("profile.screen")
    }

    private var brandHeader: some View {
        HStack {
            VO1DBrandLockup(compact: true)

            Spacer()

            StatusPill(
                text: model.account?.active == true ? "ACTIVE" : "INACTIVE",
                connected: model.account?.active == true
            )
        }
        .frame(height: 50)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("PROFILE")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(2.1)
                .foregroundStyle(.white.opacity(0.38))

            Text("Your space")
                .font(.system(size: 28, weight: .semibold))
                .tracking(-0.7)

            Text("Access, identity and connection settings.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.40))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var identityCard: some View {
        ReferenceGlassCard(radius: 24) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(
                        cornerRadius: 20,
                        style: .continuous
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.14),
                                VO1DStyle.graphite.opacity(0.72),
                                .black.opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(
                            cornerRadius: 20,
                            style: .continuous
                        )
                    )
                    .frame(width: 68, height: 68)
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 20,
                            style: .continuous
                        )
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.42),
                                    .white.opacity(0.08),
                                    VO1DStyle.frost.opacity(0.20)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                    }

                    Image(systemName: "person.fill")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(color: .white.opacity(0.18), radius: 7)
                }
                .accessibilityIdentifier("profile.avatar")

                VStack(alignment: .leading, spacing: 7) {
                    TextField(
                        "Your nickname",
                        text: $preferences.nickname
                    )
                    .font(.system(size: 20, weight: .semibold))
                    .focused($editingName)
                    .submitLabel(.done)
                    .onSubmit { editingName = false }
                    .onChange(of: preferences.nickname) { _, value in
                        if value.count > 32 {
                            preferences.nickname = String(value.prefix(32))
                        }
                    }
                    .accessibilityIdentifier("profile.nickname")

                    Text("USER ID / \(model.account?.id ?? 0)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.35))

                    Text("Tap the name to edit")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.28))
                }

                Spacer(minLength: 0)
            }
            .padding(18)
        }
    }

    private var membershipCard: some View {
        ReferenceGlassCard(
            radius: 24,
            highlighted: model.account?.active == true
        ) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("MEMBERSHIP")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(1.7)
                        .foregroundStyle(.white.opacity(0.38))

                    Spacer()

                    Text(model.account?.active == true ? "ACTIVE" : "INACTIVE")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.72))
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(remainingDays)")
                        .font(.system(size: 54, weight: .light, design: .rounded))
                        .tracking(-2)
                        .monospacedDigit()

                    Text("days remaining")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.40))
                }

                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(height: 1)

                HStack {
                    Text("Expires")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.42))

                    Spacer()

                    Text(expiration)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                }
            }
            .padding(20)
        }
    }

    private var sessionCard: some View {
        ReferenceGlassCard(radius: 22) {
            VStack(spacing: 0) {
                HStack {
                    Text("CURRENT SESSION")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(1.7)
                        .foregroundStyle(.white.opacity(0.38))

                    Spacer()

                    Circle()
                        .fill(
                            model.isConnected
                            ? .white
                            : .white.opacity(0.18)
                        )
                        .frame(width: 5, height: 5)
                        .shadow(
                            color:
                                model.isConnected
                                ? .white.opacity(0.44)
                                : .clear,
                            radius: 5
                        )
                }
                .padding(.bottom, 13)

                sessionRow("State", model.phase.rawValue)
                divider
                sessionRow(
                    "Location",
                    model.activeServer?.name ?? "Not connected"
                )
                divider
                ProfileTrafficRow()
                divider
                sessionRow(
                    "Favorites",
                    String(model.favoriteCodes.count)
                )
            }
            .padding(18)
        }
    }

    private var actionStack: some View {
        VStack(spacing: 10) {
            profileAction(
                title:
                    model.hasActiveSubscription
                    ? "Subscription"
                    : "Get Subscription",
                detail:
                    model.hasActiveSubscription
                    ? "View plans or activate another key"
                    : "Choose a plan or activate your VOID key",
                icon: "creditcard"
            ) {
                model.presentPaywall()
            }
            .accessibilityIdentifier("profile.subscription")

            profileAction(
                title: "Settings",
                detail: "Connection & interface",
                icon: "gearshape"
            ) {
                showSettings = true
            }
            .accessibilityIdentifier("profile.settings")

            profileAction(
                title: "Change Key",
                detail: "Activate another VOID license",
                icon: "key.horizontal"
            ) {
                showKey = true
            }
            .accessibilityIdentifier("profile.changeKey")

            profileAction(
                title: "Log Out",
                detail:
                    model.isDemoMode
                    ? "Leave this demo session"
                    : "Remove this device session",
                icon: "rectangle.portrait.and.arrow.right"
            ) {
                showLogout = true
            }
            .accessibilityIdentifier("profile.logout")
        }
    }

    private func profileAction(
        title: String,
        detail: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ReferenceGlassCard(radius: 18) {
                HStack(spacing: 13) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)

                        Text(detail)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.36))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.40))
                }
                .padding(16)
            }
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.985))
    }

    private func sessionRow(
        _ title: String,
        _ value: String
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.42))

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 11)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.07))
            .frame(height: 1)
    }

    private var remainingDays: Int {
        guard let until = model.account?.until else { return 0 }

        return max(
            0,
            Int(
                ceil(
                    (Double(until) - Date().timeIntervalSince1970)
                    / 86_400
                )
            )
        )
    }

    private var expiration: String {
        guard let until = model.account?.until else { return "—" }

        return Date(
            timeIntervalSince1970: Double(until)
        )
        .formatted(
            .dateTime
                .day()
                .month(.abbreviated)
                .year()
        )
    }
}

private struct ProfileTrafficRow: View {
    @EnvironmentObject private var model: AppViewModel
    @EnvironmentObject private var session: SessionMonitor

    var body: some View {
        HStack {
            Text("Traffic")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.42))

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
        }
        .padding(.vertical, 11)
    }

    private var value: String {
        guard session.hasTrafficMeasurements else {
            return "Measuring…"
        }

        let suffix = model.isDemoMode ? " · Demo" : ""

        return "\(session.stats.trafficValue) \(session.stats.trafficUnit)\(suffix)"
    }
}

private struct ChangeKeyView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var key = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            ReferenceBackdrop()

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CHANGE KEY")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .tracking(1.8)
                            .foregroundStyle(.white.opacity(0.38))

                        Text("Activate license")
                            .font(.system(size: 24, weight: .semibold))
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 36, height: 36)
                            .foregroundStyle(.white.opacity(0.82))
                            .background(
                                Color.white.opacity(0.045),
                                in: Circle()
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        .white.opacity(0.10),
                                        lineWidth: 0.8
                                    )
                            )
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.92))
                }

                Text(
                    model.isDemoMode
                    ? "This starts a fresh Simulator session."
                    : "Enter one of the fixed VO1D licenses in VOID-XXXX-XXXX-XXXX format."
                )
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.42))
                .fixedSize(horizontal: false, vertical: true)

                if !model.isDemoMode {
                    HStack {
                        TextField(
                            "VOID-XXXX-XXXX-XXXX",
                            text: $key
                        )
                        .font(.system(size: 14, weight: .medium))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($focused)
                        .onChange(of: key) { _, value in
                            let formatted = formatKey(value)

                            if formatted != key {
                                key = formatted
                            }
                        }

                        Image(
                            systemName:
                                AccessKeyVault.license(for: key) != nil
                                ? "checkmark.circle.fill"
                                : "key.horizontal"
                        )
                        .foregroundStyle(
                            AccessKeyVault.license(for: key) != nil
                            ? .white
                            : .white.opacity(0.28)
                        )
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(
                        Color.white.opacity(0.03),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                .white.opacity(focused ? 0.24 : 0.09),
                                lineWidth: 0.8
                            )
                    )
                }

                ReferencePrimaryButton(
                    title:
                        model.isActivating
                        ? "Activating..."
                        : model.isDemoMode
                            ? "Restart Demo"
                            : "Activate Key",
                    icon: "chevron.right"
                ) {
                    Task {
                        if await model.activate(key: key) {
                            dismiss()
                        }
                    }
                }
                .disabled(
                    model.isActivating ||
                    (
                        !model.isDemoMode &&
                        AccessKeyVault.license(for: key) == nil
                    )
                )

                if let error = model.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(VO1DStyle.red)
                }

                Spacer()
            }
            .padding(22)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(.black)
        .onAppear { focused = !model.isDemoMode }
    }

    private func formatKey(_ input: String) -> String {
        var raw = input
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }

        if raw.hasPrefix("VOID") {
            raw.removeFirst(4)
        }

        raw = String(raw.prefix(12))
        guard !raw.isEmpty else { return "" }

        var groups: [String] = []
        var index = raw.startIndex

        while index < raw.endIndex {
            let end = raw.index(
                index,
                offsetBy: min(
                    4,
                    raw.distance(from: index, to: raw.endIndex)
                )
            )

            groups.append(String(raw[index..<end]))
            index = end
        }

        return "VOID-" + groups.joined(separator: "-")
    }
}

private extension View {
    func profileReveal(
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
