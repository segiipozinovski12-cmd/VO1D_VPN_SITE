import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var model: AppViewModel
    @State private var key = ""

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            VStack(spacing: 8) {
                Text("VO1D_VPN")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .tracking(3)

                Text("PRIVATE / SECURE / BORDERLESS")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.gray)
                    .tracking(2)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("ACCESS KEY")
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(.gray)

                TextField("VOID-XXXX-XXXX-XXXX-XXXX", text: $key)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .padding(16)
                    .background(
                        Color.white.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12))
                    )
            }

            Button {
                Task {
                    await model.activate(key: key)
                }
            } label: {
                HStack {
                    if model.isActivating {
                        ProgressView()
                            .tint(.black)
                    }

                    Text(model.isActivating ? "ACTIVATING…" : "ACTIVATE")
                        .font(.headline.monospaced().weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(.black)
                .background(
                    .white,
                    in: RoundedRectangle(cornerRadius: 16)
                )
            }
            .disabled(model.isActivating)

            if let error = model.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }

            Text("Ключ выдаётся в Telegram после активации подписки.")
                .font(.footnote)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [.black, Color(white: 0.08), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}
