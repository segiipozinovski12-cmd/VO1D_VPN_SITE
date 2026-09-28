import SwiftUI

enum AppTab: String, CaseIterable {
    case home = "Home"
    case locations = "Locations"
    case stats = "Stats"
    case profile = "Profile"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .locations: return "location"
        case .stats: return "chart.bar"
        case .profile: return "person"
        }
    }
}

struct AppShell: View {
    @Environment(\.vo1dReduceMotion) private var reduceMotion
    @EnvironmentObject private var preferences: Preferences

    @State private var tab: AppTab = .home
    @State private var direction: CGFloat = 1

    var body: some View {
        NavigationStack {
            ZStack {
                ReferenceBackdrop()

                Group {
                    switch tab {
                    case .home:
                        HomeView(
                            openLocations: { select(.locations) },
                            openProfile: { select(.profile) }
                        )

                    case .locations:
                        ServersView()

                    case .stats:
                        ReferenceStatsView()

                    case .profile:
                        ProfileView()
                    }
                }
                .id(tab)
                .transition(tabTransition)
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    tabBar
                }
            }
        }
        .animation(
            reduceMotion ? nil : .snappy(duration: 0.30),
            value: tab
        )
    }

    private var tabBar: some View {
        ReferenceGlassPanel(radius: 27) {
            HStack(spacing: 2) {
                ForEach(AppTab.allCases, id: \.self) { item in
                    Button {
                        select(item)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(
                                    .system(
                                        size: 17,
                                        weight:
                                            tab == item
                                            ? .semibold
                                            : .regular
                                    )
                                )
                                .symbolRenderingMode(.hierarchical)

                            Text(item.rawValue)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(
                            tab == item
                            ? .white
                            : .white.opacity(0.34)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.94))
                    .accessibilityIdentifier(
                        "tab.\(item.rawValue.lowercased())"
                    )
                    .accessibilityAddTraits(
                        tab == item
                        ? .isSelected
                        : []
                    )
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 5)
        .background(
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.78),
                    .black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var tabTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }

        let insertionX: CGFloat = direction > 0 ? 20 : -20
        let removalX: CGFloat = direction > 0 ? -12 : 12

        return .asymmetric(
            insertion:
                .offset(x: insertionX)
                .combined(with: .opacity),
            removal:
                .offset(x: removalX)
                .combined(with: .opacity)
        )
    }

    private func select(_ next: AppTab) {
        guard next != tab else { return }

        let tabs = AppTab.allCases
        let currentIndex = tabs.firstIndex(of: tab) ?? 0
        let nextIndex = tabs.firstIndex(of: next) ?? currentIndex

        direction = nextIndex >= currentIndex ? 1 : -1

        Haptics.play(
            .selection,
            enabled: preferences.haptics
        )

        withAnimation(
            reduceMotion
            ? nil
            : .snappy(duration: 0.30)
        ) {
            tab = next
        }
    }
}
