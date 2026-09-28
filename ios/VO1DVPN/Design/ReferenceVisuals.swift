import SwiftUI

// MARK: - VO1D cinematic reference visual system

struct ReferenceBackdrop: View {
    var body: some View {
        ZStack {
            Color.black

            RadialGradient(
                colors: [
                    .white.opacity(0.055),
                    .white.opacity(0.012),
                    .clear
                ],
                center: UnitPoint(x: 0.50, y: 0.06),
                startRadius: 0,
                endRadius: 430
            )

            RadialGradient(
                colors: [
                    VO1DStyle.frost.opacity(0.030),
                    .clear
                ],
                center: UnitPoint(x: 0.88, y: 0.42),
                startRadius: 0,
                endRadius: 360
            )

            LinearGradient(
                colors: [
                    .black.opacity(0.02),
                    .black.opacity(0.22),
                    .black.opacity(0.76)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            ReferenceNoise()
                .blendMode(.screen)
                .opacity(0.36)
        }
        .ignoresSafeArea()
    }
}

private struct ReferenceNoise: View {
    var body: some View {
        Canvas { context, size in
            let columns = 54
            let rows = 96

            for y in 0..<rows {
                for x in 0..<columns {
                    let h = (x * 73 + y * 151 + x * y * 7) & 255
                    guard h < 12 else { continue }

                    let px = size.width * CGFloat(x) / CGFloat(max(1, columns - 1))
                    let py = size.height * CGFloat(y) / CGFloat(max(1, rows - 1))
                    let alpha = 0.018 + Double(h % 5) * 0.004
                    let side: CGFloat = h.isMultiple(of: 3) ? 1.1 : 0.65

                    context.fill(
                        Path(
                            ellipseIn: CGRect(
                                x: px,
                                y: py,
                                width: side,
                                height: side
                            )
                        ),
                        with: .color(.white.opacity(alpha))
                    )
                }
            }

            for line in 0..<16 {
                let y = size.height * CGFloat(line + 1) / 17
                let width = size.width * CGFloat(0.06 + Double((line * 19) % 29) / 100)
                let x = size.width * CGFloat(Double((line * 31) % 68) / 100)
                context.fill(
                    Path(
                        CGRect(
                            x: x,
                            y: y,
                            width: width,
                            height: 0.45
                        )
                    ),
                    with: .color(.white.opacity(0.018))
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Brand

struct VO1DBrandLockup: View {
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 4 : 8) {
            GlitchText(
                "VO1D_VPN",
                size: compact ? 24 : 47,
                tracking: compact ? 2.0 : 2.9
            )

            Text("ZERO LOGS")
                .font(
                    .system(
                        size: compact ? 7 : 10,
                        weight: .medium,
                        design: .monospaced
                    )
                )
                .tracking(compact ? 4.1 : 7.2)
                .foregroundStyle(.white.opacity(0.82))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("VO1D VPN. Zero logs.")
    }
}

struct GlitchText: View {
    let text: String
    let size: CGFloat
    let tracking: CGFloat

    init(
        _ text: String,
        size: CGFloat,
        tracking: CGFloat
    ) {
        self.text = text
        self.size = size
        self.tracking = tracking
    }

    var body: some View {
        ZStack {
            brandText
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.15), radius: 5)

            brandText
                .foregroundStyle(.white.opacity(0.28))
                .offset(x: -2.2, y: -0.7)
                .mask {
                    glitchMask(
                        bands: [
                            (0.09, 0.16),
                            (0.44, 0.09),
                            (0.73, 0.11)
                        ]
                    )
                }

            brandText
                .foregroundStyle(.white.opacity(0.22))
                .offset(x: 2.8, y: 0.8)
                .mask {
                    glitchMask(
                        bands: [
                            (0.25, 0.08),
                            (0.58, 0.12),
                            (0.88, 0.07)
                        ]
                    )
                }

            brandText
                .foregroundStyle(.black.opacity(0.48))
                .offset(x: 0.7, y: 0.4)
                .mask {
                    glitchMask(
                        bands: [
                            (0.34, 0.025),
                            (0.66, 0.028)
                        ]
                    )
                }
        }
    }

    private var brandText: some View {
        Text(text)
            .font(
                .system(
                    size: size,
                    weight: .black,
                    design: .monospaced
                )
            )
            .tracking(tracking)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
    }

    private func glitchMask(
        bands: [(CGFloat, CGFloat)]
    ) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(Array(bands.enumerated()), id: \.offset) { _, band in
                    Rectangle()
                        .frame(
                            width: proxy.size.width,
                            height: max(1, proxy.size.height * band.1)
                        )
                        .offset(
                            y: proxy.size.height * band.0
                        )
                }
            }
        }
    }
}

// MARK: - Planet

struct ReferencePlanet: View {
    @Environment(\.vo1dReduceMotion) private var reduceMotion

