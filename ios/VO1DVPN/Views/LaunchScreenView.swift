import SwiftUI

struct LaunchScreenView: View {
    @Environment(\.vo1dReduceMotion) private var reduceMotion

    @State private var appeared = false
    @State private var progress: CGFloat = 0.04
    @State private var statusIndex = 0
    @State private var sweep = false

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
                ReferenceBackdrop()

                VStack(spacing: 0) {
                    topPrivacy
                        .padding(.horizontal, 28)
                        .padding(.top, 30)
                        .opacity(appeared ? 1 : 0)

                    Spacer(minLength: 0)

                    planetStage(size: proxy.size)
                        .frame(height: proxy.size.height * 0.66)

                    Spacer(minLength: 0)

                    terminalFooter
                        .padding(.horizontal, 28)
                        .padding(.bottom, 26)
                }

                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.055),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 110)
                .offset(y: sweep ? proxy.size.height * 0.65 : -proxy.size.height * 0.55)
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
            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                privacyLine("PRIVACY")
                privacyLine("SECURE")
                privacyLine("ANONYMITY")
                privacyLine("FREEDOM")
            }
        }
    }

    private func privacyLine(_ text: String) -> some View {
        HStack(spacing: 11) {
            Rectangle()
                .fill(.white.opacity(0.55))
                .frame(width: 7, height: 1)

            Text(text)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(.white.opacity(0.64))
        }
    }

    private func planetStage(size: CGSize) -> some View {
        ZStack {
            ReferencePlanet(
                diameter: min(size.width * 1.72, 690),
                rotation: -17,
                glow: appeared ? 0.30 : 0.07
            )
            .offset(
                x: -size.width * 0.30,
                y: size.height * 0.055
            )
            .scaleEffect(appeared || reduceMotion ? 1 : 0.90)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 10) {
                Spacer()

                VO1DBrandLockup()
                    .shadow(color: .black.opacity(0.98), radius: 18)
                    .shadow(color: .white.opacity(0.22), radius: 12)
                    .padding(.bottom, size.height * 0.020)
            }
            .padding(.bottom, 18)
            .opacity(appeared ? 1 : 0)
        }
    }

    private var terminalFooter: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(statuses.enumerated()), id: \.offset) { index, status in
                    Text(status)
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(
                            index <= statusIndex
                            ? .white.opacity(0.58)
                            : .white.opacity(0.16)
                        )
                        .opacity(index <= statusIndex ? 1 : 0.36)
                }
            }

            HStack(spacing: 12) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.12))
                            .frame(height: 4)

                        Capsule()
                            .fill(.white)
                            .frame(
                                width: max(
                                    8,
                                    proxy.size.width * min(1, progress)
                                ),
                                height: 4
                            )
                            .shadow(color: .white.opacity(0.55), radius: 6)
                    }
                }
                .frame(height: 4)

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 38, alignment: .trailing)
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
            try? await Task.sleep(for: .milliseconds(350))
            completion()
            return
        }

        withAnimation(.easeOut(duration: 0.70)) {
            appeared = true
        }

        withAnimation(.linear(duration: 1.45)) {
            sweep = true
        }

        let milestones: [(Int, CGFloat, Int)] = [
            (230, 0.18, 0),
            (250, 0.34, 1),
            (280, 0.52, 2),
            (310, 0.68, 3)
        ]

        for item in milestones {
            try? await Task.sleep(for: .milliseconds(item.0))

            withAnimation(.easeInOut(duration: 0.34)) {
                statusIndex = item.2
                progress = item.1
            }
        }

        try? await Task.sleep(for: .milliseconds(310))

        withAnimation(.easeOut(duration: 0.38)) {
            progress = 1
        }

        try? await Task.sleep(for: .milliseconds(240))
        completion()
    }
}
