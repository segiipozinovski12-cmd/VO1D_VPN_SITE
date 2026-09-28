import Foundation
import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.vo1dReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    @State private var key = ""
    @State private var appeared = false
    @State private var selectedPlan = 30
    @State private var planGlow = false
    @FocusState private var keyFocused: Bool

    private let plans = [
        AccessPlan(days: 30, title: "1 MONTH", price: "$1.99", detail: "30 days"),
        AccessPlan(days: 90, title: "3 MONTHS", price: "$4.99", detail: "90 days"),
        AccessPlan(days: 180, title: "6 MONTHS", price: "$8.99", detail: "180 days"),
        AccessPlan(days: 365, title: "1 YEAR", price: "$14.99", detail: "365 days")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                    .vo1dReveal(appeared, reduceMotion: reduceMotion, delay: 0.00)

                hero
                    .vo1dReveal(appeared, reduceMotion: reduceMotion, delay: 0.05)

                if model.isDemoMode {
                    demoEntry
                        .vo1dReveal(appeared, reduceMotion: reduceMotion, delay: 0.11)
                } else {
                    subscriptionSection
                        .vo1dReveal(appeared, reduceMotion: reduceMotion, delay: 0.10)

                    keySection
                        .vo1dReveal(appeared, reduceMotion: reduceMotion, delay: 0.17)
                }

                footer
                    .vo1dReveal(appeared, reduceMotion: reduceMotion, delay: 0.22)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 34)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background {
            ZStack {
                DeepSpaceBackdrop()

                RadialGradient(
                    colors: [
                        .white.opacity(planGlow ? 0.040 : 0.015),
                        .clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.38),
                    startRadius: 0,
                    endRadius: 360
                )
            }
            .ignoresSafeArea()
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.46)) {
                    appeared = true
                }

                withAnimation(
                    .easeInOut(duration: 2.8)
                    .repeatForever(autoreverses: true)
                ) {
                    planGlow = true
                }
            }
        }
        .accessibilityIdentifier("login.screen")
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("VO1D_VPN")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .tracking(0.8)

                Text(model.isDemoMode ? "SIMULATOR PREVIEW" : "NATIVE PRIVATE NETWORK")
                    .font(VO1DStyle.mono(8))
                    .tracking(1.5)
                    .foregroundStyle(VO1DStyle.secondary)
            }

            Spacer()

            StatusPill(
                text: model.isDemoMode ? "DEMO" : "ACCESS",
                connected: false
            )
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Color.clear
                        .frame(width: 56, height: 56)
                        .vo1dSystemGlass(
                            in: RoundedRectangle(
                                cornerRadius: 18,
                                style: .continuous
                            )
                        )

                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.25),
                                .white.opacity(0.055)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 56, height: 56)

                    Image(systemName: model.isDemoMode ? "play.fill" : "shield.lefthalf.filled")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Eyebrow(text: model.isDemoMode ? "LOCAL DEMO" : "FIRST CONNECTION")

                    Text(model.isDemoMode ? "Explore VO1D" : "Choose access. Enter your key.")
                        .font(.system(size: 22, weight: .semibold))
                        .tracking(-0.5)
                }
            }

            Text(
                model.isDemoMode
                ? "The Simulator keeps the complete interface and animations, but network traffic stays local."
                : "Pick a subscription, message @vo1d_root to purchase it, then activate the license key you receive."
            )
            .font(.subheadline)
            .foregroundStyle(VO1DStyle.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .vo1dSurface(highlighted: true, radius: 24)
    }

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow(text: "01 / CHOOSE ACCESS")
                Spacer()
                Text("400 LICENSES")
                    .font(VO1DStyle.mono(8))
                    .tracking(0.8)
                    .foregroundStyle(VO1DStyle.secondary)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(plans) { plan in
                    planCard(plan)
                }
            }

            Button {
                guard let plan = plans.first(where: { $0.days == selectedPlan }) else { return }
                openPurchase(plan)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .semibold))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("BUY IN TELEGRAM")
                            .font(VO1DStyle.mono(10))
                            .tracking(0.7)

                        Text("@vo1d_root · \\(selectedPlanTitle)")
                            .font(.caption)
                            .foregroundStyle(.black.opacity(0.62))
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 17)
                .frame(height: 58)
                .background(
                    LinearGradient(
                        colors: [.white, Color(white: 0.87)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .strokeBorder(.white.opacity(0.92), lineWidth: 1)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("purchase.telegram")
        }
    }

    private func planCard(_ plan: AccessPlan) -> some View {
        let selected = selectedPlan == plan.days

        return Button {
            selectedPlan = plan.days
            Haptics.play(.selection, enabled: model.preferences.haptics)
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(plan.title)
                        .font(VO1DStyle.mono(9))
                        .tracking(0.4)

                    Spacer()

                    Circle()
                        .fill(selected ? .white : .white.opacity(0.16))
                        .frame(width: 6, height: 6)
                        .shadow(
                            color: selected ? .white.opacity(0.35) : .clear,
                            radius: 5
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.price)
                        .font(.system(size: 25, weight: .semibold, design: .rounded))
                        .monospacedDigit()

                    Text(plan.detail)
                        .font(.caption)
                        .foregroundStyle(VO1DStyle.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .vo1dSurface(highlighted: selected, radius: 18)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        .white.opacity(selected ? 0.22 : 0.035),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("plan.\\(plan.days)")
    }

    private var keySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow(text: "02 / ACTIVATE KEY")

                Spacer()

                Text("12 CHARACTERS")
                    .font(VO1DStyle.mono(8))
                    .foregroundStyle(VO1DStyle.secondary)
            }

            HStack(spacing: 12) {
                Image(systemName: "key.horizontal")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(.white.opacity(0.78))

                TextField("VOID-XXXX-XXXX-XXXX", text: $key)
                    .font(VO1DStyle.mono(13))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($keyFocused)
                    .submitLabel(.go)
                    .onSubmit {
                        guard keyReady else { return }
                        activate()
                    }
                    .onChange(of: key) { _, value in
                        key = formatKeyInput(value)
                    }
                    .accessibilityIdentifier("login.key")

                if !key.isEmpty {
                    Button {
                        key = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(VO1DStyle.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear key")
                }
            }
            .padding(.horizontal, 17)
            .frame(height: 58)
            .vo1dSurface(highlighted: keyFocused, radius: 17)

            PrimaryButton(
                title: model.isActivating ? "VERIFYING KEY…" : "ACTIVATE VO1D",
                icon: model.isActivating ? "ellipsis" : "arrow.right"
            ) {
                activate()
            }
            .disabled(model.isActivating || !keyReady)
            .opacity(model.isActivating || !keyReady ? 0.48 : 1)
            .accessibilityIdentifier("login.activate")

            if let error = model.errorMessage {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .padding(.top, 1)

                    Text(error)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.caption)
                .foregroundStyle(VO1DStyle.red)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .vo1dSurface(radius: 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var demoEntry: some View {
        VStack(spacing: 14) {
            PrimaryButton(
                title: model.isActivating ? "STARTING…" : "ENTER DEMO",
                icon: "play.fill"
            ) {
                Task { _ = await model.activate(key: "") }
            }
            .disabled(model.isActivating)

            Text("No key, payment, backend, or real VPN tunnel is used in Simulator.")
                .font(.caption)
                .foregroundStyle(VO1DStyle.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 11, weight: .light))

            Text(
                model.isDemoMode
                ? "PREVIEW MODE"
                : "KEY VALIDATION HAPPENS ON THE VO1D BACKEND"
            )
            .font(VO1DStyle.mono(8))
            .tracking(0.55)
        }
        .foregroundStyle(.white.opacity(0.34))
        .padding(.top, 4)
    }

    private var selectedPlanTitle: String {
        plans.first(where: { $0.days == selectedPlan })?.title ?? "ACCESS"
    }

    private var keyReady: Bool {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.uppercased().hasPrefix("VO1D1.") {
            return clean.count > 16
        }
        return clean.filter { $0.isLetter || $0.isNumber }.count == 16
    }

    private func activate() {
        guard keyReady, !model.isActivating else { return }
        keyFocused = false
        Task {
            _ = await model.activate(key: key)
        }
    }

    private func openPurchase(_ plan: AccessPlan) {
        var components = URLComponents(string: "https://t.me/vo1d_root")
        components?.queryItems = [
            URLQueryItem(
                name: "text",
                value: "Хочу купить VO1D_VPN: \\(plan.title), \\(plan.price). Нужен ключ для iPhone."
            )
        ]

        if let url = components?.url {
            openURL(url)
        }
    }

    private func formatKeyInput(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.uppercased().hasPrefix("VO1D1.") {
            return trimmed
        }

        var raw = trimmed
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
                offsetBy: min(4, raw.distance(from: index, to: raw.endIndex))
            )
            groups.append(String(raw[index..<end]))
            index = end
        }

        return "VOID-" + groups.joined(separator: "-")
    }
}

private struct AccessPlan: Identifiable {
    let days: Int
    let title: String
    let price: String
    let detail: String

    var id: Int { days }
}
