import SwiftUI

// MARK: - Reference driven visual language

struct ReferenceBackdrop: View {
    var body: some View {
        ZStack {
            Color.black

            RadialGradient(
                colors: [
                    Color.white.opacity(0.045),
                    Color.clear
                ],
                center: UnitPoint(x: 0.48, y: 0.14),
                startRadius: 0,
                endRadius: 360
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.02),
                    Color.black.opacity(0.35),
                    Color.black.opacity(0.76)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            ReferenceNoise()
                .opacity(0.15)
                .blendMode(.screen)
        }
        .ignoresSafeArea()
    }
}

private struct ReferenceNoise: View {
    var body: some View {
        Canvas { context, size in
            let columns = 42
            let rows = 78

            for y in 0..<rows {
                for x in 0..<columns {
                    let seed = (x * 37 + y * 53) % 19
                    guard seed == 0 || seed == 7 else { continue }

                    let px = size.width * CGFloat(x) / CGFloat(max(1, columns - 1))
                    let py = size.height * CGFloat(y) / CGFloat(max(1, rows - 1))
                    let alpha = seed == 0 ? 0.035 : 0.018
                    let rect = CGRect(x: px, y: py, width: seed == 0 ? 1.4 : 0.8, height: 0.8)
                    context.fill(Path(rect), with: .color(.white.opacity(alpha)))
                }
            }

            for line in 0..<12 {
                let y = size.height * CGFloat(line + 1) / 13
                let width = size.width * CGFloat(0.08 + Double((line * 17) % 24) / 100)
                let x = size.width * CGFloat(Double((line * 29) % 70) / 100)
                let rect = CGRect(x: x, y: y, width: width, height: 0.6)
                context.fill(Path(rect), with: .color(.white.opacity(0.025)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct VO1DBrandLockup: View {
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 4 : 8) {
            GlitchText(
                "VO1D_VPN",
                size: compact ? 24 : 48,
                tracking: compact ? 2.4 : 3.4
            )

            Text("ZERO LOGS")
                .font(.system(size: compact ? 7 : 10, weight: .medium, design: .monospaced))
                .tracking(compact ? 4.0 : 7.0)
                .foregroundStyle(.white.opacity(0.80))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("VO1D VPN. Zero logs.")
    }
}

struct GlitchText: View {
    let text: String
    let size: CGFloat
    let tracking: CGFloat

    init(_ text: String, size: CGFloat, tracking: CGFloat) {
        self.text = text
        self.size = size
        self.tracking = tracking
    }

    var body: some View {
        ZStack {
            brandText
                .foregroundStyle(.white)

            brandText
                .foregroundStyle(.white.opacity(0.19))
                .offset(x: -2, y: 0)
                .mask(alignment: .top) {
                    VStack(spacing: 0) {
                        Rectangle().frame(height: size * 0.16)
                        Spacer()
                    }
                }

            brandText
                .foregroundStyle(.white.opacity(0.15))
                .offset(x: 2.5, y: 1)
                .mask(alignment: .bottom) {
                    VStack(spacing: 0) {
                        Spacer()
                        Rectangle().frame(height: size * 0.18)
                    }
                }
        }
    }

    private var brandText: some View {
        Text(text)
            .font(.system(size: size, weight: .black, design: .monospaced))
            .tracking(tracking)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
    }
}

struct ReferencePlanet: View {
    var diameter: CGFloat
    var rotation: Double = -16
    var glow: Double = 0.13
    var showRoutes = true

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.24),
                            Color(white: 0.18),
                            Color(white: 0.035),
                            .black
                        ],
                        center: UnitPoint(x: 0.40, y: 0.24),
                        startRadius: 0,
                        endRadius: diameter * 0.62
                    )
                )

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.20),
                            .clear,
                            .black.opacity(0.80)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
                .opacity(0.65)

            PlanetContinents()
                .fill(.white.opacity(0.22))
                .blur(radius: 0.35)
                .padding(diameter * 0.08)

            PlanetContinents()
                .stroke(.white.opacity(0.22), lineWidth: 0.6)
                .padding(diameter * 0.08)

            PlanetGrid()
                .stroke(.white.opacity(0.10), lineWidth: 0.55)
                .padding(diameter * 0.035)

            if showRoutes {
                PlanetRoutes()
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.06),
                                .white.opacity(0.38),
                                .white.opacity(0.04)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(
                            lineWidth: 0.8,
                            lineCap: .round
                        )
                    )
                    .padding(diameter * 0.06)

                PlanetRouteDots()
                    .padding(diameter * 0.06)
            }

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.52),
                            .white.opacity(0.08),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.1
                )

            Circle()
                .trim(from: 0.05, to: 0.33)
                .stroke(.white.opacity(0.75), lineWidth: 1.8)
                .blur(radius: 1.2)
                .rotationEffect(.degrees(-24))
        }
        .frame(width: diameter, height: diameter)
        .rotationEffect(.degrees(rotation))
        .shadow(color: .white.opacity(glow), radius: diameter * 0.075)
        .overlay {
            Ellipse()
                .stroke(.white.opacity(0.08), lineWidth: 0.7)
                .frame(width: diameter * 1.20, height: diameter * 0.33)
                .rotationEffect(.degrees(-12))
                .offset(y: diameter * 0.08)
        }
        .accessibilityHidden(true)
    }
}

