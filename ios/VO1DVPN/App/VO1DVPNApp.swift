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
                try? await Task.sleep(for: .milliseconds(2_850))
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

    @State private var appeared = false
    @State private var step = 0
    @State private var progress: CGFloat = 0.08
    @State private var rotate = false
    @State private var sweep = false

    private let stages = [
        "Verifying key",
        "Activating plan",
        "Configuring servers",
        "Setting up secure tunnel",
        "Almost ready..."
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ReferenceBackdrop()

                ReferencePlanet(
                    diameter: min(proxy.size.width * 1.28, 530),
                    rotation: -11,
                    glow: 0.11
                )
                .offset(x: -proxy.size.width * 0.18, y: proxy.size.height * 0.32)
                .opacity(0.34)

                ReferenceVortex(active: true, busy: true)
                    .frame(width: 360, height: 360)
                    .rotationEffect(.degrees(rotate ? 360 : 0))
                    .offset(y: proxy.size.height * 0.20)
                    .opacity(0.74)

                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.055),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .offset(y: sweep ? proxy.size.height * 0.55 : -proxy.size.height * 0.45)
                .blur(radius: 22)
                .opacity(reduceMotion ? 0 : 1)

                VStack(spacing: 0) {
                    VO1DBrandLockup(compact: true)
                        .padding(.top, 28)
                        .opacity(appeared ? 1 : 0)

                    Spacer()

                    ReferenceGlassCard(radius: 30, highlighted: true) {
                        VStack(spacing: 22) {
                            acceptedIcon

                            VStack(spacing: 7) {
                                Text("Key Accepted")
                                    .font(.system(size: 23, weight: .semibold))
                                    .tracking(-0.25)

                                Text("Activating your subscription...")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.47))
                            }

                            VStack(alignment: .leading, spacing: 15) {
                                ForEach(Array(stages.enumerated()), id: \.offset) { index, title in
                                    activationRow(index: index, title: title)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 12) {
                                GeometryReader { bar in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(.white.opacity(0.12))
                                            .frame(height: 4)

                                        Capsule()
                                            .fill(.white)
                                            .frame(
                                                width: max(
                                                    8,
                                                    bar.size.width * progress
                                                ),
                                                height: 4
                                            )
                                            .shadow(color: .white.opacity(0.52), radius: 6)
                                    }
                                }
                                .frame(height: 4)

                                Text("\(Int(progress * 100))%")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .monospacedDigit()
                                    .foregroundStyle(.white.opacity(0.76))
                                    .frame(width: 34, alignment: .trailing)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 28)
                    }
                    .padding(.horizontal, 26)
                    .frame(maxWidth: 430)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.965)

                    Spacer()
                }
            }
        }
        .task { await run() }
        .accessibilityIdentifier("activation.success")
    }

    private var acceptedIcon: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.11), lineWidth: 1)
                .frame(width: 88, height: 88)

            Circle()
                .trim(from: 0.02, to: 0.33)
                .stroke(
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.95),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(
                        lineWidth: 2.0,
                        lineCap: .round
                    )
                )
                .frame(width: 78, height: 78)
                .rotationEffect(.degrees(rotate ? 360 : 0))
                .shadow(color: .white.opacity(0.42), radius: 6)

            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 62, height: 62)
                .background(.ultraThinMaterial, in: Circle())

            Image(systemName: "checkmark")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(.white)
        }
        .shadow(color: .white.opacity(0.20), radius: 14)
    }

    private func activationRow(index: Int, title: String) -> some View {
        let done = index < step
        let active = index == step

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(
                        .white.opacity(done || active ? 0.48 : 0.18),
                        lineWidth: 1
                    )
                    .frame(width: 21, height: 21)

                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 17, height: 17)
                        .background(.white, in: Circle())
                } else if active {
                    Circle()
                        .fill(.white)
                        .frame(width: 5, height: 5)
                        .shadow(color: .white.opacity(0.7), radius: 4)
                }
            }

            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(
                    done || active
                    ? .white.opacity(0.82)
                    : .white.opacity(0.34)
                )

            Spacer()
        }
    }

    @MainActor
    private func run() async {
        if reduceMotion {
            appeared = true
            step = 4
            progress = 1
            return
        }

        withAnimation(.easeOut(duration: 0.36)) {
            appeared = true
        }

        withAnimation(
            .linear(duration: 4.6)
            .repeatForever(autoreverses: false)
        ) {
            rotate = true
        }

        withAnimation(.linear(duration: 1.35)) {
            sweep = true
        }

        let marks: [(Int, CGFloat)] = [
            (0, 0.18),
            (1, 0.36),
            (2, 0.57),
            (3, 0.78),
            (4, 0.92)
        ]

        for item in marks {
            withAnimation(.snappy(duration: 0.26)) {
                step = item.0
                progress = item.1
            }

            try? await Task.sleep(for: .milliseconds(430))
        }

        withAnimation(.easeOut(duration: 0.34)) {
            progress = 1
        }
    }
}
