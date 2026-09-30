import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.vo1dReduceMotion) private var reduceMotion

    @State private var key = ""
    @State private var breathe = false
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack {
                    Text("VO1D_VPN")
                        .font(.system(size: 23, weight: .bold, design: .monospaced))
                        .tracking(1)

                    Spacer()

                    StatusPill(
                        text: model.isDemoMode ? "DEMO" : "ACCESS",
                        connected: false
                    )
                }
                .padding(.top, 36)
                .vo1dReveal(appeared, reduceMotion: reduceMotion, delay: 0.00)

                Spacer(minLength: 48)

                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(VO1DStyle.ice.opacity(breathe ? 0.04 : 0.18), lineWidth: 1)
                        .frame(width: breathe ? 104 : 92, height: breathe ? 104 : 92)

                    Image(systemName: model.isDemoMode ? "play.circle" : "key.horizontal")
                        .font(.system(size: 45, weight: .ultraLight))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                        .frame(width: 88, height: 88)
                        .vo1dSurface(highlighted: true, radius: 26)
                }
                .frame(width: 108, height: 108)
                .vo1dReveal(appeared, reduceMotion: reduceMotion, delay: 0.06)

                VStack(alignment: .leading, spacing: 14) {
                    Eyebrow(text: model.isDemoMode ? "DEMO / SIMULATOR" : "YOUR PRIVATE CONNECTION")

                    Text(model.isDemoMode ? "Take a look\ninside VO1D." : "Your key.\nYour connection.")
                        .font(.system(size: 39, weight: .medium))
                        .tracking(-1.5)

                    Text(
                        model.isDemoMode
                        ? "Explore the app with local simulated connections. No access key required."
                        : "Enter your access key or the full activation string from the VO1D bot."
                    )
                    .font(.subheadline)
                    .foregroundStyle(VO1DStyle.secondary)
                }
                .vo1dReveal(appeared, reduceMotion: reduceMotion, delay: 0.11)

                if !model.isDemoMode {
                    HStack(spacing: 12) {
                        Image(systemName: "key")
                            .foregroundStyle(VO1DStyle.ice)

                        TextField("VOID-… or VO1D1.…", text: $key)
                            .font(VO1DStyle.mono(13))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("login.key")
                    }
                    .padding(18)
                    .vo1dSurface(radius: 16)
                    .vo1dReveal(appeared, reduceMotion: reduceMotion, delay: 0.15)
                }

                PrimaryButton(
                    title: model.isActivating
                        ? "Activating…"
                        : model.isDemoMode
                            ? "Enter demo"
                            : "Activate connection"
                ) {
                    Task { await model.activate(key: key) }
                }
                .disabled(
                    model.isActivating ||
                    (!model.isDemoMode && key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                )
                .accessibilityIdentifier("login.activate")
                .vo1dReveal(appeared, reduceMotion: reduceMotion, delay: 0.19)

                if let error = model.errorMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                        Text(error)
                    }
                    .font(.caption)
                    .foregroundStyle(VO1DStyle.red)
                    .padding(14)
                    .vo1dSurface(radius: 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if !model.isDemoMode {
                    Link(destination: URL(string: "https://t.me/VO1D_VPNbot")!) {
                        HStack {
                            Label("Get an access key", systemImage: "paperplane")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .foregroundStyle(.white)
                        .padding(16)
                        .vo1dSurface(radius: 16)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .vo1dReveal(appeared, reduceMotion: reduceMotion, delay: 0.23)
                }

                Spacer(minLength: 32)
            }
            .padding(26)
            .frame(maxWidth: 520)
        }
        .frame(maxWidth: .infinity)
        .background { DeepSpaceBackdrop().ignoresSafeArea() }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            if reduceMotion {
                appeared = true
                return
            }

            withAnimation(.easeOut(duration: 0.46)) {
                appeared = true
            }

            withAnimation(
                .easeInOut(duration: 2.8)
                .repeatForever(autoreverses: true)
            ) {
                breathe = true
            }
        }
        .accessibilityIdentifier("login.screen")
    }
}
