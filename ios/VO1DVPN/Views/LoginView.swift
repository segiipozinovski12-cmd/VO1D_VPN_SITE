import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.vo1dReduceMotion) private var reduceMotion

    @State private var key = ""
    @State private var selectedPlan = 30
    @State private var appeared = false
    @FocusState private var keyFocused: Bool

    private let plans = [
        AccessPlan(days: 30, title: "1\nMonth", price: "$1.99", detail: "30 days", discount: nil),
        AccessPlan(days: 90, title: "3\nMonths", price: "$4.99", detail: "90 days", discount: nil),
        AccessPlan(days: 180, title: "6\nMonths", price: "$8.99", detail: "180 days", discount: "-25%"),
        AccessPlan(days: 365, title: "1\nYear", price: "$14.99", detail: "365 days", discount: "-37%")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                    .padding(.top, 4)

                VStack(spacing: 22) {
                    heading
                    planRow
                    benefits
                    subscriptionButton
                    divider
                    keyEntry
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 34)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background { ReferenceBackdrop() }
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.48)) {
                    appeared = true
                }
            }
        }
        .accessibilityIdentifier("login.screen")
    }

    private var hero: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 10) {
                VO1DBrandLockup(compact: true)

                HStack(spacing: 10) {
                    Circle()
                        .fill(.white.opacity(0.75))
                        .frame(width: 3, height: 3)

                    Rectangle()
                        .fill(.white.opacity(0.16))
                        .frame(width: 34, height: 0.8)

                    Text("PRIVATE ACCESS")
                        .font(
                            .system(
                                size: 8,
                                weight: .medium,
                                design: .monospaced
                            )
                        )
                        .tracking(2.0)
                        .foregroundStyle(.white.opacity(0.42))

                    Rectangle()
                        .fill(.white.opacity(0.16))
                        .frame(width: 34, height: 0.8)

                    Circle()
                        .fill(.white.opacity(0.75))
                        .frame(width: 3, height: 3)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 22)
            .opacity(appeared ? 1 : 0)

            Button {
                keyFocused = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.white.opacity(0.84))
                    .background(
                        .ultraThinMaterial,
                        in: Circle()
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.30),
                                        .white.opacity(0.07)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.9
                            )
                    )
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.94))
            .padding(.top, 12)
            .padding(.trailing, 18)
            .accessibilityLabel("Jump to key entry")
        }
        .frame(height: 112)
    }

    private var heading: some View {
        VStack(spacing: 6) {
            Text("Choose Your Plan")
                .font(.system(size: 24, weight: .semibold))
                .tracking(-0.4)

            Text("Private. Secure. Borderless.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.white.opacity(0.44))
        }
        .padding(.top, 2)
        .opacity(appeared ? 1 : 0)
    }

    private var planRow: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(plans) { plan in
                planCard(plan)
            }
        }
        .opacity(appeared ? 1 : 0)
    }

    private func planCard(_ plan: AccessPlan) -> some View {
        let selected = selectedPlan == plan.days

        return Button {
            selectedPlan = plan.days
            Haptics.play(.selection, enabled: model.preferences.haptics)
        } label: {
            ZStack(alignment: .topTrailing) {
                ReferenceGlassCard(
                    radius: 15,
                    highlighted: selected
                ) {
                    VStack(spacing: 12) {
                        Text(plan.title)
                            .font(.system(size: 11, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.90))
                            .lineSpacing(-1)

                        Spacer(minLength: 0)

                        Text(plan.price)
                            .font(.system(size: 16, weight: .semibold))
                            .monospacedDigit()
                            .minimumScaleFactor(0.72)

                        Text(plan.detail)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.40))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .frame(height: 142)
                }

                if let discount = plan.discount {
                    Text(discount)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(.white, in: Capsule())
                        .offset(x: 5, y: -8)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.975))
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("plan.\(plan.days)")
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefit("bolt.horizontal.fill", "High speed worldwide servers")
            benefit("eye.slash", "No logs. No tracking.")
            benefit("circle", "Stable and secure connection")
            benefit("point.3.connected.trianglepath.dotted", "Access to all locations")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }

    private func benefit(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .light))
                .frame(width: 20)
                .foregroundStyle(.white.opacity(0.74))

            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.66))

            Spacer()
        }
    }

    private var subscriptionButton: some View {
        ReferencePrimaryButton(
            title: "Get Subscription",
            icon: "chevron.right"
        ) {
            Haptics.play(.selection, enabled: model.preferences.haptics)

            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) {
                keyFocused = true
            }
        }
        .accessibilityIdentifier("subscription.primary")
    }

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(height: 1)

            Text("or")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.44))

            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(height: 1)
        }
        .padding(.horizontal, 22)
    }

    private var keyEntry: some View {
        VStack(spacing: 13) {
            Text("Have a key? Enter it below")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.42))

            HStack(spacing: 12) {
                TextField("VOID-XXXX-XXXX-XXXX", text: $key)
                    .font(.system(size: 14, weight: .medium))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($keyFocused)
                    .submitLabel(.go)
                    .onSubmit {
                        guard keyReady else { return }
                        activate()
                    }
                    .onChange(of: key) { _, value in
                        let formatted = formatKeyInput(value)

                        if formatted != key {
                            key = formatted
                        }

                        if let license = AccessKeyVault.license(for: formatted) {
                            selectedPlan = license.days
                        }
                    }
                    .accessibilityIdentifier("login.key")

                Button {
                    activate()
                } label: {
                    Image(systemName: model.isActivating ? "ellipsis" : "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .foregroundStyle(.white.opacity(keyReady ? 0.92 : 0.22))
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.92))
                .disabled(!keyReady || model.isActivating)
                .accessibilityIdentifier("login.activate")
            }
            .padding(.horizontal, 18)
            .frame(height: 58)
            .background {
                Capsule()
                    .fill(Color.white.opacity(0.028))
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(keyFocused ? 0.34 : 0.13),
                                .white.opacity(0.045)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
            }

            if model.isDemoMode {
                Button("Enter Simulator Demo") {
                    Task { _ = await model.activate(key: "") }
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.42))
                .padding(.top, 4)
            }

            if let error = model.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(VO1DStyle.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .transition(.opacity)
            }
        }
    }

    private var keyReady: Bool {
        AccessKeyVault.license(for: key) != nil
    }

    private func activate() {
        guard keyReady, !model.isActivating else { return }
        keyFocused = false

        Task {
            _ = await model.activate(key: key)
        }
    }

    private func formatKeyInput(_ input: String) -> String {
        var raw = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

private struct AccessPlan: Identifiable {
    let days: Int
    let title: String
    let price: String
    let detail: String
    let discount: String?

    var id: Int { days }
}
