import SwiftUI

struct ServersView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filteredServers: [VO1DServer] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.servers }

        return model.servers.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.code.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 18)
                    .padding(.top, 6)

                searchField
                    .padding(.horizontal, 18)
                    .padding(.top, 16)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredServers) { server in
                            Button {
                                Task {
                                    await model.select(server)
                                    dismiss()
                                }
                            } label: {
                                row(server)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .overlay(.white.opacity(0.065))
                                .padding(.leading, 52)
                        }

                        if filteredServers.isEmpty {
                            Text("No servers found")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.4))
                                .padding(.top, 42)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                }
                .scrollIndicators(.hidden)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        ZStack {
            Text("Servers")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                }

                Spacer()
            }
        }
        .frame(height: 38)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.34))

            TextField("Search country...", text: $search)
                .font(.system(size: 13))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(.white.opacity(0.06))
        )
    }

    private func row(_ server: VO1DServer) -> some View {
        let selected = model.selectedServer?.code == server.code

        return HStack(spacing: 12) {
            Text(server.flag)
                .font(.system(size: 22))

            Text(server.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)

            Spacer()

            Text(pingText(for: server))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(pingColor(for: server))

            ZStack {
                Circle()
                    .stroke(.white.opacity(selected ? 0.85 : 0.28), lineWidth: 1.2)
                    .frame(width: 15, height: 15)

                if selected {
                    Circle()
                        .fill(.white)
                        .frame(width: 7, height: 7)
                }
            }
        }
        .frame(height: 44)
        .contentShape(Rectangle())
    }

    private func pingText(for server: VO1DServer) -> String {
        if let wrapped = model.pingByCode[server.code], let ping = wrapped {
            return "\(ping) ms"
        }
        return "— ms"
    }

    private func pingColor(for server: VO1DServer) -> Color {
        guard let wrapped = model.pingByCode[server.code], let ping = wrapped else {
            return .white.opacity(0.34)
        }

        if ping < 70 { return Color(red: 0.38, green: 0.86, blue: 0.46) }
        if ping < 110 { return Color(red: 0.92, green: 0.78, blue: 0.33) }
        return Color(red: 0.95, green: 0.38, blue: 0.38)
    }
}
