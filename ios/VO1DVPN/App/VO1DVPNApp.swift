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
            .scaleEffect(showSplash ? 0.985 : 1)

            if showSplash {
                LaunchScreenView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.30), value: model.sessionToken != nil)
        .task {
            try? await Task.sleep(for: .milliseconds(1350))
            withAnimation(.easeOut(duration: 0.42)) {
                showSplash = false
            }
        }
    }
}

private struct LaunchScreenView: View {
    @State private var progress: CGFloat = 0
    @State private var titleVisible = false
    @State private var scan = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [.clear, .white.opacity(0.028), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Text("VO1D_VPN")
                        .font(.system(size: 35, weight: .black, design: .monospaced))
                        .tracking(2.6)
                        .foregroundStyle(.white.opacity(0.15))
                        .offset(x: scan ? 1.5 : -1.5)

                    Text("VO1D_VPN")
                        .font(.system(size: 35, weight: .black, design: .monospaced))
                        .tracking(2.6)
                        .foregroundStyle(.white)
                }
                .opacity(titleVisible ? 1 : 0)
                .scaleEffect(titleVisible ? 1 : 0.96)

                Text("SECURE CONNECTION")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(3.1)
                    .foregroundStyle(.white.opacity(0.44))
                    .padding(.top, 14)
                    .opacity(titleVisible ? 1 : 0)

                VStack(spacing: 8) {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.12))
                            .frame(width: 138, height: 3)

                        Capsule()
                            .fill(.white)
                            .frame(width: 138 * progress, height: 3)
                    }

                    Text(progress < 0.9 ? "INITIALIZING" : "READY")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.28))
                        .contentTransition(.opacity)
                }
                .padding(.top, 52)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.30)) {
                titleVisible = true
            }

            withAnimation(.linear(duration: 0.55).repeatCount(2, autoreverses: true)) {
                scan.toggle()
            }

            withAnimation(.easeInOut(duration: 1.05)) {
                progress = 1
            }
        }
    }
}