    var diameter: CGFloat
    var rotation: Double = -16
    var glow: Double = 0.13
    var showRoutes = true

    @State private var routeDraw: CGFloat = 0.08
    @State private var orbitTurn = false
    @State private var breathe = false
    @State private var highlightTurn = false

    var body: some View {
        ZStack {
            planetShadow

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(white: 0.22),
                            Color(white: 0.075),
                            Color(white: 0.016),
                            .black
                        ],
                        center: UnitPoint(x: 0.33, y: 0.23),
                        startRadius: 0,
                        endRadius: diameter * 0.62
                    )
                )

            PlanetLandMasses()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.24),
                            .white.opacity(0.09),
                            .white.opacity(0.025)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(diameter * 0.055)
                .blur(radius: 0.25)

            PlanetLandMasses()
                .stroke(
                    .white.opacity(0.18),
                    lineWidth: 0.55
                )
                .padding(diameter * 0.055)

            cityLights
                .clipShape(Circle())

            PlanetGrid()
                .stroke(
                    .white.opacity(0.075),
                    lineWidth: 0.50
                )
                .padding(diameter * 0.018)
                .blendMode(.screen)

            if showRoutes {
                routeGlow
                routeCore

                PlanetRouteDots(active: breathe)
                    .padding(diameter * 0.038)
            }

            limbLight

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.15),
                            .clear,
                            .black.opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
                .opacity(0.72)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .clear,
                            .black.opacity(0.02),
                            .black.opacity(0.74)
                        ],
                        center: UnitPoint(x: 0.34, y: 0.28),
                        startRadius: diameter * 0.18,
                        endRadius: diameter * 0.64
                    )
                )

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.88),
                            .white.opacity(0.16),
                            .white.opacity(0.02),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.25
                )

            Circle()
                .trim(from: 0.01, to: 0.31)
                .stroke(
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.98),
                            .white.opacity(0.22),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(
                        lineWidth: 2.2,
                        lineCap: .round
                    )
                )
                .blur(radius: 1.4)
                .rotationEffect(
                    .degrees(
                        -28 + (highlightTurn ? 360 : 0)
                    )
                )
        }
        .frame(width: diameter, height: diameter)
        .rotationEffect(.degrees(rotation))
        .overlay { orbit }
        .shadow(
            color: .white.opacity(
                glow * (breathe ? 1.45 : 0.90)
            ),
            radius: diameter * (breathe ? 0.11 : 0.075)
        )
        .onAppear { startPlanetMotion() }
        .accessibilityHidden(true)
    }

    private var planetShadow: some View {
        Circle()
            .fill(.black)
            .shadow(
                color: .black.opacity(0.95),
                radius: diameter * 0.10,
                y: diameter * 0.04
            )
    }

    private var cityLights: some View {
        ZStack {
            PlanetCityLights(
                glow: false,
                intensity: breathe ? 1.0 : 0.82
            )

            PlanetCityLights(
                glow: true,
                intensity: breathe ? 1.0 : 0.76
            )
            .blur(radius: 2.2)
            .blendMode(.screen)
        }
        .padding(diameter * 0.045)
    }

    private var routeGlow: some View {
        PlanetRoutes()
            .trim(from: 0, to: routeDraw)
            .stroke(
                .white.opacity(0.34),
                style: StrokeStyle(
                    lineWidth: 3.0,
                    lineCap: .round
                )
            )
            .blur(radius: 4.5)
            .padding(diameter * 0.038)
            .blendMode(.screen)
    }

    private var routeCore: some View {
        PlanetRoutes()
            .trim(from: 0, to: routeDraw)
            .stroke(
                LinearGradient(
                    colors: [
                        .white.opacity(0.08),
                        .white.opacity(0.88),
                        .white.opacity(0.08)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(
                    lineWidth: 0.85,
                    lineCap: .round
                )
            )
            .padding(diameter * 0.038)
    }

    private var limbLight: some View {
        ZStack {
            Circle()
                .trim(from: 0.58, to: 0.97)
                .stroke(
                    .white.opacity(0.24),
                    style: StrokeStyle(
                        lineWidth: diameter * 0.018,
                        lineCap: .round
                    )
                )
                .blur(radius: diameter * 0.018)
                .rotationEffect(.degrees(12))

            Circle()
                .trim(from: 0.62, to: 0.95)
                .stroke(
                    .white.opacity(0.70),
                    style: StrokeStyle(
                        lineWidth: 1.5,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(12))
        }
    }

    private var orbit: some View {
        ZStack {
            Ellipse()
                .trim(from: 0.06, to: 0.84)
                .stroke(
                    .white.opacity(0.08),
                    lineWidth: 0.6
                )
                .frame(
                    width: diameter * 1.26,
                    height: diameter * 0.34
                )
                .rotationEffect(
                    .degrees(
                        -13 + (orbitTurn ? 360 : 0)
                    )
                )
                .offset(y: diameter * 0.10)

            Ellipse()
                .trim(from: 0.12, to: 0.34)
                .stroke(
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.52),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(
                        lineWidth: 1.0,
                        lineCap: .round
                    )
                )
                .frame(
                    width: diameter * 1.26,
                    height: diameter * 0.34
                )
                .rotationEffect(
                    .degrees(
                        -13 + (orbitTurn ? 360 : 0)
                    )
                )
                .offset(y: diameter * 0.10)
                .blur(radius: 0.8)
        }
    }

    private func startPlanetMotion() {
        guard !reduceMotion else {
            routeDraw = 1
            breathe = true
            return
        }

        withAnimation(.easeOut(duration: 1.35)) {
            routeDraw = 1
        }

        withAnimation(
            .linear(duration: 17)
            .repeatForever(autoreverses: false)
        ) {
            orbitTurn = true
        }

        withAnimation(
            .linear(duration: 12)
            .repeatForever(autoreverses: false)
        ) {
            highlightTurn = true
        }

        withAnimation(
            .easeInOut(duration: 2.8)
            .repeatForever(autoreverses: true)
        ) {
            breathe = true
        }
    }
}

private struct PlanetGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        for factor in [-0.64, -0.42, -0.20, 0.0, 0.20, 0.42, 0.64] {
            let height = rect.height * CGFloat(1 - abs(factor) * 0.45)
            let y = center.y + rect.height * CGFloat(factor) * 0.44

            path.addEllipse(
                in: CGRect(
                    x: rect.minX + rect.width * 0.055,
                    y: y - height * 0.050,
                    width: rect.width * 0.89,
                    height: height * 0.10
                )
            )
        }

        for factor in [-0.62, -0.34, 0.0, 0.34, 0.62] {
            let width = rect.width * CGFloat(0.58 + (1 - abs(factor)) * 0.20)

            path.addEllipse(
                in: CGRect(
                    x: center.x - width * 0.5,
                    y: rect.minY + rect.height * 0.04,
                    width: width,
                    height: rect.height * 0.92
                )
            )
        }

        return path
    }
}

