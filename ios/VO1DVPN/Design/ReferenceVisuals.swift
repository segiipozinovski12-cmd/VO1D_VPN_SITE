import SwiftUI

struct ReferenceBackdrop: View {
    var body: some View {
        ZStack {
            Color.black

            LinearGradient(
                colors: [
                    Color(red: 0.015, green: 0.017, blue: 0.021),
                    .black,
                    Color(red: 0.008, green: 0.009, blue: 0.012)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Canvas { context, size in
                var grid = Path()
                let step: CGFloat = 24

                for x in stride(from: 0, through: size.width, by: step) {
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                }

                for y in stride(from: 0, through: size.height, by: step) {
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                }

                context.stroke(
                    grid,
                    with: .color(.white.opacity(0.012)),
                    lineWidth: 0.45
                )

                var scan = Path()
                for y in stride(from: 8, through: size.height, by: 11) {
                    scan.move(to: CGPoint(x: 0, y: y))
                    scan.addLine(to: CGPoint(x: size.width, y: y))
                }

                context.stroke(
                    scan,
                    with: .color(.white.opacity(0.009)),
                    lineWidth: 0.35
                )
            }

            RadialGradient(
                colors: [
                    .white.opacity(0.035),
                    .clear
                ],
                center: UnitPoint(x: 0.48, y: 0.30),
                startRadius: 0,
                endRadius: 300
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct ReferencePlanetView: View {
    var compact = false
    var glow = true

    @State private var orbit = false
    @State private var breathe = false

    var body: some View {
        GeometryReader { proxy in
            let side = min(
                compact ? proxy.size.width * 0.92 : proxy.size.width * 1.52,
                compact ? 330 : 620
            )

            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(0.22),
                                Color(red: 0.16, green: 0.18, blue: 0.21).opacity(0.75),
                                Color(red: 0.025, green: 0.028, blue: 0.034),
                                .black
                            ],
                            center: UnitPoint(x: 0.42, y: 0.32),
                            startRadius: 0,
                            endRadius: side * 0.58
                        )
                    )
                    .frame(width: side, height: side)
                    .overlay {
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.12),
                                        .clear,
                                        .black.opacity(0.82)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        PlanetLongitudeLines()
                            .stroke(
                                .white.opacity(0.075),
                                style: StrokeStyle(
                                    lineWidth: 0.6,
                                    lineCap: .round
                                )
                            )
                            .padding(side * 0.09)
                    }
                    .overlay {
                        PlanetLandHints()
                            .fill(.white.opacity(0.13))
                            .blur(radius: 0.4)
                            .padding(side * 0.13)
                    }
                    .overlay {
                        PlanetNetwork()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.08),
                                        .white.opacity(0.48),
                                        .white.opacity(0.07)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(
                                    lineWidth: 0.75,
                                    lineCap: .round
                                )
                            )
                            .padding(side * 0.08)
                            .rotationEffect(.degrees(orbit ? 360 : 0))
                    }
                    .overlay {
                        PlanetNodes()
                            .fill(.white.opacity(0.92))
                            .shadow(color: .white.opacity(0.55), radius: 4)
                            .padding(side * 0.09)
                    }
                    .shadow(
                        color: glow ? .white.opacity(breathe ? 0.12 : 0.045) : .clear,
                        radius: glow ? 30 : 0
                    )
                    .mask(
                        Ellipse()
                            .frame(width: side, height: side)
                    )

                Ellipse()
                    .trim(from: 0.05, to: 0.56)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.36),
                                .white.opacity(0.06),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(
                            lineWidth: compact ? 0.8 : 1.1,
                            lineCap: .round
                        )
                    )
                    .frame(width: side * 1.04, height: side * 0.88)
                    .rotationEffect(.degrees(-13))

                Ellipse()
                    .trim(from: 0.60, to: 0.92)
                    .stroke(
                        .white.opacity(0.08),
                        style: StrokeStyle(
                            lineWidth: 0.65,
                            lineCap: .round
                        )
                    )
                    .frame(width: side * 1.16, height: side * 0.70)
                    .rotationEffect(.degrees(18))
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height,
                alignment: .top
            )
            .offset(y: compact ? -side * 0.56 : -side * 0.16)
        }
        .onAppear {
            withAnimation(
                .linear(duration: 34)
                .repeatForever(autoreverses: false)
            ) {
                orbit = true
            }

            withAnimation(
                .easeInOut(duration: 3.2)
                .repeatForever(autoreverses: true)
            ) {
                breathe = true
            }
        }
        .accessibilityHidden(true)
    }
}

