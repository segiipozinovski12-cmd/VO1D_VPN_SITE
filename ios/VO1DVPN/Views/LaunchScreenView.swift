import SwiftUI

struct LaunchScreenView: View {
    @Environment(\.vo1dReduceMotion) private var reduceMotion

    @State private var appeared = false
    @State private var progress: CGFloat = 0.04
    @State private var statusIndex = 0
    @State private var sweep = false
    @State private var corePulse = false

    let completion: () -> Void

    private let statuses = [
        "Initializing core...",
        "Loading systems...",
        "Routing network...",
        "Establishing tunnel..."
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ReferenceBackdrop(interactive: true)

                VStack(spacing: 0) {
                    topPrivacy
                        .padding(.horizontal, 24)
                        .padding(.top, 22)
                        .opacity(appeared ? 1 : 0)

                    Spacer(minLength: 18)

                    brandBlock
                        .padding(.horizontal, 24)

                    Spacer(minLength: 20)

                    coreGlass
                        .padding(.horizontal, 26)

                    Spacer(minLength: 22)

                    terminalFooter
                        .padding(.horizontal, 26)
                        .padding(.bottom, 22)
                }

                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.06),
                        VO1DStyle.frost.opacity(0.035),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .offset(
                    y:
                        sweep
                        ? proxy.size.height * 0.72
                        : -proxy.size.height * 0.56
                )
                .blur(radius: 24)
                .opacity(reduceMotion ? 0 : 1)
                .allowsHitTesting(false)
            }
        }
        .task { await runSequence() }
        .accessibilityIdentifier("launch.screen")
    }

    private var topPrivacy: some View {
        HStack(alignment: .top) {
            Text("VO1D / BOOT")
                .font(
                    .system(
                        size: 8,
                        weight: .medium,
                        design: .monospaced
                    )
                )
                .tracking(2.0)
                .foregroundStyle(.white.opacity(0.34))

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                privacyLine("PRIVACY")
                privacyLine("SECURE")
                privacyLine("ANONYMITY")
                privacyLine("FREEDOM")
            }
        }
    }

    private func privacyLine(_ text: String) -> some View {
        HStack(spacing: 9) {
            Circle()
                .fill(.white.opacity(0.72))
                .frame(width: 2.6, height: 2.6)

            Rectangle()
                .fill(.white.opacity(0.22))
                .frame(width: 13, height: 0.7)

            Text(text)
                .font(
                    .system(
                        size: 7,
                        weight: .medium,
                        design: .monospaced
                    )
                )
                .tracking(2.2)
                .foregroundStyle(.white.opacity(0.58))
        }
    }

    private var brandBlock: some View {
        VStack(spacing: 14) {
            VO1DBrandLockup()
                .shadow(color: .black.opacity(0.98), radius: 18)
                .shadow(color: .white.opacity(0.16), radius: 10)

            Text("PRIVATE NETWORK")
                .font(
                    .system(
                        size: 9,
                        weight: .medium,
                        design: .monospaced
                    )
                )
                .tracking(3.2)
                .foregroundStyle(.white.opacity(0.38))
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared || reduceMotion ? 1 : 0.97)
    }

    private var coreGlass: some View {
        ReferenceGlassCard(
            radius: 28,
            highlighted: false
        ) {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .white.opacity(0.16),
                                    VO1DStyle.frost.opacity(0.05),
                                    .black.opacity(0.88)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 38
                            )
                        )
                        .frame(width: 64, height: 64)

                    Circle()
                        .stroke(
                            .white.opacity(corePulse ? 0.58 : 0.18),
                            lineWidth: 1.0
                        )
                        .frame(width: corePulse ? 58 : 48, height: corePulse ? 58 : 48)
                        .blur(radius: corePulse ? 1.8 : 0)

                    Circle()
                        .fill(.white)
                        .frame(width: 7, height: 7)
                        .shadow(color: .white.opacity(0.85), radius: 8)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("VO1D CORE")
                        .font(
                            .system(
                                size: 12,
                                weight: .semibold,
                                design: .monospaced
                            )
                        )
                        .tracking(1.7)

                    Text("SECURE BOOT SEQUENCE")
                        .font(
                            .system(
                                size: 8,
                                weight: .medium,
                                design: .monospaced
                            )
                        )
                        .tracking(1.3)
                        .foregroundStyle(.white.opacity(0.34))

                    Text(
                        statuses[
                            min(
                                statusIndex,
                                statuses.count - 1
                            )
                        ]
                    )
                    .font(
                        .system(
                            size: 11,
                            weight: .regular,
                            design: .monospaced
                        )
                    )
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(1)

                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { index in
                            Capsule()
                                .fill(
                                    index <= statusIndex
                                    ? .white.opacity(0.80)
                                    : .white.opacity(0.11)
                                )
                                .frame(width: 24, height: 2.5)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .frame(maxWidth: 430)
        .opacity(appeared ? 1 : 0)
    }

    private var terminalFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(
                    Array(statuses.enumerated()),
                    id: \.offset
                ) { index, status in
                    Text(status)
                        .font(
                            .system(
                                size: 8.5,
                                weight: .regular,
                                design: .monospaced
                            )
                        )
                        .foregroundStyle(
                            index <= statusIndex
                            ? .white.opacity(0.54)
                            : .white.opacity(0.14)
                        )
                }
            }

            HStack(spacing: 12) {
                GeometryReader { bar in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.10))
                            .frame(height: 3.5)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.84),
                                        VO1DStyle.pearl,
                                        VO1DStyle.frost.opacity(0.70)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(
                                    8,
                                    bar.size.width * min(1, progress)
                                ),
                                height: 3.5
                            )
                            .shadow(
                                color: .white.opacity(0.48),
                                radius: 7
                            )
                    }
                }
                .frame(height: 3.5)

                Text("\(Int(progress * 100))%")
                    .font(
                        .system(
                            size: 9,
                            weight: .medium,
                            design: .monospaced
                        )
                    )
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(width: 34, alignment: .trailing)
            }
        }
        .opacity(appeared ? 1 : 0)
    }

    @MainActor
    private func runSequence() async {
        if reduceMotion {
            appeared = true
            progress = 1
            statusIndex = 3
            corePulse = true

            try? await Task.sleep(for: .milliseconds(320))
            completion()
            return
        }

        withAnimation(.easeOut(duration: 0.52)) {
            appeared = true
        }

        withAnimation(
            .easeInOut(duration: 1.0)
            .repeatForever(autoreverses: true)
        ) {
            corePulse = true
        }

        withAnimation(.linear(duration: 1.55)) {
            sweep = true
        }

        let milestones: [(Int, CGFloat, Int)] = [
            (240, 0.18, 0),
            (260, 0.39, 1),
            (280, 0.61, 2),
            (320, 0.82, 3)
        ]

        for item in milestones {
            try? await Task.sleep(for: .milliseconds(item.0))

            withAnimation(.easeInOut(duration: 0.30)) {
                statusIndex = item.2
                progress = item.1
            }
        }

        try? await Task.sleep(for: .milliseconds(280))

        withAnimation(.easeOut(duration: 0.34)) {
            progress = 1
        }

        try? await Task.sleep(for: .milliseconds(220))
        completion()
    }
}
