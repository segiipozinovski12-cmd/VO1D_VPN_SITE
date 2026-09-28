import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppViewModel
    @EnvironmentObject private var pings: PingStore
    @EnvironmentObject private var session: SessionMonitor
    @Environment(\.vo1dReduceMotion) private var reduceMotion

    let openLocations: () -> Void
    let openProfile: () -> Void

    @State private var appeared = false
    @State private var pulse = false

    @State private var pressDown = false
    @State private var burstOne = false
    @State private var burstTwo = false
    @State private var flash = false
    @State private var particleBurst = false
    @State private var pressSpin = 0.0

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                topBar
                    .referenceReveal(
                        appeared,
                        delay: 0.00,
                        reduceMotion: reduceMotion
                    )

                serverCard
                    .referenceReveal(
                        appeared,
                        delay: 0.05,
                        reduceMotion: reduceMotion
                    )

                connectionHero
                    .referenceReveal(
                        appeared,
                        delay: 0.10,
                        reduceMotion: reduceMotion
                    )

                ReferenceTrafficGrid()
                    .referenceReveal(
                        appeared,
                        delay: 0.16,
                        reduceMotion: reduceMotion
                    )

                if let error = model.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(VO1DStyle.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .background { homeBackdrop }
        .onAppear {
            guard !appeared else { return }

            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.44)) {
                    appeared = true
                }

                withAnimation(
                    .easeInOut(duration: 2.6)
                    .repeatForever(autoreverses: true)
                ) {
                    pulse = true
                }
            }
        }
        .accessibilityIdentifier("home.screen")
    }

    private var homeBackdrop: some View {
        ZStack {
            ReferenceBackdrop()

            RadialGradient(
                colors: [
                    VO1DStyle.frost.opacity(
                        model.isConnected ? 0.095 : 0.030
                    ),
                    VO1DStyle.steel.opacity(
                        model.isConnected ? 0.040 : 0.015
                    ),
                    .clear
                ],
                center: UnitPoint(x: 0.50, y: 0.40),
                startRadius: 0,
                endRadius: 360
            )

            RadialGradient(
                colors: [
                    .white.opacity(
                        flash
                        ? 0.12
                        : model.phase.isBusy
                            ? 0.055
                            : 0.018
                    ),
                    .clear
                ],
                center: UnitPoint(x: 0.50, y: 0.42),
                startRadius: 0,
                endRadius: 250
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.30),
                value: flash
            )
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        ZStack {
            HStack {
                referenceCircleButton(
                    icon: "line.3.horizontal",
                    label: "Open locations",
                    action: openLocations
                )

                Spacer()

                referenceCircleButton(
                    icon: "gearshape",
                    label: "Open profile",
                    action: openProfile
                )
            }

            VO1DBrandLockup(compact: true)
        }
        .frame(height: 54)
    }

    private func referenceCircleButton(
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 38, height: 38)
                .background {
                    Circle()
                        .fill(Color.white.opacity(0.045))
                        .background(.ultraThinMaterial, in: Circle())
                }
                .overlay {
                    Circle()
                        .strokeBorder(
                            .white.opacity(0.10),
                            lineWidth: 0.8
                        )
                }
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.92))
        .accessibilityLabel(label)
    }

    private var serverCard: some View {
        let server = model.activeServer ?? model.selectedServer
        let ping = server.flatMap { pings.values[$0.code] }

        return Button {
            openLocations()
        } label: {
            ReferenceGlassCard(
                radius: 22,
                highlighted: model.isConnected
            ) {
                HStack(spacing: 13) {
                    Text(server?.flag ?? "◉")
                        .font(.system(size: 27))
                        .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(server?.name ?? "Choose location")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(server?.label ?? "Select a VO1D route")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.42))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    Text(ping.map { "\($0) ms" } ?? "— ms")
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.60))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.62))
                }
                .padding(.horizontal, 16)
                .frame(height: 70)
            }
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.985))
        .accessibilityIdentifier("home.server")
    }

    private var connectionHero: some View {
        ZStack {
            ReferenceVortex(
                active: model.isConnected || flash,
                busy: model.phase.isBusy || flash
            )
            .frame(width: 356, height: 356)
            .scaleEffect(
                model.isConnected
                ? (pulse ? 1.025 : 0.990)
                : flash
                    ? 1.045
                    : 0.995
            )
            .animation(
                reduceMotion
                ? nil
                : .spring(
                    response: 0.48,
                    dampingFraction: 0.78
                ),
                value: flash
            )

            connectionShockwaves
            connectControl

            VStack(spacing: 4) {
                Spacer()

                Text(statusTitle)
                    .font(
                        .system(
                            size: 12,
                            weight: .semibold,
                            design: .monospaced
                        )
                    )
                    .tracking(3.0)
                    .foregroundStyle(.white.opacity(0.95))
                    .contentTransition(.opacity)
                    .accessibilityIdentifier("connection.status")

                Text(
                    model.isConnected
                    ? session.stats.durationText
                    : statusSubtitle
                )
                .font(.system(size: 11, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.46))
                .contentTransition(.numericText())
            }
            .frame(height: 286)
            .allowsHitTesting(false)
        }
        .frame(height: 356)
    }

    private var connectionShockwaves: some View {
        ZStack {
            Circle()
                .stroke(
                    .white.opacity(burstOne ? 0 : 0.58),
                    lineWidth: burstOne ? 0.7 : 2.0
                )
                .frame(width: 104, height: 104)
                .scaleEffect(burstOne ? 2.65 : 0.78)
                .blur(radius: burstOne ? 2.5 : 0)

            Circle()
                .stroke(
                    VO1DStyle.frost.opacity(burstTwo ? 0 : 0.54),
                    lineWidth: burstTwo ? 0.6 : 1.9
                )
                .frame(width: 122, height: 122)
                .scaleEffect(burstTwo ? 2.34 : 0.80)
                .blur(radius: burstTwo ? 4.4 : 0.9)

            Circle()
                .stroke(
                    VO1DStyle.chrome.opacity(
                        flash ? 0.34 : 0.08
                    ),
                    lineWidth: 1.0
                )
                .frame(width: 146, height: 146)
                .scaleEffect(
                    flash
                    ? 1.42
                    : model.isConnected
                        ? (pulse ? 1.04 : 0.97)
                        : 0.91
                )
                .blur(radius: flash ? 2.8 : 0.8)
                .opacity(model.isConnected || flash ? 1 : 0.42)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(flash ? 0.14 : 0),
                            VO1DStyle.frost.opacity(flash ? 0.06 : 0),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 88
                    )
                )
                .frame(width: 190, height: 190)
                .scaleEffect(flash ? 1.25 : 0.55)
                .blur(radius: flash ? 8 : 2)

            if particleBurst {
                ForEach(0..<20, id: \.self) { index in
                    let angle =
                        Double(index) /
                        20.0 *
                        Double.pi *
                        2

                    let distance =
                        CGFloat(
                            94 +
                            (index % 5) * 11
                        )

                    Circle()
                        .fill(.white)
                        .frame(
                            width: index.isMultiple(of: 4) ? 3.0 : 1.8,
                            height: index.isMultiple(of: 4) ? 3.0 : 1.8
                        )
                        .shadow(
                            color: .white.opacity(0.75),
                            radius: 4
                        )
                        .offset(
                            x: CGFloat(cos(angle)) * distance,
                            y: CGFloat(sin(angle)) * distance
                        )
                        .opacity(flash ? 0.92 : 0)
                        .scaleEffect(flash ? 1 : 0.2)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var connectControl: some View {
        Button {
            triggerConnectionInteraction()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(
                                    model.isConnected ? 0.16 : 0.075
                                ),
                                VO1DStyle.frost.opacity(
                                    model.isConnected ? 0.055 : 0.018
                                ),
                                VO1DStyle.graphite.opacity(0.90),
                                .black.opacity(0.97)
                            ],
                            center: UnitPoint(x: 0.40, y: 0.34),
                            startRadius: 0,
                            endRadius: 72
                        )
                    )
                    .frame(width: 122, height: 122)
                    .background(
                        .ultraThinMaterial,
                        in: Circle()
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(
                                            model.isConnected ? 0.62 : 0.30
                                        ),
                                        VO1DStyle.chrome.opacity(
                                            model.isConnected ? 0.18 : 0.06
                                        ),
                                        .white.opacity(0.045),
                                        VO1DStyle.frost.opacity(
                                            model.isConnected ? 0.28 : 0.09
                                        )
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.0
                            )
                    }
                    .shadow(
                        color: .white.opacity(
                            model.isConnected
                            ? (pulse ? 0.25 : 0.16)
                            : flash ? 0.38 : 0.05
                        ),
                        radius: model.isConnected ? 24 : flash ? 30 : 12
                    )
                    .shadow(
                        color: .black.opacity(0.72),
                        radius: 20,
                        y: 10
                    )

                Circle()
                    .trim(from: 0.04, to: 0.34)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(
                                    model.isConnected || model.phase.isBusy
                                    ? 0.94
                                    : 0.52
                                ),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(
                            lineWidth: 1.7,
                            lineCap: .round
                        )
                    )
                    .frame(width: 108, height: 108)
                    .rotationEffect(.degrees(pressSpin))

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.14),
                                .white.opacity(0.035),
                                .black.opacity(0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 78, height: 78)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                .white.opacity(
                                    model.isConnected ? 0.24 : 0.13
                                ),
                                lineWidth: 0.8
                            )
                    }

                if model.phase.isBusy {
                    ProgressView()
                        .tint(.white)
                        .controlSize(.small)
                } else {
                    Image(
                        systemName:
                            model.isConnected
                            ? "stop.fill"
                            : "power"
                    )
                    .font(
                        .system(
                            size: model.isConnected ? 18 : 22,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(.white.opacity(0.98))
                    .shadow(
                        color: .white.opacity(
                            model.isConnected ? 0.38 : 0.16
                        ),
                        radius: 6
                    )
                }
            }
            .scaleEffect(pressDown ? 0.88 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("connection.control")
        .accessibilityValue(statusTitle)
    }

    private func triggerConnectionInteraction() {
        Haptics.play(
            .selection,
            enabled: model.preferences.haptics
        )

        guard !reduceMotion else {
            model.toggleConnection()
            return
        }

        particleBurst = true
        burstOne = false
        burstTwo = false
        flash = false

        withAnimation(
            .easeIn(duration: 0.10)
        ) {
            pressDown = true
        }

        withAnimation(
            .spring(
                response: 0.40,
                dampingFraction: 0.52
            )
            .delay(0.08)
        ) {
            pressDown = false
            flash = true
            burstOne = true
            pressSpin += 220
        }

        withAnimation(
            .easeOut(duration: 0.72)
            .delay(0.14)
        ) {
            burstTwo = true
        }

        Task { @MainActor in
            try? await Task.sleep(
                for: .milliseconds(115)
            )

            model.toggleConnection()

            try? await Task.sleep(
                for: .milliseconds(430)
            )

            withAnimation(.easeOut(duration: 0.30)) {
                flash = false
            }

            try? await Task.sleep(
                for: .milliseconds(420)
            )

            withAnimation(nil) {
                burstOne = false
                burstTwo = false
                particleBurst = false
            }
        }
    }

    private var statusTitle: String {
        if model.isConnected {
            return "CONNECTED"
        }

        if model.phase.isBusy {
            return "CONNECTING"
        }

        if model.phase == .failed {
            return "FAILED"
        }

        return "READY"
    }

    private var statusSubtitle: String {
        switch model.phase {
        case .preparing:
            return "PREPARING"
        case .routing, .switching:
            return "ROUTING"
        case .securing:
            return "SECURING"
        case .disconnecting:
            return "CLOSING"
        case .failed:
            return "TRY AGAIN"
        case .ready, .connected:
            return "TAP TO CONNECT"
        }
    }
}

private extension View {
    func referenceReveal(
        _ visible: Bool,
        delay: Double,
        reduceMotion: Bool
    ) -> some View {
        opacity(visible ? 1 : 0)
            .offset(
                y: visible || reduceMotion ? 0 : 12
            )
            .scaleEffect(
                visible || reduceMotion ? 1 : 0.988
            )
            .animation(
                reduceMotion
                ? nil
                : .easeOut(duration: 0.44).delay(delay),
                value: visible
            )
    }
}
