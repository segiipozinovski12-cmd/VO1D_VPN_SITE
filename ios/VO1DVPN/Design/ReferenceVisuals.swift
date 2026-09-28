import SwiftUI

// MARK: - VO1D cinematic reference visual system

struct ReferenceBackdrop: View {
    var interactive = false

    var body: some View {
        ZStack {
            Color(red: 0.004, green: 0.005, blue: 0.008)

            LinearGradient(
                colors: [
                    Color(red: 0.030, green: 0.034, blue: 0.045),
                    Color(red: 0.010, green: 0.012, blue: 0.018),
                    .black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    VO1DStyle.frost.opacity(0.070),
                    VO1DStyle.steel.opacity(0.030),
                    .clear
                ],
                center: UnitPoint(x: 0.18, y: 0.12),
                startRadius: 0,
                endRadius: 430
            )

            RadialGradient(
                colors: [
                    .white.opacity(0.050),
                    .clear
                ],
                center: UnitPoint(x: 0.88, y: 0.70),
                startRadius: 0,
                endRadius: 360
            )

            ReferenceLineField(interactive: interactive)
                .opacity(0.72)

            ReferenceNoise()
                .blendMode(.screen)
                .opacity(0.30)

            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.08),
                    .black.opacity(0.50)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct ReferenceLineField: View {
    @Environment(\.vo1dReduceMotion) private var reduceMotion

    let interactive: Bool

    @State private var dragPoint: CGPoint?
    @State private var impulse: CGFloat = 0

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: reduceMotion ? 1.0 : 1.0 / 30.0
            )
        ) { timeline in
            GeometryReader { proxy in
                Canvas { context, size in
                    let time =
                        reduceMotion
                        ? 0
                        : timeline.date.timeIntervalSinceReferenceDate

                    drawLines(
                        context: &context,
                        size: size,
                        time: time,
                        focus: dragPoint,
                        impulse: impulse
                    )
                }
                .contentShape(Rectangle())
                .gesture(
                    interactive
                    ? DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dragPoint = value.location
                            impulse = 1
                        }
                        .onEnded { _ in
                            withAnimation(.easeOut(duration: 0.8)) {
                                impulse = 0
                            }
                            dragPoint = nil
                        }
                    : nil
                )
            }
        }
        .accessibilityHidden(true)
    }

    private func drawLines(
        context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        focus: CGPoint?,
        impulse: CGFloat
    ) {
        let rows = 14

        for index in 0..<rows {
            let baseY =
                size.height *
                (0.07 + CGFloat(index) * 0.067)

            let phase =
                time * (0.17 + Double(index % 4) * 0.045) +
                Double(index) * 0.71

            let drift =
                CGFloat(sin(phase)) * 16

            let startX =
                size.width *
                (
                    index.isMultiple(of: 2)
                    ? -0.08
                    : 0.10
                ) +
                drift

            let width =
                size.width *
                (0.46 + CGFloat((index * 7) % 5) * 0.08)

            let p1 = CGPoint(
                x: startX,
                y: baseY
            )
            var p2 = CGPoint(
                x: startX + width * 0.34,
                y: baseY + CGFloat(sin(phase * 1.8)) * 14
            )
            var p3 = CGPoint(
                x: startX + width * 0.69,
                y: baseY - CGFloat(cos(phase * 1.35)) * 18
            )
            var p4 = CGPoint(
                x: startX + width,
                y: baseY + CGFloat(sin(phase * 1.13)) * 9
            )

            if let focus {
                p2 = displaced(p2, from: focus, impulse: impulse)
                p3 = displaced(p3, from: focus, impulse: impulse)
                p4 = displaced(p4, from: focus, impulse: impulse)
            }

            var glowPath = Path()
            glowPath.move(to: p1)
            glowPath.addLine(to: p2)
            glowPath.addLine(to: p3)
            glowPath.addLine(to: p4)

            context.drawLayer { glow in
                glow.addFilter(.blur(radius: 4.5))
                glow.stroke(
                    glowPath,
                    with: .color(
                        VO1DStyle.frost.opacity(
                            0.080 + Double(index % 3) * 0.020
                        )
                    ),
                    style: StrokeStyle(
                        lineWidth: 2.2,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: [
                            24 + CGFloat(index % 4) * 7,
                            13 + CGFloat(index % 3) * 5
                        ]
                    )
                )
            }

            context.stroke(
                glowPath,
                with: .color(
                    .white.opacity(
                        0.11 + Double(index % 4) * 0.018
                    )
                ),
                style: StrokeStyle(
                    lineWidth: 0.75,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: [
                        24 + CGFloat(index % 4) * 7,
                        13 + CGFloat(index % 3) * 5
                    ]
                )
            )

            for point in [p1, p4] {
                context.fill(
                    Path(
                        ellipseIn: CGRect(
                            x: point.x - 1.6,
                            y: point.y - 1.6,
                            width: 3.2,
                            height: 3.2
                        )
                    ),
                    with: .color(.white.opacity(0.55))
                )
            }
        }
    }

    private func displaced(
        _ point: CGPoint,
        from focus: CGPoint,
        impulse: CGFloat
    ) -> CGPoint {
        let dx = point.x - focus.x
        let dy = point.y - focus.y
        let distance = max(18, sqrt(dx * dx + dy * dy))
        let force = max(0, 1 - distance / 240) * impulse * 95

        return CGPoint(
            x: point.x + dx / distance * force,
            y: point.y + dy / distance * force
        )
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

// MARK: - Ambient lines replace the old planet system

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
                                Color.white.opacity(
                                    highlighted ? 0.22 : 0.11
                                ),
                                VO1DStyle.graphite.opacity(0.72),
                                Color.black.opacity(0.90)
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
                                .white.opacity(
                                    highlighted ? 0.19 : 0.10
                                ),
                                .clear,
                                VO1DStyle.frost.opacity(
                                    highlighted ? 0.08 : 0.03
                                )
                            ],
                            startPoint: UnitPoint(x: 0.05, y: 0.02),
                            endPoint: UnitPoint(x: 0.90, y: 0.95)
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
                                .white.opacity(
                                    highlighted ? 0.94 : 0.36
                                ),
                                .white.opacity(0.08),
                                VO1DStyle.frost.opacity(
                                    highlighted ? 0.44 : 0.16
                                )
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: highlighted ? 1.25 : 0.95
                    )
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) {
                GlassSheen(
                    radius: radius,
                    strong: highlighted
                )
                .allowsHitTesting(false)
            }
            .shadow(
                color: .white.opacity(
                    highlighted ? 0.22 : 0.055
                ),
                radius: highlighted ? 22 : 12
            )
            .shadow(
                color: .black.opacity(0.72),
                radius: 28,
                y: 14
            )
    }
}

private struct GlassSheen: View {
    @Environment(\.vo1dReduceMotion) private var reduceMotion

    let radius: CGFloat
    let strong: Bool

    @State private var shift: CGFloat = -0.65

    var body: some View {
        GeometryReader { proxy in
            RoundedRectangle(
                cornerRadius: radius,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(strong ? 0.20 : 0.09),
                        .white.opacity(strong ? 0.34 : 0.13),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(
                width: proxy.size.width * 0.42,
                height: proxy.size.height * 1.55
            )
            .rotationEffect(.degrees(-18))
            .offset(
                x: proxy.size.width * shift,
                y: -proxy.size.height * 0.24
            )
            .blur(radius: 8)
            .mask {
                RoundedRectangle(
                    cornerRadius: radius,
                    style: .continuous
                )
            }
            .onAppear {
                guard !reduceMotion else { return }

                withAnimation(
                    .linear(duration: strong ? 4.8 : 7.2)
                    .repeatForever(autoreverses: false)
                ) {
                    shift = 1.45
                }
            }
        }
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
