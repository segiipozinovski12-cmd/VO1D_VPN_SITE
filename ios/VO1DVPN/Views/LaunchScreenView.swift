import SwiftUI

struct LaunchScreenView: View {
    @Environment(\.vo1dReduceMotion) private var reduceMotion

    @State private var step = 0
    @State private var reveal = false
    @State private var scan = false
    @State private var pulse = false
    @State private var progress: CGFloat = 0

    let completion: () -> Void

    private let statuses = [
        "INITIALIZING",
        "LOADING NETWORK",
        "CHECKING ROUTES",
        "READY"
    ]

    var body: some View {
        ZStack {
            DeepSpaceBackdrop().ignoresSafeArea()

            LinearGradient(
                colors: [.clear, VO1DStyle.ice.opacity(0.06), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 110)
            .offset(y: scan ? 470 : -470)
            .opacity(reduceMotion ? 0 : 1)
            .blur(radius: 12)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    LaunchNetwork()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.06), VO1DStyle.ice.opacity(0.30), .white.opacity(0.04)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 0.7
                        )
                        .frame(width: 260, height: 150)
                        .scaleEffect(reveal ? 1 : 0.62)
                        .opacity(reveal ? 1 : 0)

                    Circle()
                        .stroke(VO1DStyle.ice.opacity(pulse ? 0.03 : 0.23), lineWidth: 1)
                        .frame(width: pulse ? 106 : 76, height: pulse ? 106 : 76)

                    Color.clear
                        .frame(width: 72, height: 72)
                        .vo1dSystemGlass(in: Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                        )

                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 30, weight: .ultraLight))
                        .foregroundStyle(.white)
                        .shadow(color: VO1DStyle.ice.opacity(0.25), radius: 10)
                }
                .frame(height: 176)

                Text("VO1D_VPN")
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .opacity(step > 0 ? 1 : 0)
                    .offset(y: step > 0 || reduceMotion ? 0 : 8)

                Text("SECURE CONNECTION")
                    .font(VO1DStyle.mono(10))
                    .tracking(3.2)
                    .foregroundStyle(VO1DStyle.secondary)
                    .padding(.top, 14)
                    .opacity(step > 0 ? 1 : 0)

                VStack(spacing: 14) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.08))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.92), VO1DStyle.ice.opacity(0.72)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: proxy.size.width * progress)
                                .shadow(color: VO1DStyle.ice.opacity(0.22), radius: 5)
                        }
                    }
                    .frame(width: 146, height: 2)

                    Text(statuses[min(3, max(0, step - 1))])
                        .font(VO1DStyle.mono(9))
                        .tracking(1.6)
                        .foregroundStyle(VO1DStyle.secondary)
                        .contentTransition(.opacity)
                }
                .padding(.top, 48)
                .opacity(reveal ? 1 : 0)

                Spacer()

                HStack(spacing: 8) {
                    Circle().fill(step >= 4 ? VO1DStyle.green : VO1DStyle.secondary).frame(width: 5, height: 5)
                    Text(step >= 4 ? "SYSTEM READY" : "PRIVATE BY DESIGN")
                        .font(VO1DStyle.mono(9))
                        .tracking(2.0)
                }
                .foregroundStyle(step >= 4 ? VO1DStyle.green : .white.opacity(0.36))
                .padding(.bottom, 34)
                .opacity(step > 0 ? 1 : 0)
            }
        }
        .accessibilityIdentifier("launch.screen")
        .task {
            do {
                try await Task.sleep(for: .milliseconds(80))

                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.34)) {
                    reveal = true
                }

                if !reduceMotion {
                    withAnimation(.linear(duration: 1.45)) {
                        scan = true
                    }

                    withAnimation(.easeOut(duration: 1.3)) {
                        progress = 1
                    }

                    withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                } else {
                    progress = 1
                }

                let delays = [180, 270, 285, 300]
                for index in 1...4 {
                    try await Task.sleep(for: .milliseconds(delays[index - 1]))
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.20)) {
                        step = index
                    }
                }

                try await Task.sleep(for: .milliseconds(180))
                completion()
            } catch {
                return
            }
        }
    }
}

private struct LaunchNetwork: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        for index in 0..<10 {
            let angle = Double(index) * .pi / 5
            let reach = index.isMultiple(of: 2) ? 0.50 : 0.40
            let end = CGPoint(
                x: center.x + CGFloat(cos(angle)) * rect.width * reach,
                y: center.y + CGFloat(sin(angle)) * rect.height * reach
            )

            path.move(to: center)
            path.addLine(to: end)
            path.addEllipse(
                in: CGRect(
                    x: end.x - 1.8,
                    y: end.y - 1.8,
                    width: 3.6,
                    height: 3.6
                )
            )
        }

        path.addEllipse(
            in: CGRect(
                x: center.x - 46,
                y: center.y - 46,
                width: 92,
                height: 92
            )
        )

        return path
    }
}