private struct PlanetGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        for factor in [-0.55, -0.28, 0.0, 0.28, 0.55] {
            let h = rect.height * CGFloat(1 - abs(factor) * 0.55)
            let y = center.y + rect.height * CGFloat(factor) * 0.44
            path.addEllipse(
                in: CGRect(
                    x: rect.minX + rect.width * 0.08,
                    y: y - h * 0.075,
                    width: rect.width * 0.84,
                    height: h * 0.15
                )
            )
        }

        for factor in [-0.55, -0.26, 0.26, 0.55] {
            let w = rect.width * CGFloat(1 - abs(factor) * 0.28)
            path.addEllipse(
                in: CGRect(
                    x: center.x - w * 0.20,
                    y: rect.minY + rect.height * 0.06,
                    width: w * 0.40,
                    height: rect.height * 0.88
                )
            )
        }

        return path
    }
}

private struct PlanetContinents: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        p.move(to: point(0.18, 0.27))
        p.addCurve(to: point(0.33, 0.19), control1: point(0.22, 0.18), control2: point(0.28, 0.18))
        p.addCurve(to: point(0.43, 0.28), control1: point(0.38, 0.18), control2: point(0.43, 0.21))
        p.addLine(to: point(0.40, 0.39))
        p.addLine(to: point(0.31, 0.42))
        p.addLine(to: point(0.26, 0.36))
        p.addLine(to: point(0.18, 0.35))
        p.closeSubpath()

        p.move(to: point(0.43, 0.41))
        p.addCurve(to: point(0.54, 0.35), control1: point(0.48, 0.34), control2: point(0.51, 0.34))
        p.addLine(to: point(0.61, 0.43))
        p.addLine(to: point(0.58, 0.54))
        p.addLine(to: point(0.50, 0.60))
        p.addLine(to: point(0.44, 0.51))
        p.closeSubpath()

        p.move(to: point(0.57, 0.25))
        p.addCurve(to: point(0.79, 0.23), control1: point(0.66, 0.16), control2: point(0.74, 0.17))
        p.addLine(to: point(0.86, 0.31))
        p.addLine(to: point(0.80, 0.39))
        p.addLine(to: point(0.69, 0.37))
        p.addLine(to: point(0.64, 0.47))
        p.addLine(to: point(0.56, 0.41))
        p.addLine(to: point(0.58, 0.33))
        p.closeSubpath()

        p.move(to: point(0.71, 0.55))
        p.addCurve(to: point(0.82, 0.59), control1: point(0.76, 0.53), control2: point(0.81, 0.55))
        p.addLine(to: point(0.84, 0.69))
        p.addLine(to: point(0.76, 0.72))
        p.addLine(to: point(0.69, 0.66))
        p.closeSubpath()

        p.move(to: point(0.33, 0.52))
        p.addCurve(to: point(0.41, 0.62), control1: point(0.39, 0.53), control2: point(0.43, 0.57))
        p.addLine(to: point(0.38, 0.78))
        p.addLine(to: point(0.31, 0.85))
        p.addLine(to: point(0.27, 0.73))
        p.addLine(to: point(0.28, 0.60))
        p.closeSubpath()

        return p
    }
}

private struct PlanetRoutes: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let routes: [(CGPoint, CGPoint, CGPoint)] = [
            (
                CGPoint(x: rect.width * 0.24, y: rect.height * 0.50),
                CGPoint(x: rect.width * 0.45, y: rect.height * 0.15),
                CGPoint(x: rect.width * 0.63, y: rect.height * 0.43)
            ),
            (
                CGPoint(x: rect.width * 0.35, y: rect.height * 0.66),
                CGPoint(x: rect.width * 0.53, y: rect.height * 0.28),
                CGPoint(x: rect.width * 0.79, y: rect.height * 0.49)
            ),
            (
                CGPoint(x: rect.width * 0.52, y: rect.height * 0.41),
                CGPoint(x: rect.width * 0.69, y: rect.height * 0.22),
                CGPoint(x: rect.width * 0.83, y: rect.height * 0.34)
            )
        ]

        for route in routes {
            path.move(to: route.0)
            path.addQuadCurve(to: route.2, control: route.1)
        }

        return path
    }
}

private struct PlanetRouteDots: View {
    var body: some View {
        GeometryReader { proxy in
            let points: [(CGFloat, CGFloat)] = [
                (0.24, 0.50),
                (0.63, 0.43),
                (0.35, 0.66),
                (0.79, 0.49),
                (0.52, 0.41),
                (0.83, 0.34)
            ]

            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                Circle()
                    .fill(.white)
                    .frame(width: index.isMultiple(of: 2) ? 4.5 : 3.2, height: index.isMultiple(of: 2) ? 4.5 : 3.2)
                    .shadow(color: .white.opacity(0.8), radius: 5)
                    .position(
                        x: proxy.size.width * point.0,
                        y: proxy.size.height * point.1
                    )
            }
        }
    }
}

