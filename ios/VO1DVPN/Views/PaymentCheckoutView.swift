import SafariServices
import SwiftUI

struct PaymentCheckoutView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.vo1dReduceMotion) private var reduceMotion

    let planDays: Int
    let planTitle: String
    let displayPrice: String

    @State private var stage: CheckoutStage = .methods
    @State private var payment: PaymentCreateResponse?
    @State private var browserURL: URL?
    @State private var showBrowser = false
    @State private var pollTask: Task<Void, Never>?
    @State private var glow = false

    var body: some View {
        ZStack {
            ReferenceBackdrop()

            ScrollView {
                VStack(spacing: 20) {
                    header
                    planSummary
                    stageContent
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
        .onDisappear {
            pollTask?.cancel()
            pollTask = nil
        }
        .fullScreenCover(isPresented: $showBrowser) {
            if let browserURL {
                CheckoutSafariView(url: browserURL)
                    .ignoresSafeArea()
            }
        }
        .accessibilityIdentifier("payment.checkout")
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("VO1D CHECKOUT")
                    .font(
                        .system(
                            size: 9,
                            weight: .medium,
                            design: .monospaced
                        )
                    )
                    .tracking(2.1)
                    .foregroundStyle(.white.opacity(0.42))

                Text("Secure payment")
                    .font(.system(size: 28, weight: .semibold))
                    .tracking(-0.7)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(width: 40, height: 40)
                    .background(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.10),
                                VO1DStyle.graphite.opacity(0.72),
                                .black.opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(
                                .white.opacity(0.16),
                                lineWidth: 0.8
                            )
                    }
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.92))
        }
    }

    private var planSummary: some View {
        ReferenceGlassCard(
            radius: 24,
            highlighted: true
        ) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .white.opacity(0.15),
                                    VO1DStyle.midnight.opacity(0.72),
                                    .black.opacity(0.95)
                                ],
                                center: UnitPoint(x: 0.36, y: 0.30),
                                startRadius: 0,
                                endRadius: 38
                            )
                        )
                        .frame(width: 66, height: 66)

                    Image(systemName: "lock.shield")
                        .font(.system(size: 23, weight: .light))
                        .foregroundStyle(.white.opacity(0.94))
                        .shadow(
                            color: VO1DStyle.frost.opacity(0.26),
                            radius: 8
                        )
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(planTitle.replacingOccurrences(of: "\n", with: " "))
                        .font(.system(size: 17, weight: .semibold))

                    Text("\(planDays) days of VO1D access")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.46))
                }

                Spacer()

                Text(displayPrice)
                    .font(
                        .system(
                            size: 19,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .monospacedDigit()
            }
            .padding(18)
        }
    }

    @ViewBuilder
    private var stageContent: some View {
        switch stage {
        case .methods:
            methods
                .transition(.opacity.combined(with: .scale(scale: 0.97)))

        case .creating:
            statusPanel(
                title: "Creating payment",
                subtitle: "Securing a fresh RollyPay session…",
                busy: true
            )

        case .waiting:
            waitingPanel

        case .success:
            successPanel

        case .failure(let message):
            failurePanel(message)
        }
    }

    private var methods: some View {
        VStack(spacing: 14) {
            VStack(spacing: 5) {
                Text("CHOOSE PAYMENT METHOD")
                    .font(
                        .system(
                            size: 9,
                            weight: .medium,
                            design: .monospaced
                        )
                    )
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.42))

                Text("No Telegram required")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.56))
            }
            .padding(.bottom, 2)

            methodButton(
                code: "sbp",
                icon: "qrcode",
                title: "СБП",
                subtitle: "Fast bank payment · RUB"
            )

            methodButton(
                code: "crypto",
                icon: "bitcoinsign.circle",
                title: "Crypto",
                subtitle: "Cryptocurrency through RollyPay"
            )

            methodButton(
                code: "xrocket",
                icon: "paperplane.circle",
                title: "xRocket",
                subtitle: "Opens the connected RollyPay PayForm"
            )

            Text(
                "The final amount is calculated in RUB by the server at checkout. "
                + "Your RollyPay credentials stay on the backend and are never stored on iPhone."
            )
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.30))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.top, 2)
        }
    }

    private func methodButton(
        code: String,
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        Button {
            startPayment(method: code)
        } label: {
            ReferenceGlassCard(radius: 20) {
                HStack(spacing: 15) {
                    ZStack {
                        RoundedRectangle(
                            cornerRadius: 15,
                            style: .continuous
                        )
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.12),
                                    VO1DStyle.midnight.opacity(0.62),
                                    .black.opacity(0.90)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: 15,
                                style: .continuous
                            )
                            .strokeBorder(
                                .white.opacity(0.12),
                                lineWidth: 0.7
                            )
                        }

                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(.white.opacity(0.92))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))

                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.42))
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                }
                .padding(14)
            }
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.975))
        .disabled(stage != .methods)
        .accessibilityIdentifier("payment.method.\(code)")
    }

    private var waitingPanel: some View {
        VStack(spacing: 18) {
            statusPanel(
                title: "Waiting for payment",
                subtitle:
                    payment.map {
                        "\($0.amountRub) ₽ · \(methodTitle($0.method))"
                    } ?? "Complete payment in the secure checkout.",
                busy: true
            )

            if let payment {
                ReferenceGlassCard(radius: 20) {
                    VStack(spacing: 13) {
                        HStack {
                            Text("PAYMENT")
                                .font(
                                    .system(
                                        size: 9,
                                        weight: .medium,
                                        design: .monospaced
                                    )
                                )
                                .tracking(1.4)
                                .foregroundStyle(.white.opacity(0.38))

                            Spacer()

                            Text(payment.status.uppercased())
                                .font(
                                    .system(
                                        size: 9,
                                        weight: .semibold,
                                        design: .monospaced
                                    )
                                )
                                .tracking(1.1)
                                .foregroundStyle(.white.opacity(0.70))
                        }

                        Divider()
                            .overlay(.white.opacity(0.07))

                        HStack {
                            Text(payment.amountRub + " ₽")
                                .font(
                                    .system(
                                        size: 24,
                                        weight: .semibold,
                                        design: .rounded
                                    )
                                )
                                .monospacedDigit()

                            Spacer()

                            Text("\(payment.planDays) DAYS")
                                .font(
                                    .system(
                                        size: 9,
                                        weight: .medium,
                                        design: .monospaced
                                    )
                                )
                                .tracking(1.3)
                                .foregroundStyle(.white.opacity(0.42))
                        }
                    }
                    .padding(18)
                }

                ReferencePrimaryButton(
                    title: "Open Payment",
                    icon: "arrow.up.right"
                ) {
                    reopenPayment()
                }
            }

            Text("VO1D checks payment status automatically.")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.30))
        }
    }

    private func statusPanel(
        title: String,
        subtitle: String,
        busy: Bool
    ) -> some View {
        ReferenceGlassCard(
            radius: 26,
            highlighted: busy
        ) {
            VStack(spacing: 16) {
                ZStack {
                    ReferenceVortex(
                        active: false,
                        busy: busy
                    )
                    .frame(width: 116, height: 116)
                    .clipShape(Circle())

                    Circle()
                        .fill(.black.opacity(0.72))
                        .frame(width: 48, height: 48)
                        .overlay {
                            if busy {
                                ProgressView()
                                    .tint(.white.opacity(0.88))
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }
                }

                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.46))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 18)
        }
    }

    private var successPanel: some View {
        ReferenceGlassCard(
            radius: 28,
            highlighted: true
        ) {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(
                            VO1DStyle.frost.opacity(0.30),
                            lineWidth: 1
                        )
                        .frame(width: 112, height: 112)
                        .scaleEffect(glow ? 1.22 : 0.90)
                        .opacity(glow ? 0 : 1)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .white.opacity(0.18),
                                    VO1DStyle.midnight.opacity(0.74),
                                    .black.opacity(0.94)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 48
                            )
                        )
                        .frame(width: 84, height: 84)

                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text("Subscription Active")
                    .font(.system(size: 23, weight: .semibold))

                Text("Access is linked directly to this iPhone.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.46))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 34)
        }
        .onAppear {
            guard !reduceMotion else { return }

            withAnimation(
                .easeOut(duration: 0.75)
            ) {
                glow = true
            }
        }
    }

    private func failurePanel(_ message: String) -> some View {
        VStack(spacing: 16) {
            ReferenceGlassCard(radius: 24) {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.white.opacity(0.80))

                    Text("Payment unavailable")
                        .font(.system(size: 19, weight: .semibold))

                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.46))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            }

            ReferencePrimaryButton(
                title: "Try Again",
                icon: "arrow.clockwise"
            ) {
                withAnimation(.easeOut(duration: 0.22)) {
                    stage = .methods
                }
            }
        }
    }

    private func startPayment(method: String) {
        Haptics.play(
            .selection,
            enabled: model.preferences.haptics
        )

        withAnimation(.easeOut(duration: 0.22)) {
            stage = .creating
        }

        Task {
            do {
                let created = try await model.createPayment(
                    planDays: planDays,
                    method: method
                )

                payment = created
                if let url = URL(string: created.payUrl) {
                    browserURL = url
                    showBrowser = true
                }

                withAnimation(.easeOut(duration: 0.24)) {
                    stage = .waiting
                }

                beginPolling(
                    orderID: created.orderId,
                    pollToken: created.pollToken
                )
            } catch {
                withAnimation(.easeOut(duration: 0.22)) {
                    stage = .failure(error.localizedDescription)
                }
                Haptics.play(
                    .error,
                    enabled: model.preferences.haptics
                )
            }
        }
    }

    private func reopenPayment() {
        guard let payment,
              let url = URL(string: payment.payUrl)
        else { return }

        browserURL = url
        showBrowser = true
    }

    private func beginPolling(
        orderID: String,
        pollToken: String
    ) {
        pollTask?.cancel()

        pollTask = Task {
            var transientErrors = 0

            for _ in 0..<450 {
                if Task.isCancelled { return }

                do {
                    try await Task.sleep(for: .seconds(2))
                } catch {
                    return
                }

                do {
                    let response = try await model.paymentStatus(
                        orderID: orderID,
                        pollToken: pollToken
                    )
                    transientErrors = 0

                    if response.status == "paid" {
                        let activated =
                            await model.finishPurchasedPayment(response)

                        guard activated else { continue }

                        showBrowser = false
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                            stage = .success
                        }

                        try? await Task.sleep(for: .milliseconds(1100))
                        dismiss()
                        return
                    }

                    if [
                        "expired",
                        "canceled",
                        "refunded",
                        "chargeback",
                        "error"
                    ].contains(response.status) {
                        showBrowser = false
                        withAnimation(.easeOut(duration: 0.22)) {
                            stage = .failure(
                                "Payment status: \(response.status)."
                            )
                        }
                        return
                    }
                } catch {
                    transientErrors += 1

                    if transientErrors >= 8 {
                        withAnimation(.easeOut(duration: 0.22)) {
                            stage = .failure(
                                "Could not verify payment yet. "
                                + "You can retry without creating another charge."
                            )
                        }
                        return
                    }
                }
            }
        }
    }

    private func methodTitle(_ code: String) -> String {
        switch code {
        case "sbp":
            return "СБП"
        case "crypto":
            return "Crypto"
        case "xrocket":
            return "xRocket"
        default:
            return code
        }
    }
}

private enum CheckoutStage: Equatable {
    case methods
    case creating
    case waiting
    case success
    case failure(String)
}

private struct CheckoutSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(
        context: Context
    ) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredBarTintColor = .black
        controller.preferredControlTintColor = .white
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(
        _ uiViewController: SFSafariViewController,
        context: Context
    ) {}
}
