import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var model: AppViewModel
    @State private var key = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 72)

                Text("VO1D_VPN")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(.white)

                Spacer()

                VStack(spacing: 18) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 43, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)

                    Text("Enter Your Key")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Enter the key you received from our Telegram bot.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.48))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    TextField("VOID-XXXX-XXXX-XXXX-XXXX", text: $key)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(Color.white.opacity(0.055))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(.white.opacity(0.14), lineWidth: 1)
                        )

                    Button {
                        Task { await model.activate(key: key) }
                    } label: {
                        HStack(spacing: 8) {
                            if model.isActivating {
                                ProgressView()
                                    .tint(.black)
                            }

                            Text(model.isActivating ? "Activating..." : "Activate")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(.white, in: RoundedRectangle(cornerRadius: 9))
                    }
                    .disabled(model.isActivating)
                }
                .padding(.horizontal, 24)
                .padding(.top, 34)

                if let error = model.errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 26)
                        .padding(.top, 14)
                }

                Text("No key? Get it in our Telegram bot.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.38))
                    .padding(.top, 17)

                Spacer()
                Spacer()
            }
        }
    }
}
