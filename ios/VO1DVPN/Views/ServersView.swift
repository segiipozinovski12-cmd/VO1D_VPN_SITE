import SwiftUI

struct ServersView: View {
    @EnvironmentObject private var model: AppViewModel
    @EnvironmentObject private var pings: PingStore
    @EnvironmentObject private var preferences: Preferences
    @Environment(\.vo1dReduceMotion) private var reduceMotion

    @State private var search = ""
    @State private var filter: Filter = .all
    @State private var appeared = false

    enum Filter: String, CaseIterable {
        case all = "ALL"
        case favorites = "FAVORITES"
        case lowest = "LOWEST PING"
    }

    private var filtered: [VO1DServer] {
        let query = search
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let matching = model.servers.filter { server in
            (filter != .favorites ||
             model.favoriteCodes.contains(server.code)) &&
            (
                query.isEmpty ||
                [server.name, server.code, server.protocolName, server.label]
                    .contains {
                        $0.localizedCaseInsensitiveContains(query)
                    }
            )
        }

        return filter == .lowest
            ? ServerRanking.sorted(matching, pings: pings.values)
            : matching.sorted { $0.name < $1.name }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                brandHeader
                    .locationReveal(appeared, delay: 0.00, reduceMotion: reduceMotion)

                titleBlock
                    .locationReveal(appeared, delay: 0.03, reduceMotion: reduceMotion)

                searchField
                    .locationReveal(appeared, delay: 0.06, reduceMotion: reduceMotion)

                fastestCard
                    .locationReveal(appeared, delay: 0.09, reduceMotion: reduceMotion)

                filterBar
                    .locationReveal(appeared, delay: 0.12, reduceMotion: reduceMotion)

                HStack {
                    Text("\(filtered.count) LOCATIONS")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(1.7)
                        .foregroundStyle(.white.opacity(0.40))

                    Spacer()

                    Text(pings.isRefreshing ? "MEASURING" : "LIVE LATENCY")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(.white.opacity(0.34))
                }
                .padding(.horizontal, 2)
                .locationReveal(appeared, delay: 0.15, reduceMotion: reduceMotion)

                LazyVStack(spacing: 10) {
                    ForEach(filtered) { server in
                        ServerCard(
                            server: server,
                            ping: pings.values[server.code],
                            selected: model.selectedServer?.code == server.code,
                            favorite: model.favoriteCodes.contains(server.code),
                            compact: preferences.compactServers,
                            showPing: preferences.livePing,
                            busy: model.phase.isBusy,
                            select: { model.select(server) },
                            toggleFavorite: { model.toggleFavorite(server) }
                        )
                    }

                    if filtered.isEmpty {
                        ReferenceGlassCard(radius: 20) {
                            VStack(spacing: 11) {
                                Image(systemName: "location.slash")
                                    .font(.system(size: 26, weight: .ultraLight))
                                    .foregroundStyle(.white.opacity(0.55))

                                Text(
                                    filter == .favorites && search.isEmpty
                                    ? "No favorites yet"
                                    : "No matching locations"
                                )
                                .font(.system(size: 16, weight: .semibold))

                                Text(
                                    filter == .favorites && search.isEmpty
                                    ? "Save a location with the star button."
                                    : "Try another country or location code."
                                )
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.40))
                                .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                        }
                    }
                }
                .locationReveal(appeared, delay: 0.18, reduceMotion: reduceMotion)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            guard !appeared else { return }

            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.42)) {
                    appeared = true
                }
            }
        }
        .accessibilityIdentifier("servers.screen")
    }

    private var brandHeader: some View {
        HStack {
            VO1DBrandLockup(compact: true)

            Spacer()

            Button {
                Haptics.play(.selection, enabled: preferences.haptics)
                Task { await pings.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .rotationEffect(
                        .degrees(pings.isRefreshing ? 360 : 0)
                    )
                    .animation(
                        pings.isRefreshing && !reduceMotion
                        ? .linear(duration: 0.8)
                          .repeatForever(autoreverses: false)
                        : .easeOut(duration: 0.16),
                        value: pings.isRefreshing
                    )
                    .frame(width: 38, height: 38)
                    .background(
                        Color.white.opacity(0.045),
                        in: Circle()
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                .white.opacity(0.10),
                                lineWidth: 0.8
                            )
                    )
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.92))
            .disabled(pings.isRefreshing)
            .accessibilityIdentifier("servers.refresh")
        }
        .frame(height: 48)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("LOCATIONS")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(2.1)
                .foregroundStyle(.white.opacity(0.38))

            Text("Choose your route")
                .font(.system(size: 28, weight: .semibold))
                .tracking(-0.7)

            Text("Low latency. Real VO1D nodes.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.40))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchField: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.40))

            TextField("Search locations", text: $search)
                .font(.system(size: 14))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("servers.search")

            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.34))
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.92))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.028))
                .background(.ultraThinMaterial, in: Capsule())
        }
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.10), lineWidth: 0.8)
        }
    }

    private var fastestCard: some View {
        Button {
            guard let fastest = model.fastestServer else {
                Task { await pings.refresh() }
                return
            }

            preferences.autoFastest = true
            model.select(fastest)
        } label: {
            ReferenceGlassCard(radius: 22, highlighted: true) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                            .frame(width: 48, height: 48)

                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("FASTEST LOCATION")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(.white.opacity(0.38))

                        Text(
                            model.fastestServer.map {
                                "\($0.flag)  \($0.name)"
                            } ?? "Measure routes"
                        )
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                    }

                    Spacer()

                    Text(
                        model.fastestServer
                            .flatMap { pings.values[$0.code] }
                            .map { "\($0) ms" }
                        ?? "— ms"
                    )
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.58))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(17)
            }
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.985))
        .disabled(model.phase.isBusy)
        .accessibilityIdentifier("servers.fastest")
    }

    private var filterBar: some View {
        HStack(spacing: 5) {
            ForEach(Filter.allCases, id: \.self) { item in
                Button {
                    Haptics.play(.selection, enabled: preferences.haptics)

                    withAnimation(
                        reduceMotion
                        ? nil
                        : .snappy(duration: 0.22)
                    ) {
                        filter = item
                    }
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(
                            filter == item
                            ? .black
                            : .white.opacity(0.44)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background {
                            if filter == item {
                                Capsule()
                                    .fill(.white)
                                    .shadow(
                                        color: .white.opacity(0.18),
                                        radius: 7
                                    )
                            }
                        }
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.96))
                .accessibilityIdentifier("filter.\(item.rawValue)")
            }
        }
        .padding(4)
        .background(
            Color.white.opacity(0.028),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.8)
        )
    }
}

private extension View {
    func locationReveal(
        _ visible: Bool,
        delay: Double,
        reduceMotion: Bool
    ) -> some View {
        opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 12)
            .animation(
                reduceMotion
                ? nil
                : .easeOut(duration: 0.42).delay(delay),
                value: visible
            )
    }
}
