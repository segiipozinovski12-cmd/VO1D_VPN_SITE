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

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                topBar
                    .referenceReveal(appeared, delay: 0.00, reduceMotion: reduceMotion)

                serverCard
                    .referenceReveal(appeared, delay: 0.05, reduceMotion: reduceMotion)

                connectionHero
                    .referenceReveal(appeared, delay: 0.10, reduceMotion: reduceMotion)

                ReferenceTrafficGrid()
                    .referenceReveal(appeared, delay: 0.16, reduceMotion: reduceMotion)

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
        .background {
            ZStack {
                ReferenceBackdrop()

                RadialGradient(
                    colors: [
                        .white.opacity(
                            model.isConnected
                            ? 0.055
                            : model.phase.isBusy
                                ? 0.038
                                : 0.016
                        ),
                        .clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.43),
                    startRadius: 0,
                    endRadius: 330
                )
                .animation(
                    reduceMotion
                    ? nil
                    : .easeInOut(duration: 0.45),
                    value: model.phase
                )
            }
            .ignoresSafeArea()
        }
        .onAppear {
            guard !appeared else { return }

            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.44)) {
                    appeared = true
                }

                withAnimation(
                    .easeInOut(duration: 2.8)
                    .repeatForever(autoreverses: true)
                ) {
                    pulse = true
                }
            }
        }
        .accessibilityIdentifier("home.screen")
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
                        .strokeBorder(.white.opacity(0.10), lineWidth: 0.8)
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
            ReferenceGlassCard(radius: 22) {
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
        VStack(spacing: 0) {
            ZStack {
                ReferenceVortex(
                    active: model.isConnected,
                    busy: model.phase.isBusy
                )
                .frame(width: 302, height: 302)
                .scaleEffect(pulse && model.isConnected ? 1.015 : 0.995)

                Circle()
                    .fill(Color.black.opacity(0.46))
                    .frame(width: 104, height: 104)
                    .background(
                        .ultraThinMaterial,
                        in: Circle()
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.22),
                                        .white.opacity(0.055)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.9
                            )
                    }
                    .shadow(color: .black.opacity(0.55), radius: 18)

                Button {
                    model.toggleConnection()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.035))
                            .frame(width: 70, height: 70)
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        .white.opacity(
                                            model.isConnected
                                            ? 0.18
                                            : 0.10
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
                                    size: model.isConnected ? 18 : 21,
                                    weight: .medium
                                )
                            )
                            .foregroundStyle(.white.opacity(0.94))
                        }
                    }
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.92))
                .accessibilityIdentifier("connection.toggle")

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
                        .foregroundStyle(.white.opacity(0.92))
                        .contentTransition(.opacity)

                    Text(
                        model.isConnected
                        ? session.stats.durationText
                        : statusSubtitle
                    )
                    .font(.system(size: 11, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.44))
                    .contentTransition(.numericText())
                }
                .frame(height: 258)
                .allowsHitTesting(false)
            }
            .frame(height: 308)
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
            .offset(y: visible || reduceMotion ? 0 : 12)
            .scaleEffect(visible || reduceMotion ? 1 : 0.988)
            .animation(
                reduceMotion
                ? nil
                : .easeOut(duration: 0.44).delay(delay),
                value: visible
            )
    }
}
