import SwiftUI

@main
struct VO1DVPNApp: App {
    @StateObject private var model = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(model.preferences)
                .environmentObject(model.pings)
                .environmentObject(model.session)
                .preferredColorScheme(.dark)
                .tint(.white)
        }
    }
}

private struct RootView: View {
    @EnvironmentObject private var model: AppViewModel
    @EnvironmentObject private var preferences: Preferences
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var splashFinished = false
    @State private var showActivationSuccess = false
    @State private var activationSequence = UUID()

    private var motionReduced: Bool {
        systemReduceMotion || preferences.reduceAnimations
    }

    var body: some View {
        ZStack {
            DeepSpaceBackdrop().ignoresSafeArea()

            if splashFinished {
                Group {
                    if model.sessionToken == nil {
                        LoginView()
                    } else {
                        AppShell()
                    }
                }
                .transition(
                    motionReduced
                    ? .opacity
                    : .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.985)),
                        removal: .opacity
                    )
                )
                .zIndex(1)
            } else {
                LaunchScreenView {
                    withAnimation(motionReduced ? nil : .easeOut(duration: 0.42)) {
                        splashFinished = true
                    }
                }
                .transition(
                    motionReduced
                    ? .opacity
                    : .opacity.combined(with: .scale(scale: 1.012))
                )
                .zIndex(2)
            }

            if showActivationSuccess {
                ActivationSuccessOverlay()
                    .transition(
                        motionReduced
                        ? .opacity
                        : .opacity.combined(with: .scale(scale: 1.018))
                    )
                    .zIndex(3)
            }
        }
        .environment(\.vo1dReduceMotion, motionReduced)
        .animation(motionReduced ? nil : .easeOut(duration: 0.38), value: splashFinished)
        .task {
            await model.bootstrap()
        }
        .onChange(of: scenePhase) { _, phase in
            model.setForeground(phase == .active)
        }
        .onChange(of: model.sessionToken) { oldValue, newValue in
            guard oldValue == nil,
                  newValue != nil,
                  splashFinished,
                  !model.isDemoMode else { return }

            let sequence = UUID()
            activationSequence = sequence

            withAnimation(
                motionReduced
                ? nil
                : .easeOut(duration: 0.24)
            ) {
                showActivationSuccess = true
            }

            Task {
                try? await Task.sleep(for: .milliseconds(2_150))
                guard activationSequence == sequence else { return }

                withAnimation(
                    motionReduced
                    ? nil
                    : .easeInOut(duration: 0.46)
                ) {
                    showActivationSuccess = false
                }
            }
        }
        .alert(
            "Connection notice",
            isPresented: Binding(
                get: { model.errorMessage != nil && model.sessionToken != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK") {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}


private struct ActivationSuccessOverlay: View {
    @Environment(\.vo1dReduceMotion) private var reduceMotion

    @State private var step = 0
    @State private var progress: CGFloat = 0.12
    @State private var reveal = false
    @State private var ring = false
    @State private var sweep = false

    private let steps = [
        "Verifying key",
        "Activating plan",
        "Configuring servers",
        "Setting up secure tunnel",
        "Almost ready..."
    ]

    var body: some View {
        ZStack {
            ReferenceBackdrop()

            ReferenceVortexView(
                connected: true,
                busy: true
            )
            .frame(width: 560, height: 560)
            .rotationEffect(.degrees(-10))
            .opacity(0.68)
            .offset(y: 180)

            LinearGradient(
                colors: [
                    .black.opacity(0.10),
                    .black.opacity(0.32),
                    .black.opacity(0.74)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 70)

                VStack(spacing: 4) {
                    Text("VO1D_VPN")
                        .font(
                            .system(
                                size: 25,
                                weight: .black,
                                design: .monospaced
                            )
                        )
                        .tracking(1.2)

                    Text("ZERO LOGS")
                        .font(VO1DStyle.mono(7))
                        .tracking(4)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .opacity(reveal ? 1 : 0)

                Spacer()

                ReferenceGlassPanel(
                    radius: 30,
                    highlighted: false
                ) {
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .stroke(
                                    .white.opacity(0.10),
                                    lineWidth: 1
                                )
                                .frame(width: 94, height: 94)

                            Circle()
                                .trim(
                                    from: 0.04,
                                    to: ring ? 1 : 0.04
                                )
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.12),
                                            .white,
                                            .white.opacity(0.20)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(
                                        lineWidth: 1.6,
                                        lineCap: .round
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                                .shadow(
                                    color: .white.opacity(0.24),
                                    radius: 10
                                )

                            Image(systemName: "checkmark")
                                .font(
                                    .system(
                                        size: 31,
                                        weight: .medium
                                    )
                                )
                                .foregroundStyle(.white)
                                .scaleEffect(
                                    reveal || reduceMotion
                                    ? 1
                                    : 0.82
                                )
                        }

                        VStack(spacing: 7) {
                            Text("Key Accepted")
                                .font(.system(size: 23, weight: .semibold))

                            Text("Activating your subscription...")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.50))
                        }

                        VStack(spacing: 14) {
                            ForEach(
                                Array(steps.enumerated()),
                                id: \.offset
                            ) { index, label in
                                HStack(spacing: 11) {
                                    ZStack {
                                        Circle()
                                            .stroke(
                                                .white.opacity(
                                                    index <= step
                                                    ? 0.65
                                                    : 0.18
                                                ),
                                                lineWidth: 1
                                            )
                                            .frame(width: 22, height: 22)

                                        if index < step {
                                            Image(systemName: "checkmark")
                                                .font(
                                                    .system(
                                                        size: 9,
                                                        weight: .bold
                                                    )
                                                )
                                                .foregroundStyle(.black)
                                                .frame(
                                                    width: 18,
                                                    height: 18
                                                )
                                                .background(
                                                    .white,
                                                    in: Circle()
                                                )
                                        } else if index == step {
                                            Circle()
                                                .fill(.white)
                                                .frame(width: 5, height: 5)
                                                .shadow(
                                                    color: .white.opacity(0.5),
                                                    radius: 4
                                                )
                                        }
                                    }

                                    Text(label)
                                        .font(.system(size: 13))
                                        .foregroundStyle(
                                            index <= step
                                            ? .white.opacity(0.82)
                                            : .white.opacity(0.34)
                                        )

                                    Spacer()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)

                        HStack(spacing: 12) {
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(.white.opacity(0.12))

                                    Capsule()
                                        .fill(.white)
                                        .frame(
                                            width:
                                                max(
                                                    10,
                                                    proxy.size.width * progress
                                                )
                                        )
                                        .shadow(
                                            color: .white.opacity(0.35),
                                            radius: 5
                                        )
                                }
                            }
                            .frame(height: 4)

                            Text("\(Int(progress * 100))%")
                                .font(VO1DStyle.mono(9))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.72))
                                .frame(width: 34, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 30)
                }
                .frame(maxWidth: 330)
                .opacity(reveal ? 1 : 0)
                .offset(y: reveal || reduceMotion ? 0 : 14)

                Spacer()
            }

            LinearGradient(
                colors: [
                    .clear,
                    .white.opacity(0.10),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 120, height: 520)
            .rotationEffect(.degrees(-20))
            .offset(x: sweep ? 380 : -380)
            .blur(radius: 16)
            .opacity(reduceMotion ? 0 : 0.55)
            .allowsHitTesting(false)
        }
        .onAppear {
            if reduceMotion {
                reveal = true
                ring = true
                step = 4
                progress = 1
                return
            }

            withAnimation(.easeOut(duration: 0.38)) {
                reveal = true
            }

            withAnimation(.easeOut(duration: 0.72)) {
                ring = true
            }

            withAnimation(.linear(duration: 1.7)) {
                sweep = true
            }

            Task {
                let targets: [CGFloat] = [0.22, 0.40, 0.59, 0.82, 1.0]

                for index in 0..<targets.count {
                    try? await Task.sleep(
                        for: .milliseconds(index == 0 ? 180 : 300)
                    )

                    withAnimation(.easeInOut(duration: 0.30)) {
                        step = index
                        progress = targets[index]
                    }
                }
            }
        }
        .accessibilityIdentifier("activation.success")
    }
}