private struct PlanetLandMasses: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + rect.width * x,
                y: rect.minY + rect.height * y
            )
        }

        // North America
        path.move(to: p(0.10, 0.27))
        path.addLine(to: p(0.16, 0.20))
        path.addLine(to: p(0.25, 0.17))
        path.addLine(to: p(0.34, 0.21))
        path.addLine(to: p(0.40, 0.27))
        path.addLine(to: p(0.38, 0.34))
        path.addLine(to: p(0.31, 0.38))
        path.addLine(to: p(0.27, 0.45))
        path.addLine(to: p(0.22, 0.42))
        path.addLine(to: p(0.18, 0.35))
        path.addLine(to: p(0.11, 0.33))
        path.closeSubpath()

        // South America
        path.move(to: p(0.30, 0.47))
        path.addLine(to: p(0.38, 0.50))
        path.addLine(to: p(0.42, 0.58))
        path.addLine(to: p(0.39, 0.69))
        path.addLine(to: p(0.35, 0.80))
        path.addLine(to: p(0.30, 0.87))
        path.addLine(to: p(0.27, 0.77))
        path.addLine(to: p(0.27, 0.65))
        path.addLine(to: p(0.24, 0.56))
        path.closeSubpath()

        // Europe + Asia
        path.move(to: p(0.46, 0.27))
        path.addLine(to: p(0.52, 0.22))
        path.addLine(to: p(0.60, 0.18))
        path.addLine(to: p(0.70, 0.18))
        path.addLine(to: p(0.80, 0.21))
        path.addLine(to: p(0.90, 0.27))
        path.addLine(to: p(0.87, 0.34))
        path.addLine(to: p(0.80, 0.36))
        path.addLine(to: p(0.74, 0.42))
        path.addLine(to: p(0.67, 0.39))
        path.addLine(to: p(0.61, 0.44))
        path.addLine(to: p(0.55, 0.39))
        path.addLine(to: p(0.49, 0.36))
        path.addLine(to: p(0.45, 0.32))
        path.closeSubpath()

        // Africa
        path.move(to: p(0.50, 0.41))
        path.addLine(to: p(0.58, 0.40))
        path.addLine(to: p(0.64, 0.47))
        path.addLine(to: p(0.62, 0.59))
        path.addLine(to: p(0.56, 0.72))
        path.addLine(to: p(0.49, 0.67))
        path.addLine(to: p(0.45, 0.55))
        path.addLine(to: p(0.46, 0.46))
        path.closeSubpath()

        // Arabia / India
        path.move(to: p(0.62, 0.43))
        path.addLine(to: p(0.70, 0.46))
        path.addLine(to: p(0.73, 0.54))
        path.addLine(to: p(0.69, 0.62))
        path.addLine(to: p(0.64, 0.55))
        path.closeSubpath()

        // Australia
        path.move(to: p(0.72, 0.64))
        path.addLine(to: p(0.82, 0.61))
        path.addLine(to: p(0.89, 0.67))
        path.addLine(to: p(0.87, 0.76))
        path.addLine(to: p(0.78, 0.79))
        path.addLine(to: p(0.70, 0.72))
        path.closeSubpath()

        // Greenland
        path.move(to: p(0.34, 0.12))
        path.addLine(to: p(0.41, 0.10))
        path.addLine(to: p(0.44, 0.17))
        path.addLine(to: p(0.39, 0.23))
        path.addLine(to: p(0.33, 0.19))
        path.closeSubpath()

        return path
    }
}

