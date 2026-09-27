import SwiftUI

struct ServersView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var search = ""
    @State private var favoritesOnly = false
    @State private var sortByPing = true

    private var filteredServers: [VO1DServer] {
        var result = model.servers

        if favoritesOnly {
            result = result.filter { model.isFavorite($0) }
        }

        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(query) ||
                $0.code.localizedCaseInsensitiveContains(query)
            }
        }

        if sortByPing {
            result.sort {
                pingValue($0) < pingValue($1)
            }
        }

        return result
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 18)
                    .padding(.top, 6)

                controls
                    .padding(.horizontal, 18)
                    .padding(.top, 14)

                fastestCard
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredServers) { server in
                            serverCard(server)
                        }

                        if filteredServers.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white.opacity(0.25))

                                Text("No servers found")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .padding(.top, 48)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .animation(.snappy(duration: 0.25), value: favoritesOnly)
        .animation(.snappy(duration: 0.25), value: sortByPing)
    }

    private var topBar: some View {
        ZStack {
            VStack(spacing: 2) {
                Text("Servers")
                    .font(.system(size: 17, weight: .semibold))

                Text("\(model.servers.count) locations")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.33))
            }

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(ScaleButtonStyle())

                Spacer()

                Button {
                    Task { await model.refreshPingsNow() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 34, height: 34)
                        .rotationEffect(.degrees(model.isRefreshingPings ? 360 : 0))
                        .animation(
                            model.isRefreshingPings
                            ? .linear(duration: 0.75).repeatForever(autoreverses: false)
                            : .default,
                            value: model.isRefreshingPings
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .frame(height: 44)
    }

    private var controls: some View {
        VStack(spacing: 10) {
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
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 11)
                    .fill(.white.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(.white.opacity(0.07), lineWidth: 1)
            )

            HStack(spacing: 8) {
                filterButton(
                    title: favoritesOnly ? "FAVORITES" : "ALL",
                    icon: favoritesOnly ? "star.fill" : "globe",
                    active: favoritesOnly
                ) {
                    favoritesOnly.toggle()
                }

                filterButton(
                    title: "PING",
                    icon: sortByPing ? "arrow.up.arrow.down" : "line.3.horizontal",
                    active: sortByPing
                ) {
                    sortByPing.toggle()
                }

                Spacer()
            }
        }
    }

    private func filterButton(
        title: String,
        icon: String,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(active ? 0.92 : 0.48))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(.white.opacity(active ? 0.10 : 0.045))
            )
            .overlay(
                Capsule()
                    .stroke(.white.opacity(active ? 0.14 : 0.06), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var fastestCard: some View {
        Group {
            if let server = model.fastestServer {
                Button {
                    Task {
                        await model.select(server)
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.08))
                                .frame(width: 38, height: 38)

                            Image(systemName: "bolt.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("FASTEST LOCATION")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(.white.opacity(0.34))

                            Text("\(server.flag)  \(server.name)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        Spacer()

                        Text(pingText(for: server))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(pingColor(for: server))

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 58)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white.opacity(0.055))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.white.opacity(0.075), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.98))
            }
        }
    }

    private func serverCard(_ server: VO1DServer) -> some View {
        let selected = model.selectedServer?.code == server.code
        let favorite = model.isFavorite(server)

        return HStack(spacing: 12) {
            Button {
                Task {
                    await model.select(server)
                    dismiss()
                }
            } label: {
                HStack(spacing: 12) {
                    Text(server.flag)
                        .font(.system(size: 23))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(server.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)

                        HStack(spacing: 6) {
                            Text(server.code)
                            Text("•")
                            Text(server.protocolName)
                        }
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.28))
                    }

                    Spacer()

                    Text(pingText(for: server))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(pingColor(for: server))
                        .contentTransition(.numericText())

                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(selected ? .white : .white.opacity(0.18))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    model.toggleFavorite(server)
                }
            } label: {
                Image(systemName: favorite ? "star.fill" : "star")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(favorite ? 0.78 : 0.22))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 12)
        .frame(height: 62)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(selected ? 0.075 : 0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(selected ? 0.13 : 0.055), lineWidth: 1)
        )
    }

    private func pingValue(_ server: VO1DServer) -> Int {
        guard let wrapped = model.pingByCode[server.code],
              let ping = wrapped else {
            return Int.max
        }
        return ping
    }

    private func pingText(for server: VO1DServer) -> String {
        let value = pingValue(server)
        return value == Int.max ? "— ms" : "\(value) ms"
    }

    private func pingColor(for server: VO1DServer) -> Color {
        let ping = pingValue(server)
        if ping == Int.max { return .white.opacity(0.30) }
        if ping < 70 { return Color(red: 0.38, green: 0.86, blue: 0.46) }
        if ping < 110 { return Color(red: 0.92, green: 0.78, blue: 0.33) }
        return Color(red: 0.95, green: 0.38, blue: 0.38)
    }
}
