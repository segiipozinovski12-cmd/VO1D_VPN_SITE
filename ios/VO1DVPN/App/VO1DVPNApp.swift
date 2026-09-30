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
        }
        .environment(\.vo1dReduceMotion, motionReduced)
        .animation(motionReduced ? nil : .easeOut(duration: 0.38), value: splashFinished)
        .task {
            await model.bootstrap()
        }
        .onChange(of: scenePhase) { _, phase in
            model.setForeground(phase == .active)
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
