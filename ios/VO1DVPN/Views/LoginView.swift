import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var model: AppViewModel
    @State private var key = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("VO1D_VPN").font(.system(size: 23, weight: .bold, design: .monospaced)).tracking(1)
                    .padding(.top, 36)
                Spacer(minLength: 52)
                Image(systemName: model.isDemoMode ? "play.circle" : "key.horizontal")
                    .font(.system(size: 48, weight: .ultraLight)).frame(width: 88, height: 88).vo1dSurface()
                VStack(alignment: .leading, spacing: 14) {
                    Eyebrow(text: model.isDemoMode ? "DEMO / SIMULATOR" : "YOUR PRIVATE CONNECTION")
                    Text(model.isDemoMode ? "Take a look\ninside VO1D." : "Your key.\nYour connection.")
                        .font(.system(size: 39, weight: .medium)).tracking(-1.5)
                    Text(model.isDemoMode ? "Explore the app with local simulated connections. No access key required." : "Enter your access key or the full activation string from the VO1D bot.")
                        .font(.subheadline).foregroundStyle(VO1DStyle.secondary)
                }
                if !model.isDemoMode {
                    TextField("VOID-… or VO1D1.…", text: $key)
                        .font(VO1DStyle.mono(13)).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(18).vo1dSurface(radius: 16).accessibilityIdentifier("login.key")
                }
                PrimaryButton(title: model.isActivating ? "Activating…" : model.isDemoMode ? "Enter demo" : "Activate connection") {
                    Task { await model.activate(key: key) }
                }
                .disabled(model.isActivating || (!model.isDemoMode && key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                .accessibilityIdentifier("login.activate")
                if let error = model.errorMessage { Text(error).font(.caption).foregroundStyle(VO1DStyle.red) }
                if !model.isDemoMode {
                    Link(destination: URL(string: "https://t.me/VO1D_VPNbot")!) {
                        Label("Get an access key", systemImage: "arrow.up.right").font(.subheadline)
                    }.buttonStyle(ScaleButtonStyle())
                }
                Spacer(minLength: 32)
            }.padding(26).frame(maxWidth: 520)
        }.frame(maxWidth: .infinity).background(VO1DStyle.background).scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("login.screen")
    }
}