private struct PlanetCityLights: View {
    let glow: Bool
    let intensity: Double

    var body: some View {
        Canvas { context, size in
            let columns = 90
            let rows = 90

            for y in 0..<rows {
                for x in 0..<columns {
                    let nx = CGFloat(x) / CGFloat(columns - 1)
                    let ny = CGFloat(y) / CGFloat(rows - 1)
                    let density = landDensity(x: nx, y: ny)

                    guard density > 0 else { continue }

                    let hash = abs(
                        (x * 73856093) ^
                        (y * 19349663) ^
                        ((x + y) * 83492791)
                    )

                    let threshold = Int(
                        max(
                            2,
                            24 - density * 15
                        )
                    )

                    guard hash % threshold == 0 else { continue }

                    let px = size.width * nx
                    let py = size.height * ny
                    let power = 0.28 + Double(hash % 72) / 100
                    let radius: CGFloat =
                        glow
                        ? 1.3 + CGFloat(hash % 4) * 0.35
                        : 0.45 + CGFloat(hash % 3) * 0.22

                    context.fill(
                        Path(
                            ellipseIn: CGRect(
                                x: px - radius,
                                y: py - radius,
                                width: radius * 2,
                                height: radius * 2
                            )
                        ),
                        with: .color(
                            .white.opacity(
                                min(
                                    0.95,
                                    power * intensity
                                )
                            )
                        )
                    )
                }
            }
        }
        .blendMode(.screen)
    }

