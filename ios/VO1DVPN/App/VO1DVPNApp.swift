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
    private var motionReduced: Bool { systemReduceMotion || preferences.reduceAnimations }
    private var showSplash: Bool { !splashFinished }

    var body: some View {
        ZStack {
            VO1DStyle.background.ignoresSafeArea()
            Group {
                if model.sessionToken == nil { LoginView() }
                else { AppShell() }
            }
            .opacity(showSplash ? 0 : 1)
            .scaleEffect(showSplash && !motionReduced ? 0.98 : 1)
            .allowsHitTesting(!showSplash)
            .accessibilityHidden(showSplash)
            if showSplash {
                LaunchScreenView { splashFinished = true }
                    .transition(.opacity).zIndex(2)
            }
        }
        .environment(\.vo1dReduceMotion, motionReduced)
        .animation(motionReduced ? nil : .easeOut(duration: 0.32), value: showSplash)
        .task { await model.bootstrap() }
        .onChange(of: scenePhase) { _, phase in model.setForeground(phase == .active) }
        .alert("Connection notice", isPresented: Binding(get: { model.errorMessage != nil && model.sessionToken != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}
