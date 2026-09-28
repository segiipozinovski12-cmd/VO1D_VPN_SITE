import SwiftUI

struct LaunchScreenView: View {
    @Environment(\.vo1dReduceMotion) private var reduceMotion

    @State private var progress: CGFloat = 0.08
    @State private var stage = 0
    @State private var reveal = false
    @State private var logoReveal = false
    @State private var scan = false

    let completion: () -> Void

    private let lines = [
        "Initializing core...",
        "Loading systems...",
        "Routing network...",
        "Establishing tunnel..."
    ]

    var body: some View {
        ZStack {
            ReferenceBackdrop()

            ReferencePlanetView()
                .frame(height: 640)
                .offset(y: -8)
                .opacity(reveal ? 1 : 0)
                .scaleEffect(reveal || reduceMotion ? 1 : 1.04)

            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.04),
                    .black.opacity(0.88),
                    .black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    .clear,
                    .white.opacity(0.075),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
            .offset(y: scan ? 360 : -360)
            .opacity(reduceMotion ? 0 : 0.8)

            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    Spacer()

                    VStack(alignment: .leading, spacing: 13) {
                        ForEach(
                            ["PRIVACY", "SECURE", "ANONYMITY", "FREEDOM"],
                            id: \.self
                        ) { word in
                            HStack(spacing: 10) {
                                Rectangle()
                                    .fill(.white.opacity(0.48))
                                    .frame(width: 11, height: 1)

                                Text(word)
                                    .font(VO1DStyle.mono(7))
                                    .tracking(2.0)
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }
                    }
                    .padding(.top, 38)
                    .padding(.trailing, 14)
                }

                Spacer(minLength: 0)

                VStack(spacing: 13) {
                    Text("VO1D_VPN")
                        .font(
                            .system(
                                size: 42,
                                weight: .black,
                                design: .monospaced
                            )
                        )
                        .tracking(1.4)
                        .foregroundStyle(.white)
                        .shadow(
                            color: .white.opacity(0.12),
                            radius: 12
                        )

                    Text("ZERO LOGS")
                        .font(VO1DStyle.mono(11))
                        .tracking(7)
                        .foregroundStyle(.white.opacity(0.88))
                }
                .opacity(logoReveal ? 1 : 0)
                .offset(y: logoReveal || reduceMotion ? 0 : 10)

                Spacer()
                    .frame(height: 138)

                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(VO1DStyle.mono(9))
                                .foregroundStyle(
                                    index <= stage
                                    ? .white.opacity(0.58)
                                    : .white.opacity(0.16)
                                )
                                .contentTransition(.opacity)
                        }
                    }

                    HStack(spacing: 12) {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(.white.opacity(0.12))

                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                .white.opacity(0.65),
                                                .white,
                                                .white.opacity(0.72)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width:
                                            max(
                                                10,
                                                proxy.size.width * progress
                                            )
                                    )
                                    .shadow(
                                        color: .white.opacity(0.38),
                                        radius: 5
                                    )
                            }
                        }
                        .frame(height: 4)

                        Text("\(Int(progress * 100))%")
                            .font(VO1DStyle.mono(10))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.86))
                            .frame(width: 36, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
                .opacity(reveal ? 1 : 0)
            }
        }
        .accessibilityIdentifier("launch.screen")
        .task {
            do {
                if reduceMotion {
                    reveal = true
                    logoReveal = true
                    stage = 3
                    progress = 1
                    try await Task.sleep(for: .milliseconds(300))
                    completion()
                    return
                }

                withAnimation(.easeOut(duration: 0.55)) {
                    reveal = true
                }

                try await Task.sleep(for: .milliseconds(180))

                withAnimation(.easeOut(duration: 0.42)) {
                    logoReveal = true
                }

                withAnimation(.linear(duration: 1.8)) {
                    scan = true
                }

                let targets: [CGFloat] = [0.26, 0.45, 0.68, 0.86]
                for index in 0..<targets.count {
                    try await Task.sleep(for: .milliseconds(index == 0 ? 260 : 320))

                    withAnimation(.easeInOut(duration: 0.48)) {
                        stage = index
                        progress = targets[index]
                    }
                }

                try await Task.sleep(for: .milliseconds(300))

                withAnimation(.easeOut(duration: 0.32)) {
                    progress = 1
                }

                try await Task.sleep(for: .milliseconds(280))
                completion()
            } catch {
                return
            }
        }
    }
}