private struct PlanetLongitudeLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        for factor in [0.20, 0.36, 0.50, 0.64, 0.80] {
            let width = rect.width * CGFloat(factor)
            path.addEllipse(
                in: CGRect(
                    x: rect.midX - width / 2,
                    y: rect.minY,
                    width: width,
                    height: rect.height
                )
            )
        }

        for factor in [0.30, 0.50, 0.70] {
            let h = rect.height * CGFloat(factor)
            path.addEllipse(
                in: CGRect(
                    x: rect.minX,
                    y: rect.midY - h / 2,
                    width: rect.width,
                    height: h
                )
            )
        }

        return path
    }
}

private struct PlanetLandHints: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        func island(_ points: [CGPoint]) {
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }

        island([
            CGPoint(x: rect.minX + rect.width * 0.17, y: rect.minY + rect.height * 0.28),
            CGPoint(x: rect.minX + rect.width * 0.31, y: rect.minY + rect.height * 0.20),
            CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.27),
            CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY + rect.height * 0.40),
            CGPoint(x: rect.minX + rect.width * 0.26, y: rect.minY + rect.height * 0.44)
        ])

        island([
            CGPoint(x: rect.minX + rect.width * 0.45, y: rect.minY + rect.height * 0.33),
            CGPoint(x: rect.minX + rect.width * 0.58, y: rect.minY + rect.height * 0.27),
            CGPoint(x: rect.minX + rect.width * 0.72, y: rect.minY + rect.height * 0.34),
            CGPoint(x: rect.minX + rect.width * 0.67, y: rect.minY + rect.height * 0.44),
            CGPoint(x: rect.minX + rect.width * 0.55, y: rect.minY + rect.height * 0.42)
        ])

        island([
            CGPoint(x: rect.minX + rect.width * 0.50, y: rect.minY + rect.height * 0.48),
            CGPoint(x: rect.minX + rect.width * 0.59, y: rect.minY + rect.height * 0.54),
            CGPoint(x: rect.minX + rect.width * 0.55, y: rect.minY + rect.height * 0.70),
            CGPoint(x: rect.minX + rect.width * 0.46, y: rect.minY + rect.height * 0.64)
        ])

        return path
    }
}

private struct PlanetNetwork: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = [
            CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.38),
            CGPoint(x: rect.minX + rect.width * 0.36, y: rect.minY + rect.height * 0.27),
            CGPoint(x: rect.minX + rect.width * 0.50, y: rect.minY + rect.height * 0.44),
            CGPoint(x: rect.minX + rect.width * 0.67, y: rect.minY + rect.height * 0.31),
            CGPoint(x: rect.minX + rect.width * 0.79, y: rect.minY + rect.height * 0.49),
            CGPoint(x: rect.minX + rect.width * 0.61, y: rect.minY + rect.height * 0.67),
            CGPoint(x: rect.minX + rect.width * 0.35, y: rect.minY + rect.height * 0.64)
        ]

        for index in 0..<points.count {
            let a = points[index]
            let b = points[(index + 2) % points.count]
            path.move(to: a)
            path.addQuadCurve(
                to: b,
                control: CGPoint(
                    x: (a.x + b.x) / 2,
                    y: min(a.y, b.y) - rect.height * 0.10
                )
            )
        }

        return path
    }
}

private struct PlanetNodes: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = [
            CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.38),
            CGPoint(x: rect.minX + rect.width * 0.36, y: rect.minY + rect.height * 0.27),
            CGPoint(x: rect.minX + rect.width * 0.50, y: rect.minY + rect.height * 0.44),
            CGPoint(x: rect.minX + rect.width * 0.67, y: rect.minY + rect.height * 0.31),
            CGPoint(x: rect.minX + rect.width * 0.79, y: rect.minY + rect.height * 0.49),
            CGPoint(x: rect.minX + rect.width * 0.61, y: rect.minY + rect.height * 0.67),
            CGPoint(x: rect.minX + rect.width * 0.35, y: rect.minY + rect.height * 0.64)
        ]

        for point in points {
            path.addEllipse(
                in: CGRect(
                    x: point.x - 1.7,
                    y: point.y - 1.7,
                    width: 3.4,
                    height: 3.4
                )
            )
        }

        return path
    }
}

struct ReferenceGlassPanel<Content: View>: View {
    let radius: CGFloat
    let highlighted: Bool
    @ViewBuilder let content: () -> Content

    init(
        radius: CGFloat = 24,
        highlighted: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.radius = radius
        self.highlighted = highlighted
        self.content = content
    }

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: radius,
            style: .continuous
        )

        content()
            .background {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay {
                        shape.fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(highlighted ? 0.13 : 0.07),
                                    .white.opacity(0.018),
                                    Color.black.opacity(0.36)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(highlighted ? 0.72 : 0.24),
                            .white.opacity(highlighted ? 0.18 : 0.055),
                            .white.opacity(highlighted ? 0.40 : 0.11)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: highlighted ? 1.2 : 0.8
                )
            }
            .shadow(
                color: highlighted ? .white.opacity(0.13) : .black.opacity(0.48),
                radius: highlighted ? 14 : 18,
                y: highlighted ? 0 : 10
            )
    }
}