    private func landDensity(
        x: CGFloat,
        y: CGFloat
    ) -> CGFloat {
        let europe = blob(x, y, 0.58, 0.35, 0.17, 0.12)
        let asia = blob(x, y, 0.72, 0.33, 0.22, 0.15)
        let india = blob(x, y, 0.69, 0.53, 0.09, 0.10)
        let japan = blob(x, y, 0.86, 0.39, 0.045, 0.09)
        let africa = blob(x, y, 0.54, 0.55, 0.14, 0.20)
        let northAmerica = blob(x, y, 0.25, 0.34, 0.18, 0.16)
        let eastUS = blob(x, y, 0.33, 0.40, 0.10, 0.12)
        let southAmerica = blob(x, y, 0.33, 0.66, 0.11, 0.20)
        let australia = blob(x, y, 0.79, 0.70, 0.13, 0.10)

        return min(
            1,
            europe * 1.25 +
            asia * 0.95 +
            india * 1.12 +
            japan * 1.18 +
            africa * 0.56 +
            northAmerica * 0.78 +
            eastUS * 1.05 +
            southAmerica * 0.50 +
            australia * 0.58
        )
    }

    private func blob(
        _ x: CGFloat,
        _ y: CGFloat,
        _ cx: CGFloat,
        _ cy: CGFloat,
        _ rx: CGFloat,
        _ ry: CGFloat
    ) -> CGFloat {
        let dx = (x - cx) / rx
        let dy = (y - cy) / ry
        let d = dx * dx + dy * dy

        guard d < 1 else { return 0 }
        return 1 - d
    }
}

private struct PlanetRoutes: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let routes: [(CGPoint, CGPoint, CGPoint)] = [
            (
                CGPoint(x: rect.width * 0.26, y: rect.height * 0.43),
                CGPoint(x: rect.width * 0.44, y: rect.height * 0.10),
                CGPoint(x: rect.width * 0.57, y: rect.height * 0.34)
            ),
            (
                CGPoint(x: rect.width * 0.34, y: rect.height * 0.62),
                CGPoint(x: rect.width * 0.53, y: rect.height * 0.20),
                CGPoint(x: rect.width * 0.77, y: rect.height * 0.42)
            ),
            (
                CGPoint(x: rect.width * 0.55, y: rect.height * 0.35),
                CGPoint(x: rect.width * 0.70, y: rect.height * 0.16),
                CGPoint(x: rect.width * 0.86, y: rect.height * 0.34)
            ),
            (
                CGPoint(x: rect.width * 0.56, y: rect.height * 0.39),
                CGPoint(x: rect.width * 0.62, y: rect.height * 0.16),
                CGPoint(x: rect.width * 0.34, y: rect.height * 0.36)
            ),
            (
                CGPoint(x: rect.width * 0.51, y: rect.height * 0.51),
                CGPoint(x: rect.width * 0.75, y: rect.height * 0.28),
                CGPoint(x: rect.width * 0.79, y: rect.height * 0.67)
            )
        ]

        for route in routes {
            path.move(to: route.0)
            path.addQuadCurve(
                to: route.2,
                control: route.1
            )
        }

        return path
    }
}

private struct PlanetRouteDots: View {
    let active: Bool

    private let points: [(CGFloat, CGFloat)] = [
        (0.26, 0.43),
        (0.57, 0.34),
        (0.34, 0.62),
        (0.77, 0.42),
        (0.55, 0.35),
        (0.86, 0.34),
        (0.51, 0.51),
        (0.79, 0.67)
    ]

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.30))
                        .frame(
                            width: active ? 12 : 7,
                            height: active ? 12 : 7
                        )
                        .blur(radius: 5)

                    Circle()
                        .fill(.white)
                        .frame(
                            width: index.isMultiple(of: 3) ? 3.8 : 2.6,
                            height: index.isMultiple(of: 3) ? 3.8 : 2.6
                        )
                }
                .position(
                    x: proxy.size.width * point.0,
                    y: proxy.size.height * point.1
                )
            }
        }
        .blendMode(.screen)
    }
}

