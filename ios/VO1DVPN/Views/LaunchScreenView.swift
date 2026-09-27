import SwiftUI

struct LaunchScreenView: View {
    @Environment(\.vo1dReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var reveal = false
    let completion: () -> Void
    private let statuses = ["INITIALIZING", "LOADING NETWORK", "CHECKING ROUTES", "READY"]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    LaunchNetwork().stroke(.white.opacity(0.18), lineWidth: 0.6)
                        .frame(width: 240, height: 140)
                        .scaleEffect(reveal ? 1 : 0.55)
                    Circle().stroke(.white.opacity(0.12), lineWidth: 1).frame(width: 68, height: 68)
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 30, weight: .ultraLight))
                }.opacity(reveal ? 1 : 0)
                Text("VO1D_VPN").font(.system(size: 34, weight: .bold, design: .monospaced)).tracking(2)
                    .opacity(step > 0 ? 1 : 0).offset(y: step > 0 || reduceMotion ? 0 : 8)
                Text("SECURE CONNECTION").font(VO1DStyle.mono(10)).tracking(3.2)
                    .foregroundStyle(VO1DStyle.secondary).padding(.top, 14).opacity(step > 0 ? 1 : 0)
                HStack(spacing: 6) {
                    ForEach(0..<4) { index in
                        Capsule().fill(.white.opacity(step > index ? 0.85 : 0.12)).frame(width: 27, height: 2)
                    }
                }.padding(.top, 48).opacity(reveal ? 1 : 0)
                Text(statuses[min(3, max(0, step - 1))])
                    .font(VO1DStyle.mono(9)).tracking(1.6).foregroundStyle(VO1DStyle.secondary)
                    .contentTransition(.opacity).padding(.top, 16).opacity(reveal ? 1 : 0)
                Spacer()
                Text("PRIVATE BY DESIGN").font(VO1DStyle.mono(9)).tracking(2.2)
                    .foregroundStyle(.white.opacity(0.35)).opacity(step > 0 ? 1 : 0).padding(.bottom, 34)
            }
        }
        .accessibilityIdentifier("launch.screen")
        .task {
            do {
                try await Task.sleep(for: .milliseconds(120))
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { reveal = true }
                for index in 1...4 {
                    try await Task.sleep(for: .milliseconds(index == 1 ? 220 : 330))
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { step = index }
                }
                try await Task.sleep(for: .milliseconds(220))
                completion()
            } catch { return }
        }
    }
}

private struct LaunchNetwork: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        for index in 0..<8 {
            let angle = Double(index) * .pi / 4
            let end = CGPoint(x: center.x + CGFloat(cos(angle) as Double) * rect.width / 2, y: center.y + CGFloat(sin(angle) as Double) * rect.height / 2)
            path.move(to: center)
            path.addLine(to: end)
            path.addEllipse(in: CGRect(x: end.x - 2, y: end.y - 2, width: 4, height: 4))
        }
        return path
    }
}
