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
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                if model.sessionToken == nil {
                    LoginView()
                } else {
                    HomeView()
                }
            }
            .opacity(showSplash ? 0 : 1)

            if showSplash {
                LaunchScreenView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: model.sessionToken != nil)
        .task {
            try? await Task.sleep(for: .milliseconds(1500))
            withAnimation(.easeOut(duration: 0.38)) {
                showSplash = false
            }
        }
    }
}

private struct LaunchScreenView: View {
    @State private var progress = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("VO1D_VPN")
                    .font(.system(size: 35, weight: .black, design: .monospaced))
                    .tracking(2.6)
                    .foregroundStyle(.white)

                Text("SECURE CONNECTION")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(3.1)
                    .foregroundStyle(.white.opacity(0.48))
                    .padding(.top, 14)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.16))
                        .frame(width: 132, height: 3)

                    Capsule()
                        .fill(.white)
                        .frame(width: progress ? 132 : 0, height: 3)
                }
                .padding(.top, 54)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.15)) {
                progress = true
            }
        }
    }
}
