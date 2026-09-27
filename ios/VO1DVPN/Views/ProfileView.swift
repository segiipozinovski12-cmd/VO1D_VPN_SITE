import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Nickname", text: $model.nickname)
                                .font(.headline.monospaced().weight(.bold))

                            Text("ID \(model.account?.id ?? 0)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 5)
                }

                Section("CONNECTION") {
                    Toggle("Auto-connect", isOn: $model.autoConnect)
                    Toggle("Kill Switch", isOn: $model.killSwitch)
                }

                Section("SUBSCRIPTION") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(model.account?.active == true ? "ACTIVE" : "INACTIVE")
                            .font(.caption.monospaced().weight(.bold))
                    }

                    HStack {
                        Text("Remaining")
                        Spacer()
                        Text(remainingText)
                            .font(.caption.monospaced())
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            await model.logout()
                            dismiss()
                        }
                    } label: {
                        Text("LOG OUT")
                            .font(.body.monospaced().weight(.bold))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("PROFILE")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }

    private var remainingText: String {
        let seconds = max(0, model.account?.remainingSeconds ?? 0)
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        return days > 0 ? "\(days)d \(hours)h" : "\(hours)h"
    }
}
