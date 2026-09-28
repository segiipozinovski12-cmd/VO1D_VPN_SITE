import SwiftUI

struct LaunchScreenView: View {
    @Environment(\.vo1dReduceMotion) private var reduceMotion

    @State private var step = 0
    @State private var reveal = false
    @State private var scan = false
    @State private var pulse = false
    @State private var networkDraw: CGFloat = 0
    @State private var orbit = false
    @State private var sweep = false

    let completion: () -> Void

    private let stages = ["CORE", "ROUTE", "TUNNEL", "READY"]
    private let statuses = [
        "INITIALIZING NATIVE CLIENT",
        "DISCOVERING NETWORK ROUTES",
        "PREPARING SECURE SESSION",
        "SYSTEM READY"
    ]

    private var environmentLabel: String {
        #if targetEnvironment(simulator)
        "SIMULATOR PREVIEW"
        #else
        "PACKET TUNNEL / XRAY CORE"
        #endif
    }

    var body: some View {
        ZStack {
            DeepSpaceBackdrop()
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    VO1DStyle.ice.opacity(reveal ? 0.055 : 0),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.42),
                startRadius: 10,
                endRadius: 330
            )
            .ignoresSafeArea()
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.8),
                value: reveal
            )

            LinearGradient(
                colors: [
                    .clear,
                    .white.opacity(0.028),
                    VO1DStyle.ice.opacity(0.055),
                    .white.opacity(0.018),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 72)
            .offset(y: scan ? 500 : -500)
            .blur(radius: 22)
            .opacity(reduceMotion ? 0 : 1)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                launchCore
                    .opacity(reveal ? 1 : 0)
                    .scaleEffect(reveal || reduceMotion ? 1 : 0.92)

                VStack(spacing: 11) {
                    Text("VO1D_VPN")
                        .font(
                            .system(
                                size: 34,
                                weight: .bold,
                                design: .monospaced
                            )
                        )
                        .tracking(2.1)

                    Text(environmentLabel)
                        .font(VO1DStyle.mono(9))
                        .tracking(2.4)
                        .foregroundStyle(VO1DStyle.secondary)
                }
                .padding(.top, 24)
                .opacity(step > 0 ? 1 : 0)
                .offset(y: step > 0 || reduceMotion ? 0 : 8)

                phaseRail
                    .padding(.top, 44)
                    .opacity(reveal ? 1 : 0)

                Text(statuses[min(3, max(0, step - 1))])
                    .font(VO1DStyle.mono(9))
                    .tracking(1.4)
                    .foregroundStyle(
                        step >= 4
                        ? VO1DStyle.green
                        : VO1DStyle.secondary
                    )
                    .contentTransition(.opacity)
                    .padding(.top, 16)
                    .opacity(reveal ? 1 : 0)

                Spacer()

                HStack(spacing: 8) {
                    Circle()
                        .fill(
                            step >= 4
                            ? VO1DStyle.green
                            : .white.opacity(0.28)
                        )
                        .frame(width: 5, height: 5)
                        .shadow(
                            color:
                                step >= 4
                                ? VO1DStyle.green.opacity(0.45)
                                : .clear,
                            radius: 5
                        )

                    Text(
                        step >= 4
                        ? "SECURE CLIENT READY"
                        : "PRIVATE BY DESIGN"
                    )
                    .font(VO1DStyle.mono(9))
                    .tracking(1.8)
                }
                .foregroundStyle(
                    step >= 4
                    ? VO1DStyle.green
                    : .white.opacity(0.38)
                )
                .padding(.bottom, 34)
                .opacity(step > 0 ? 1 : 0)
            }
            .padding(.horizontal, 28)
        }
        .accessibilityIdentifier("launch.screen")
        .task {
            do {
                try await Task.sleep(for: .milliseconds(70))

                withAnimation(
                    reduceMotion ? nil : .easeOut(duration: 0.42)
                ) {
                    reveal = true
                }

                if !reduceMotion {
                    withAnimation(.easeOut(duration: 0.82)) {
                        networkDraw = 1
                    }

                    withAnimation(.linear(duration: 1.35)) {
                        scan = true
                    }

                    withAnimation(
                        .linear(duration: 3.0)
                        .repeatForever(autoreverses: false)
                    ) {
                        orbit = true
                    }

                    withAnimation(
                        .easeInOut(duration: 1.55)
                        .repeatForever(autoreverses: true)
                    ) {
                        pulse = true
                    }

                    withAnimation(
                        .linear(duration: 2.2)
                        .repeatForever(autoreverses: false)
                    ) {
                        sweep = true
                    }
                } else {
                    networkDraw = 1
                }

                let delays = [160, 235, 255, 270]
                for index in 1...4 {
                    try await Task.sleep(
                        for: .milliseconds(delays[index - 1])
                    )
                    withAnimation(
                        reduceMotion
                        ? nil
                        : .snappy(duration: 0.24)
                    ) {
                        step = index
                    }
                }

                try await Task.sleep(for: .milliseconds(220))
                completion()
            } catch {
                return
            }
        }
    }

    private var launchCore: some View {
        ZStack {
            LaunchNetwork()
                .trim(from: 0, to: networkDraw)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.025),
                            .white.opacity(0.25),
                            .white.opacity(0.045)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(
                        lineWidth: 0.7,
                        lineCap: .round
                    )
                )
                .frame(width: 278, height: 164)

            Circle()
                .stroke(.white.opacity(0.035), lineWidth: 1)
                .frame(width: 154, height: 154)

            Circle()
                .trim(from: 0.02, to: 0.17)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.03),
                            .white.opacity(0.58),
                            .white.opacity(0.04)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(
                        lineWidth: 1.1,
                        lineCap: .round
                    )
                )
                .frame(width: 132, height: 132)
                .rotationEffect(.degrees(orbit ? 360 : 0))
                .opacity(reduceMotion ? 0.35 : 1)

            Circle()
                .trim(from: 0.56, to: 0.70)
                .stroke(
                    .white.opacity(0.15),
                    style: StrokeStyle(
                        lineWidth: 0.8,
                        lineCap: .round
                    )
                )
                .frame(width: 118, height: 118)
                .rotationEffect(.degrees(sweep ? -360 : 0))
                .opacity(reduceMotion ? 0 : 1)

            Circle()
                .stroke(
                    VO1DStyle.ice.opacity(
                        pulse ? 0.025 : 0.18
                    ),
                    lineWidth: 1
                )
                .frame(
                    width: pulse ? 112 : 88,
                    height: pulse ? 112 : 88
                )

            ZStack {
                Color.clear
                    .frame(width: 82, height: 82)
                    .vo1dSystemGlass(
                        in: RoundedRectangle(
                            cornerRadius: 28,
                            style: .continuous
                        )
                    )

                RoundedRectangle(
                    cornerRadius: 28,
                    style: .continuous
                )
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.28),
                            .white.opacity(0.055),
                            .black.opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .frame(width: 82, height: 82)

                Image(
                    systemName:
                        step >= 4
                        ? "checkmark.shield"
                        : "point.3.connected.trianglepath.dotted"
                )
                .font(.system(size: 30, weight: .ultraLight))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .shadow(
                    color: VO1DStyle.ice.opacity(0.20),
                    radius: 12
                )
            }
            .shadow(
                color: .black.opacity(0.34),
                radius: 20,
                y: 10
            )
        }
        .frame(height: 184)
    }

    private var phaseRail: some View {
        HStack(spacing: 7) {
            ForEach(
                Array(stages.enumerated()),
                id: \.offset
            ) { index, title in
                let active = step > index

                HStack(spacing: 6) {
                    Circle()
                        .fill(
                            active
                            ? (index == 3
                               ? VO1DStyle.green
                               : .white.opacity(0.82))
                            : .white.opacity(0.12)
                        )
                        .frame(width: 4, height: 4)

                    Text(title)
                        .font(VO1DStyle.mono(8))
                        .tracking(0.35)
                        .foregroundStyle(
                            active
                            ? .white.opacity(0.78)
                            : VO1DStyle.secondary.opacity(0.45)
                        )
                }
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .vo1dSystemGlass(
                    in: RoundedRectangle(
                        cornerRadius: 11,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 11,
                        style: .continuous
                    )
                    .strokeBorder(
                        .white.opacity(active ? 0.12 : 0.045),
                        lineWidth: 0.8
                    )
                }
            }
        }
        .frame(maxWidth: 360)
    }
}

private struct LaunchNetwork: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(
            x: rect.midX,
            y: rect.midY
        )

        for index in 0..<12 {
            let angle = Double(index) * .pi / 6
            let reach = index.isMultiple(of: 2) ? 0.50 : 0.40
            let end = CGPoint(
                x:
                    center.x
                    + CGFloat(cos(angle))
                    * rect.width
                    * reach,
                y:
                    center.y
                    + CGFloat(sin(angle))
                    * rect.height
                    * reach
            )

            path.move(to: center)
            path.addLine(to: end)
            path.addEllipse(
                in: CGRect(
                    x: end.x - 1.6,
                    y: end.y - 1.6,
                    width: 3.2,
                    height: 3.2
                )
            )
        }

        path.addEllipse(
            in: CGRect(
                x: center.x - 50,
                y: center.y - 50,
                width: 100,
                height: 100
            )
        )

        return path
    }
}