struct ReferencePrimaryButton: View {
    let title: String
    var icon = "chevron.right"
    var action: () -> Void

    @State private var sheen = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.36),
                                Color.white.opacity(0.13),
                                Color.white.opacity(0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Capsule()
                    .fill(.ultraThinMaterial)

                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.34),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 120)
                .offset(x: sheen ? 220 : -220)
                .blur(radius: 7)
                .mask(Capsule())

                HStack {
                    Spacer()
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .padding(.trailing, 20)
                }
                .foregroundStyle(.white)
            }
            .frame(height: 58)
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.72),
                                .white.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .white.opacity(0.08), radius: 12)
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.98))
        .onAppear {
            withAnimation(
                .linear(duration: 2.8)
                .repeatForever(autoreverses: false)
            ) {
                sheen = true
            }
        }
    }
}

struct ReferenceVortexView: View {
    let connected: Bool
    let busy: Bool

    @State private var outer = false
    @State private var middle = false
    @State private var inner = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .trim(
                        from: Double(index) * 0.12,
                        to: min(1, Double(index) * 0.12 + 0.20)
                    )
                    .stroke(
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.18 + Double(index) * 0.07),
                                .white.opacity(0.95),
                                .white.opacity(0.12),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(
                            lineWidth: CGFloat(1.0 + Double(index) * 0.28),
                            lineCap: .round
                        )
                    )
                    .padding(CGFloat(index) * 7)
                    .rotationEffect(
                        .degrees(
                            (index.isMultiple(of: 2) ? 1 : -1)
                            * (outer ? 360 : 0)
                            + Double(index * 17)
                        )
                    )
                    .blur(radius: index < 2 ? 0 : 0.35)
            }

            Circle()
                .stroke(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.60),
                            .white.opacity(0.09),
                            .clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 120
                    ),
                    lineWidth: 1.2
                )
                .padding(pulse ? 4 : 13)
                .opacity(connected ? 0.80 : busy ? 0.60 : 0.28)

            Circle()
                .trim(from: 0.07, to: 0.32)
                .stroke(
                    .white.opacity(0.34),
                    style: StrokeStyle(lineWidth: 0.8, lineCap: .round)
                )
                .padding(30)
                .rotationEffect(.degrees(middle ? -360 : 0))

            Circle()
                .trim(from: 0.54, to: 0.74)
                .stroke(
                    .white.opacity(0.25),
                    style: StrokeStyle(lineWidth: 0.7, lineCap: .round)
                )
                .padding(48)
                .rotationEffect(.degrees(inner ? 360 : 0))
        }
        .shadow(color: .white.opacity(connected ? 0.28 : 0.08), radius: 18)
        .onAppear {
            withAnimation(
                .linear(duration: connected ? 5.4 : 8.4)
                .repeatForever(autoreverses: false)
            ) {
                outer = true
            }

            withAnimation(
                .linear(duration: 9.5)
                .repeatForever(autoreverses: false)
            ) {
                middle = true
            }

            withAnimation(
                .linear(duration: 13.0)
                .repeatForever(autoreverses: false)
            ) {
                inner = true
            }

            withAnimation(
                .easeInOut(duration: 2.4)
                .repeatForever(autoreverses: true)
            ) {
                pulse = true
            }
        }
        .accessibilityHidden(true)
    }
}

struct MiniTrafficChart: View {
    let seed: Int
    var rising = false

    var body: some View {
        Canvas { context, size in
            let values: [CGFloat] = rising
                ? [0.18,0.26,0.20,0.35,0.44,0.40,0.54,0.62,0.58,0.78]
                : [0.26,0.38,0.64,0.37,0.29,0.42,0.30,0.24,0.31,0.26]

            var line = Path()
            for (index, value) in values.enumerated() {
                let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
                let y = size.height * (1 - value)
                if index == 0 {
                    line.move(to: CGPoint(x: x, y: y))
                } else {
                    line.addLine(to: CGPoint(x: x, y: y))
                }
            }

            var fill = line
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0, y: size.height))
            fill.closeSubpath()

            context.fill(
                fill,
                with: .linearGradient(
                    Gradient(colors: [
                        .white.opacity(0.13),
                        .clear
                    ]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )

            context.stroke(
                line,
                with: .color(.white.opacity(0.82)),
                style: StrokeStyle(
                    lineWidth: 1.1,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
        .accessibilityHidden(true)
    }
}
