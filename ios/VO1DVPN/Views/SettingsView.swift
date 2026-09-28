import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppViewModel
    @EnvironmentObject private var preferences: Preferences
    @Environment(\.dismiss) private var dismiss
    @Environment(\.vo1dReduceMotion) private var reduceMotion

    @State private var appeared = false

    private var pendingOptions: Bool {
        model.isConnected &&
        model.appliedOptions != preferences.connectionOptions
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                topBar
                    .settingsReveal(appeared, delay: 0.00, reduceMotion: reduceMotion)

                titleBlock
                    .settingsReveal(appeared, delay: 0.03, reduceMotion: reduceMotion)

                settingsSection(
                    title: "CONNECTION",
                    detail: "Route options apply on the next connection."
                ) {
                    referenceToggle(
                        "Auto Connect",
                        detail: "Connect when the app starts",
                        icon: "power",
                        value: $preferences.autoConnect,
                        id: "autoConnect"
                    )

                    divider

                    referenceToggle(
                        "Auto Fastest Server",
                        detail: "Use the lowest measured ping",
                        icon: "bolt.fill",
                        value: $preferences.autoFastest,
                        id: "autoFastest"
                    )

                    divider

                    referenceToggle(
                        "Kill Switch",
                        detail: "Keep traffic inside the VPN route",
                        icon: "shield",
                        value: $preferences.killSwitch,
                        id: "killSwitch"
                    )

                    divider

                    referenceToggle(
                        "Secure DNS",
                        detail: "Resolve DNS inside the tunnel",
                        icon: "lock",
                        value: $preferences.secureDNS,
                        id: "secureDNS"
                    )

                    divider

                    referenceToggle(
                        "IPv6 Protection",
                        detail: "Include IPv6 in the tunnel route",
                        icon: "network",
                        value: $preferences.ipv6Protection,
                        id: "ipv6Protection"
                    )
                }
                .settingsReveal(appeared, delay: 0.06, reduceMotion: reduceMotion)

                if pendingOptions {
                    ReferencePrimaryButton(
                        title: "Reconnect to Apply",
                        icon: "arrow.triangle.2.circlepath",
                        action: model.reconnect
                    )
                    .accessibilityIdentifier("settings.apply")
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                settingsSection(
                    title: "INTERFACE",
                    detail: "Keep the experience clean and responsive."
                ) {
                    referenceToggle(
                        "Live Ping",
                        detail: "Measure route latency periodically",
                        icon: "waveform.path.ecg",
                        value: $preferences.livePing,
                        id: "livePing"
                    )

                    divider

                    referenceToggle(
                        "Reduce Animations",
                        detail: "Minimize looping motion and transitions",
                        icon: "circle.dotted",
                        value: $preferences.reduceAnimations,
                        id: "reduceMotion"
                    )

                    divider

                    referenceToggle(
                        "Compact Server List",
                        detail: "Fit more locations on screen",
                        icon: "line.3.horizontal",
                        value: $preferences.compactServers,
                        id: "compactServers"
                    )

                    divider

                    referenceToggle(
                        "Haptic Feedback",
                        detail: "Tactile feedback on supported iPhones",
                        icon: "hand.tap",
                        value: $preferences.haptics,
                        id: "haptics"
                    )
                }
                .settingsReveal(appeared, delay: 0.10, reduceMotion: reduceMotion)

                networkSection
                    .settingsReveal(appeared, delay: 0.14, reduceMotion: reduceMotion)

                legalSection
                    .settingsReveal(appeared, delay: 0.17, reduceMotion: reduceMotion)

                if model.isDemoMode {
                    Text("SIMULATOR DEMO / NO REAL VPN TRAFFIC")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.30))
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .toolbar(.hidden, for: .navigationBar)
        .animation(
            reduceMotion
            ? nil
            : .snappy(duration: 0.28),
            value: pendingOptions
        )
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
        .accessibilityIdentifier("settings.screen")
    }

    private var topBar: some View {
        ZStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))
                        .frame(width: 38, height: 38)
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
                .accessibilityLabel("Back")

                Spacer()
            }

            VO1DBrandLockup(compact: true)
        }
        .frame(height: 48)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("SETTINGS")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(2.1)
                .foregroundStyle(.white.opacity(0.38))

            Text("Fine-tune VO1D")
                .font(.system(size: 28, weight: .semibold))
                .tracking(-0.7)

            Text("Connection behavior, interface and live network state.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.40))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsSection<Content: View>(
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text(title)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.7)
                    .foregroundStyle(.white.opacity(0.38))

                Spacer()
            }

            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.34))

            ReferenceGlassCard(radius: 22) {
                VStack(spacing: 0) {
                    content()
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func referenceToggle(
        _ title: String,
        detail: String,
        icon: String,
        value: Binding<Bool>,
        id: String
    ) -> some View {
        Toggle(
            isOn: Binding(
                get: { value.wrappedValue },
                set: { newValue in
                    let hapticsEnabled = preferences.haptics
                    value.wrappedValue = newValue
                    Haptics.play(
                        .selection,
                        enabled: hapticsEnabled
                    )
                }
            )
        ) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
                    .fill(.white.opacity(0.045))
                    .frame(width: 34, height: 34)
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 10,
                            style: .continuous
                        )
                        .strokeBorder(
                            .white.opacity(0.08),
                            lineWidth: 0.8
                        )
                    )

                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(.white.opacity(0.82))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)

                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.34))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(.white)
        .padding(.vertical, 14)
        .accessibilityIdentifier("settings.\(id)")
    }

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("NETWORK")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(1.7)
                .foregroundStyle(.white.opacity(0.38))

            Text("Current session information.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.34))

            ReferenceGlassCard(radius: 22) {
                VStack(spacing: 0) {
                    networkRow(
                        "Protocol",
                        model.activeServer?.protocolName ??
                        model.selectedServer?.protocolName ??
                        "—"
                    )

                    divider

                    networkRow(
                        "Current Route",
                        model.activeServer?.name ?? "Not connected"
                    )

                    divider

                    SettingsQualityRow(
                        code: model.activeServer?.code
                    )
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("LEGAL")
                .font(
                    .system(
                        size: 9,
                        weight: .medium,
                        design: .monospaced
                    )
                )
                .tracking(1.7)
                .foregroundStyle(.white.opacity(0.38))

            Text("Privacy, payments and service terms.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.34))

            ReferenceGlassCard(radius: 22) {
                VStack(spacing: 0) {
                    NavigationLink {
                        LegalDocumentView(document: .privacy)
                    } label: {
                        legalRow(
                            title: "Privacy Policy",
                            detail: "RollyPay.io · August 12, 2026",
                            icon: "hand.raised"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.privacy")

                    divider

                    NavigationLink {
                        LegalDocumentView(document: .terms)
                    } label: {
                        legalRow(
                            title: "User Agreement",
                            detail: "Public offer · RollyPay.io",
                            icon: "doc.text"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.terms")
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func legalRow(
        title: String,
        detail: String,
        icon: String
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
                .fill(.white.opacity(0.045))
                .frame(width: 34, height: 34)
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
                    .strokeBorder(
                        .white.opacity(0.08),
                        lineWidth: 0.8
                    )
                }

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(.white.opacity(0.82))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)

                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.34))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.34))
        }
        .padding(.vertical, 14)
    }

    private func networkRow(
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
        .padding(.vertical, 14)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.07))
            .frame(height: 1)
    }
}

private struct SettingsQualityRow: View {
    @EnvironmentObject private var pings: PingStore
    let code: String?

    var body: some View {
        HStack {
            Text("Connection Quality")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.42))

            Spacer()

            Text(
                code.map {
                    VO1DStyle.quality(pings.values[$0])
                } ?? "Not connected"
            )
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.78))
        }
        .padding(.vertical, 14)
    }
}

private extension View {
    func settingsReveal(
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