// MARK: - Glass

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
        let shape = RoundedRectangle(
            cornerRadius: radius,
            style: .continuous
        )

        content
            .background {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(highlighted ? 0.18 : 0.078),
                                Color(white: 0.12).opacity(highlighted ? 0.68 : 0.50),
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
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(highlighted ? 0.17 : 0.075),
                                .clear,
                                .clear
                            ],
                            startPoint: UnitPoint(x: 0.08, y: 0.02),
                            endPoint: UnitPoint(x: 0.70, y: 0.58)
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
            .overlay {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(highlighted ? 0.92 : 0.26),
                                .white.opacity(highlighted ? 0.34 : 0.07),
                                .white.opacity(highlighted ? 0.68 : 0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: highlighted ? 1.25 : 0.85
                    )
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(highlighted ? 0.82 : 0.26),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: highlighted ? 82 : 52,
                        height: highlighted ? 1.6 : 0.9
                    )
                    .blur(radius: 0.4)
                    .padding(.leading, radius * 0.78)
                    .padding(.top, 1.1)
                    .allowsHitTesting(false)
            }
            .shadow(
                color: .white.opacity(highlighted ? 0.22 : 0.035),
                radius: highlighted ? 18 : 8
            )
            .shadow(
                color: .black.opacity(0.62),
                radius: 22,
                y: 12
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
                    .foregroundStyle(.white.opacity(0.94))
            }
            .padding(.horizontal, 18)
            .frame(height: 60)
            .background {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.50),
                                .white.opacity(0.18),
                                Color(white: 0.08).opacity(0.96)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(
                        .ultraThinMaterial,
                        in: Capsule()
                    )
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.92),
                                .white.opacity(0.18),
                                .white.opacity(0.54)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            }
            .overlay(alignment: .topLeading) {
                Capsule()
                    .fill(.white.opacity(0.78))
                    .frame(width: 92, height: 1.3)
                    .blur(radius: 0.6)
                    .padding(.leading, 25)
                    .padding(.top, 1)
            }
            .shadow(color: .white.opacity(0.26), radius: 18)
            .shadow(color: .black.opacity(0.58), radius: 18, y: 10)
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.975))
    }
}

// MARK: - Vortex

struct ReferenceVortex: View {
    @Environment(\.vo1dReduceMotion) private var reduceMotion

