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
                try? await Task.sleep(for: .milliseconds(1_250))
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

    @State private var ring = false
    @State private var reveal = false
    @State private var sweep = false

    var body: some View {
        ZStack {
            DeepSpaceBackdrop()
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    VO1DStyle.frost.opacity(reveal ? 0.055 : 0.012),
                    .clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 310
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    .clear,
                    .white.opacity(0.055),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 90)
            .offset(y: sweep ? 520 : -520)
            .blur(radius: 18)
            .opacity(reduceMotion ? 0 : 1)

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                        .frame(width: 142, height: 142)

                    Circle()
                        .trim(from: 0.03, to: ring ? 1 : 0.03)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.18),
                                    VO1DStyle.pearl,
                                    .white.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(
                                lineWidth: 1.4,
                                lineCap: .round
                            )
                        )
                        .frame(width: 122, height: 122)
                        .rotationEffect(.degrees(-90))

                    Color.clear
                        .frame(width: 86, height: 86)
                        .vo1dSystemGlass(
                            in: RoundedRectangle(
                                cornerRadius: 29,
                                style: .continuous
                            )
                        )

                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 35, weight: .light))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(VO1DStyle.pearl)
                        .scaleEffect(reveal || reduceMotion ? 1 : 0.82)
                        .opacity(reveal ? 1 : 0)
                }

                VStack(spacing: 10) {
                    Text("KEY ACCEPTED")
                        .font(
                            .system(
                                size: 25,
                                weight: .semibold,
                                design: .monospaced
                            )
                        )
                        .tracking(1.6)

                    Text("ACCESS GRANTED")
                        .font(VO1DStyle.mono(9))
                        .tracking(2.5)
                        .foregroundStyle(VO1DStyle.pearl)

                    Text("Preparing your private network")
                        .font(.subheadline)
                        .foregroundStyle(VO1DStyle.secondary)
                        .padding(.top, 5)
                }
                .opacity(reveal ? 1 : 0)
                .offset(y: reveal || reduceMotion ? 0 : 8)

                Spacer()

                HStack(spacing: 7) {
                    Circle()
                        .fill(VO1DStyle.pearl)
                        .frame(width: 5, height: 5)

                    Text("SESSION VERIFIED")
                        .font(VO1DStyle.mono(8))
                        .tracking(1.5)
                }
                .foregroundStyle(VO1DStyle.pearl)
                .padding(.bottom, 34)
                .opacity(reveal ? 1 : 0)
            }
        }
        .onAppear {
            if reduceMotion {
                ring = true
                reveal = true
                return
            }

            withAnimation(.easeOut(duration: 0.54)) {
                ring = true
            }

            withAnimation(.easeOut(duration: 0.32).delay(0.12)) {
                reveal = true
            }

            withAnimation(.linear(duration: 0.85)) {
                sweep = true
            }
        }
        .accessibilityIdentifier("activation.success")
    }
}
