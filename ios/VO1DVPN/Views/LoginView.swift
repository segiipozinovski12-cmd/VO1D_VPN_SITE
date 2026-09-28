import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.vo1dReduceMotion) private var reduceMotion

    @State private var key = ""
    @State private var selectedPlan = 30
    @State private var reveal = false
    @FocusState private var keyFocused: Bool

    private let plans = [
        AccessPlan(days: 30, title: "1\nMonth", price: "$1.99", detail: "30 days", badge: nil),
        AccessPlan(days: 90, title: "3\nMonths", price: "$4.99", detail: "90 days", badge: nil),
        AccessPlan(days: 180, title: "6\nMonths", price: "$8.99", detail: "180 days", badge: "-25%"),
        AccessPlan(days: 365, title: "1\nYear", price: "$14.99", detail: "365 days", badge: "-37%")
    ]

    var body: some View {
        ZStack {
            ReferenceBackdrop()

            VStack(spacing: 0) {
                planetHeader
                    .frame(height: 210)

                ScrollView {
                    VStack(spacing: 22) {
                        titleBlock
                        planRow
                        featureList
                        getSubscriptionButton
                        divider
                        keyBlock
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onAppear {
            if reduceMotion {
                reveal = true
            } else {
                withAnimation(.easeOut(duration: 0.5)) {
                    reveal = true
                }
            }
        }
        .accessibilityIdentifier("login.screen")
    }

    private var planetHeader: some View {
        ZStack(alignment: .topTrailing) {
            ReferencePlanetView(compact: true)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipped()

            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.18),
                    .black
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Button {
                keyFocused = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.40), in: Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                    )
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.94))
            .padding(.top, 16)
            .padding(.trailing, 16)

            VStack(spacing: 5) {
                Spacer()

                Text("VO1D_VPN")
                    .font(
                        .system(
                            size: 27,
                            weight: .black,
                            design: .monospaced
                        )
                    )
                    .tracking(1.4)

                Text("ZERO LOGS")
                    .font(VO1DStyle.mono(8))
                    .tracking(4.5)
                    .foregroundStyle(.white.opacity(0.62))
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 10)
        }
        .opacity(reveal ? 1 : 0)
    }

    private var titleBlock: some View {
        VStack(spacing: 7) {
            Text("Choose Your Plan")
                .font(.system(size: 25, weight: .semibold))

            Text("Private. Secure. Borderless.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.48))
        }
        .opacity(reveal ? 1 : 0)
        .offset(y: reveal || reduceMotion ? 0 : 8)
    }

    private var planRow: some View {
        HStack(spacing: 7) {
            ForEach(plans) { plan in
                planCard(plan)
            }
        }
    }

    private func planCard(_ plan: AccessPlan) -> some View {
        let selected = selectedPlan == plan.days

        return Button {
            selectedPlan = plan.days
            Haptics.play(.selection, enabled: model.preferences.haptics)
        } label: {
            ZStack(alignment: .topTrailing) {
                ReferenceGlassPanel(
                    radius: 17,
                    highlighted: selected
                ) {
                    VStack(spacing: 14) {
                        Text(plan.title)
                            .font(.system(size: 11, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.88))

                        Spacer(minLength: 1)

                        Text(plan.price)
                            .font(.system(size: 16, weight: .semibold))
                            .minimumScaleFactor(0.76)
                            .lineLimit(1)

                        Text(plan.detail)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.40))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 114)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 5)
                }

                if let badge = plan.badge {
                    Text(badge)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.86), in: Capsule())
                        .offset(x: 3, y: -7)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.96))
        .accessibilityIdentifier("plan.\(plan.days)")
    }

    private var featureList: some View {
        VStack(spacing: 13) {
            feature("network", "High speed worldwide servers")
            feature("eye.slash", "No logs. No tracking.")
            feature("circle", "Stable and secure connection")
            feature("location", "Access to all locations")
        }
        .padding(.horizontal, 6)
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 18)

            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.66))

            Spacer()
        }
    }

    private var getSubscriptionButton: some View {
        ReferencePrimaryButton(
            title: "Get Subscription"
        ) {
            withAnimation(.easeOut(duration: 0.24)) {
                keyFocused = true
            }
        }
        .accessibilityIdentifier("subscription.cta")
    }

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(height: 1)

            Text("or")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.42))

            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(height: 1)
        }
    }

    private var keyBlock: some View {
        VStack(spacing: 12) {
            Text("Have a key? Enter it below")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.42))

            HStack(spacing: 11) {
                TextField("VOID-XXXX-XXXX-XXXX", text: $key)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($keyFocused)
                    .submitLabel(.go)
                    .onSubmit {
                        if keyReady {
                            activate()
                        }
                    }
                    .onChange(of: key) { _, newValue in
                        let formatted = formatKeyInput(newValue)
                        if formatted != key {
                            key = formatted
                        }

                        if let license = AccessKeyVault.license(for: formatted) {
                            selectedPlan = license.days
                        }
                    }
                    .accessibilityIdentifier("login.key")

                Button {
                    if keyReady {
                        activate()
                    } else {
                        keyFocused = true
                    }
                } label: {
                    Image(
                        systemName:
                            model.isActivating
                            ? "ellipsis"
                            : "chevron.right"
                    )
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.92))
                .disabled(model.isActivating)
            }
            .padding(.horizontal, 18)
            .frame(height: 58)
            .background(
                Color.black.opacity(0.35),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(
                                    keyFocused ? 0.42 : 0.16
                                ),
                                .white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }

            if let license = AccessKeyVault.license(for: key) {
                Text(
                    "VALID KEY · \(planLabel(license.days)) · \(license.days) DAYS"
                )
                .font(VO1DStyle.mono(8))
                .tracking(0.55)
                .foregroundStyle(.white.opacity(0.62))
                .transition(.opacity)
            }

            if let error = model.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(VO1DStyle.red)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            if model.isDemoMode {
                Button("ENTER DEMO") {
                    Task {
                        _ = await model.activate(key: "")
                    }
                }
                .font(VO1DStyle.mono(9))
                .foregroundStyle(.white.opacity(0.52))
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

    private func planLabel(_ days: Int) -> String {
        switch days {
        case 30: return "1 MONTH"
        case 90: return "3 MONTHS"
        case 180: return "6 MONTHS"
        case 365: return "1 YEAR"
        default: return "\(days) DAYS"
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
                offsetBy:
                    min(
                        4,
                        raw.distance(
                            from: index,
                            to: raw.endIndex
                        )
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
    let badge: String?

    var id: Int { days }
}