    let active: Bool
    let busy: Bool

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: reduceMotion ? 1.0 : 1.0 / 30.0
            )
        ) { timeline in
            let time =
                reduceMotion
                ? 0
                : timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                drawVortex(
                    context: &context,
                    size: size,
                    time: time
                )
            }
        }
        .compositingGroup()
        .drawingGroup()
        .accessibilityHidden(true)
    }

    private func drawVortex(
        context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval
    ) {
        let side = min(size.width, size.height)
        let center = CGPoint(
            x: size.width / 2,
            y: size.height / 2
        )

        let strength: Double =
            active
            ? 1.0
            : busy
                ? 0.70
                : 0.24

        // deep halo
        context.drawLayer { halo in
            halo.addFilter(
                .blur(
                    radius: active ? 24 : 15
                )
            )

            for ring in 0..<5 {
                let radius =
                    side * (0.27 + CGFloat(ring) * 0.062)
                let rect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )

                halo.stroke(
                    Path(ellipseIn: rect),
                    with: .color(
                        .white.opacity(
                            (0.045 + Double(ring) * 0.018)
                            * strength
                        )
                    ),
                    lineWidth:
                        active
                        ? 10 - CGFloat(ring)
                        : 5
                )
            }
        }

        // large luminous spiral bands
        context.drawLayer { glow in
            glow.addFilter(
                .blur(
                    radius: active ? 7.5 : 4.0
                )
            )

            for index in 0..<14 {
                let base =
                    Double(index) * 25.7 +
                    time * (active ? 23 : busy ? 34 : 8)

                let radius =
                    side * (
                        0.25 +
                        CGFloat(index % 7) * 0.035
                    )

                let length =
                    34.0 +
                    Double(index % 5) * 13.0

                let start = Angle(degrees: base)
                let end = Angle(degrees: base + length)
                let lineWidth =
                    active
                    ? CGFloat(3.8 + Double(index % 3) * 1.7)
                    : CGFloat(1.2 + Double(index % 2))

                var path = Path()
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: start,
                    endAngle: end,
                    clockwise: false
                )

                glow.stroke(
                    path,
                    with: .color(
                        .white.opacity(
                            (0.12 + Double(index % 4) * 0.045)
                            * strength
                        )
                    ),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
            }
        }

        // crisp energy arcs
        for index in 0..<24 {
            let direction = index.isMultiple(of: 2) ? 1.0 : -1.0
            let base =
                Double(index) * 15.0 +
                time *
                (active ? 20.0 : busy ? 30.0 : 6.0) *
                direction

            let radius =
                side * (
                    0.235 +
                    CGFloat(index % 9) * 0.024
                )

            let length =
                18.0 +
                Double((index * 11) % 31)

            let alpha =
                (
                    0.12 +
                    Double(index % 6) * 0.072
                ) * strength

            var path = Path()
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(base),
                endAngle: .degrees(base + length),
                clockwise: false
            )

            context.stroke(
                path,
                with: .color(.white.opacity(alpha)),
                style: StrokeStyle(
                    lineWidth:
                        active && index % 5 == 0
                        ? 2.6
                        : 0.9 + CGFloat(index % 3) * 0.45,
                    lineCap: .round
                )
            )
        }

        // inner orbit rings
        for ring in 0..<3 {
            let radius =
                side * (0.18 + CGFloat(ring) * 0.040)

            var path = Path()
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(
                    time * (18 + Double(ring) * 8)
                    + Double(ring) * 80
                ),
                endAngle: .degrees(
                    time * (18 + Double(ring) * 8)
                    + Double(ring) * 80
                    + 210
                ),
                clockwise: false
            )

            context.stroke(
                path,
                with: .color(
                    .white.opacity(
                        (0.08 + Double(ring) * 0.04)
                        * strength
                    )
                ),
                lineWidth: 0.7
            )
        }

        // orbit particles
        if active || busy {
            context.drawLayer { particles in
                particles.addFilter(.blur(radius: 1.4))

                for index in 0..<18 {
                    let angle =
                        time * (0.62 + Double(index % 4) * 0.11)
                        + Double(index) * 0.57

                    let radius =
                        side * (
                            0.25 +
                            CGFloat(index % 7) * 0.024
                        )

                    let px =
                        center.x +
                        cos(angle) * Double(radius)
                    let py =
                        center.y +
                        sin(angle) * Double(radius) * 0.92

                    let r: CGFloat =
                        index.isMultiple(of: 4)
                        ? 2.0
                        : 1.1

                    particles.fill(
                        Path(
                            ellipseIn: CGRect(
                                x: px - Double(r),
                                y: py - Double(r),
                                width: Double(r * 2),
                                height: Double(r * 2)
                            )
                        ),
                        with: .color(
                            .white.opacity(
                                active ? 0.76 : 0.40
                            )
                        )
                    )
                }
            }
        }

        // center halo
        context.drawLayer { core in
            core.addFilter(.blur(radius: 14))
            let radius = side * 0.13

            core.fill(
                Path(
                    ellipseIn: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                ),
                with: .color(
                    .white.opacity(
                        active ? 0.060 : 0.018
                    )
                )
            )
        }
    }
}

// MARK: - Mini chart

struct MiniSparkline: View {
    var intensity: Double = 1.0

    private let points: [CGFloat] = [
        0.80, 0.74, 0.63, 0.47, 0.31,
        0.57, 0.73, 0.66, 0.54, 0.63,
        0.72, 0.61, 0.42, 0.55, 0.49,
        0.35, 0.29, 0.34
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Path { path in
                    guard points.count > 1 else { return }

                    for index in points.indices {
                        let x =
                            proxy.size.width *
                            CGFloat(index) /
                            CGFloat(points.count - 1)
                        let y =
                            proxy.size.height *
                            points[index]

                        if index == 0 {
                            path.move(
                                to: CGPoint(x: x, y: y)
                            )
                        } else {
                            path.addLine(
                                to: CGPoint(x: x, y: y)
                            )
                        }
                    }
                }
                .stroke(
                    .white.opacity(0.16 * intensity),
                    lineWidth: 4.0
                )
                .blur(radius: 3)

                Path { path in
                    guard points.count > 1 else { return }

                    for index in points.indices {
                        let x =
                            proxy.size.width *
                            CGFloat(index) /
                            CGFloat(points.count - 1)
                        let y =
                            proxy.size.height *
                            points[index]

                        if index == 0 {
                            path.move(
                                to: CGPoint(x: x, y: y)
                            )
                        } else {
                            path.addLine(
                                to: CGPoint(x: x, y: y)
                            )
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.22 * intensity),
                            .white.opacity(0.96 * intensity)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(
                        lineWidth: 1.35,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
        }
        .accessibilityHidden(true)
    }
}