struct ReferenceGlassCard<Content: View>: View {
    let radius: CGFloat
    let highlighted: Bool
    @ViewBuilder var content: Content

    init(
        radius: CGFloat = 22,
        highlighted: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.radius = radius
        self.highlighted = highlighted
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        content
            .background {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(highlighted ? 0.12 : 0.055),
                                Color(white: 0.09).opacity(0.82),
                                Color(white: 0.025).opacity(0.96)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(
                        .ultraThinMaterial,
                        in: shape
                    )
            }
            .overlay {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(highlighted ? 0.70 : 0.19),
                                .white.opacity(highlighted ? 0.18 : 0.055),
                                .white.opacity(highlighted ? 0.48 : 0.09)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: highlighted ? 1.3 : 0.85
                    )
            }
            .shadow(
                color: .white.opacity(highlighted ? 0.15 : 0.025),
                radius: highlighted ? 12 : 6
            )
            .shadow(
                color: .black.opacity(0.48),
                radius: 18,
                y: 9
            )
    }
}

struct ReferencePrimaryButton: View {
    let title: String
    var icon: String = "chevron.right"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(.horizontal, 18)
            .frame(height: 58)
            .background {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.62).opacity(0.76),
                                Color(white: 0.26).opacity(0.64),
                                Color(white: 0.10).opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.70),
                                .white.opacity(0.15),
                                .white.opacity(0.42)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .white.opacity(0.16), radius: 13)
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.975))
    }
}

struct ReferenceVortex: View {
    let active: Bool
    let busy: Bool

    @State private var rotateA = false
    @State private var rotateB = false
    @State private var rotateC = false
    @State private var breathe = false

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Circle()
                    .trim(
                        from: CGFloat(index) * 0.075,
                        to: min(
                            0.98,
                            CGFloat(index) * 0.075 + 0.22
                        )
                    )
                    .stroke(
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(active ? 0.86 : busy ? 0.56 : 0.22),
                                VO1DStyle.frost.opacity(active ? 0.38 : 0.10),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(
                            lineWidth: index.isMultiple(of: 3) ? 2.2 : 1.0,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(
                        .degrees(
                            (rotateA ? 360 : 0)
                            + Double(index) * 33
                        )
                    )
                    .scaleEffect(0.72 + CGFloat(index) * 0.032)
                    .blur(radius: index.isMultiple(of: 3) ? 0.8 : 0)
            }

            Circle()
                .trim(from: 0.10, to: 0.38)
                .stroke(
                    .white.opacity(active ? 0.58 : 0.20),
                    style: StrokeStyle(
                        lineWidth: 4.2,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(rotateB ? -360 : 0))
                .blur(radius: 2.2)
                .scaleEffect(0.86)

            Circle()
                .trim(from: 0.56, to: 0.77)
                .stroke(
                    .white.opacity(active ? 0.28 : 0.10),
                    style: StrokeStyle(
                        lineWidth: 1.2,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(rotateC ? 360 : 0))
                .scaleEffect(1.04)

            Circle()
                .stroke(.white.opacity(active ? 0.12 : 0.05), lineWidth: 0.7)
                .scaleEffect(breathe ? 1.04 : 0.94)
                .blur(radius: breathe ? 1.8 : 0)
        }
        .shadow(
            color: .white.opacity(active ? 0.22 : busy ? 0.12 : 0.03),
            radius: active ? 16 : 8
        )
        .onAppear { animate() }
        .onChange(of: active) { _, _ in animate() }
        .onChange(of: busy) { _, _ in animate() }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func animate() {
        withAnimation(
            .linear(duration: active ? 7.0 : busy ? 4.0 : 16.0)
            .repeatForever(autoreverses: false)
        ) {
            rotateA = true
        }

        withAnimation(
            .linear(duration: active ? 5.2 : busy ? 3.2 : 13.0)
            .repeatForever(autoreverses: false)
        ) {
            rotateB = true
        }

        withAnimation(
            .linear(duration: active ? 10.0 : 18.0)
            .repeatForever(autoreverses: false)
        ) {
            rotateC = true
        }

        withAnimation(
            .easeInOut(duration: 2.5)
            .repeatForever(autoreverses: true)
        ) {
            breathe = true
        }
    }
}

struct MiniSparkline: View {
    var intensity: Double = 1.0

    private let points: [CGFloat] = [
        0.76, 0.72, 0.64, 0.48, 0.34,
        0.58, 0.72, 0.66, 0.54, 0.63,
        0.72, 0.61, 0.42, 0.55, 0.49,
        0.36, 0.30, 0.35
    ]

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                guard points.count > 1 else { return }

                for index in points.indices {
                    let x = proxy.size.width * CGFloat(index) / CGFloat(points.count - 1)
                    let y = proxy.size.height * points[index]

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                LinearGradient(
                    colors: [
                        .white.opacity(0.28 * intensity),
                        .white.opacity(0.92 * intensity)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
            )
        }
        .accessibilityHidden(true)
    }
}
