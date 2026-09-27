import SwiftUI

@main
struct VO1DVPNApp: App {
    @StateObject private var model = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .task { await model.bootstrap() }
        }
    }
}

private struct RootView: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if model.sessionToken == nil {
                LoginView()
            } else {
                HomeView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: model.sessionToken != nil)
    }
}
