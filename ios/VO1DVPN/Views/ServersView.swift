import SwiftUI

struct ServersView: View {
    @EnvironmentObject private var model: AppViewModel
    @EnvironmentObject private var pings: PingStore
    @EnvironmentObject private var preferences: Preferences
    @Environment(\.vo1dReduceMotion) private var reduceMotion
    @State private var search = ""
    @State private var filter: Filter = .all
    @Namespace private var selection
    enum Filter: String, CaseIterable { case all = "ALL", favorites = "FAVORITES", lowest = "LOWEST PING" }

    private var filtered: [VO1DServer] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = model.servers.filter { server in
            (filter != .favorites || model.favoriteCodes.contains(server.code)) &&
            (query.isEmpty || [server.name, server.code, server.protocolName, server.label].contains { $0.localizedCaseInsensitiveContains(query) })
        }
        return filter == .lowest ? ServerRanking.sorted(matching, pings: pings.values) : matching.sorted { $0.name < $1.name }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack(alignment: .top) {
                    PageHeading(number: "02", title: "Locations", subtitle: "A world of possibilities. One connection.")
                    IconButton(icon: "arrow.clockwise", label: "Refresh ping") { Task { await pings.refresh() } }
                        .disabled(pings.isRefreshing).padding(.top, 18).accessibilityIdentifier("servers.refresh")
                }
                searchField
                fastestCard
                HStack(spacing: 3) {
                    ForEach(Filter.allCases, id: \.self) { item in
                        Button {
                            withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) { filter = item }
                        } label: {
                            Text(item.rawValue).font(VO1DStyle.mono(9)).tracking(0.1)
                                .frame(maxWidth: .infinity).frame(height: 42)
                                .foregroundStyle(filter == item ? .white : VO1DStyle.secondary)
                                .background {
                                    if filter == item { RoundedRectangle(cornerRadius: 11).fill(.white.opacity(0.09)).matchedGeometryEffect(id: "filter", in: selection) }
                                }
                        }.buttonStyle(ScaleButtonStyle()).accessibilityIdentifier("filter.\(item.rawValue)")
                            .accessibilityAddTraits(filter == item ? .isSelected : [])
                    }
                }.padding(4).vo1dSurface(radius: 15)
                if model.phase == .switching {
                    HStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text("SWITCHING ROUTE").font(VO1DStyle.mono(10)).tracking(1)
                        Spacer()
                        Text(model.selectedServer?.code ?? "").font(VO1DStyle.mono())
                    }.padding(15).vo1dSurface().accessibilityIdentifier("route.switching")
                }
                HStack {
                    Eyebrow(text: "\(filtered.count) LOCATIONS")
                    Spacer()
                    Text(pings.isRefreshing ? "MEASURING" : preferences.livePing ? "LIVE LATENCY" : "PING PAUSED")
                        .font(VO1DStyle.mono(9)).foregroundStyle(VO1DStyle.secondary)
                }
                LazyVStack(spacing: 10) {
                    ForEach(filtered) { server in
                        ServerCard(server: server, ping: pings.values[server.code],
                                   selected: model.selectedServer?.code == server.code,
                                   favorite: model.favoriteCodes.contains(server.code), compact: preferences.compactServers,
                                   showPing: preferences.livePing, busy: model.phase.isBusy,
                                   select: { model.select(server) }, toggleFavorite: { model.toggleFavorite(server) })
                    }
                    if filtered.isEmpty {
                        EmptyState(title: filter == .favorites && search.isEmpty ? "Keep your favorites close" : "No matching locations",
                                   detail: filter == .favorites && search.isEmpty ? "Tap a star beside any location to save it here." : "Try a country name, location code or protocol.")
                    }
                }
            }
            .padding(.horizontal, 22).padding(.bottom, 24)
        }
        .scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)
        .background { DeepSpaceBackdrop().ignoresSafeArea() }
        .accessibilityIdentifier("servers.screen")
    }
    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass").foregroundStyle(VO1DStyle.secondary)
            TextField("Search locations", text: $search)
                .font(.subheadline).textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityIdentifier("servers.search")
            if !search.isEmpty {
                Button { search = "" } label: { Image(systemName: "xmark.circle.fill").frame(width: 30, height: 44) }
                    .buttonStyle(ScaleButtonStyle()).accessibilityLabel("Clear search")
            }
        }.padding(.horizontal, 16).frame(minHeight: 52).vo1dSurface(radius: 16)
    }
    private var fastestCard: some View {
        Button {
            guard let fastest = model.fastestServer else { Task { await pings.refresh() }; return }
            model.select(fastest)
            preferences.autoFastest = true
        } label: {
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    Image(systemName: "bolt.fill").font(.system(size: 12))
                    Eyebrow(text: "FASTEST LOCATION")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.fastestServer.map { "\($0.flag)  \($0.name)" } ?? "Measure your routes")
                            .font(.system(size: 22, weight: .medium))
                        Text("Selected by the lowest measured ping")
                            .font(.caption).foregroundStyle(VO1DStyle.secondary)
                    }
                    Spacer(minLength: 4)
                    PingBadge(ping: model.fastestServer.flatMap { pings.values[$0.code] })
                }
            }.padding(20).vo1dSurface(highlighted: true)
        }.buttonStyle(ScaleButtonStyle()).disabled(model.phase.isBusy).accessibilityIdentifier("servers.fastest")
    }
}
