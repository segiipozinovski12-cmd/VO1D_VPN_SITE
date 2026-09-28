import SwiftUI

enum AppTab: String, CaseIterable {
    case home = "Home"
    case locations = "Locations"
    case stats = "Stats"
    case profile = "Profile"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .locations: return "location.circle"
        case .stats: return "chart.bar.xaxis"
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
                        StatsView()

                    case .profile:
                        ProfileView()
                    }
                }
                .id(tab)
                .transition(tabTransition)
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    referenceTabBar
                }
            }
        }
        .animation(
            reduceMotion
            ? nil
            : .snappy(duration: 0.30),
            value: tab
        )
    }

    private var referenceTabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { item in
                Button {
                    select(item)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .font(
                                .system(
                                    size: 18,
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
                    .frame(height: 60)
                    .contentShape(Rectangle())
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
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .fill(Color(white: 0.035).opacity(0.96))
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(
                    cornerRadius: 24,
                    style: .continuous
                )
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .strokeBorder(
                LinearGradient(
                    colors: [
                        .white.opacity(0.12),
                        .white.opacity(0.035)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.8
            )
        }
        .shadow(color: .black.opacity(0.55), radius: 20, y: 10)
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background {
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.58),
                    .black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var tabTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }

        return .asymmetric(
            insertion:
                .offset(x: direction > 0 ? 22 : -22)
                .combined(with: .opacity),
            removal:
                .offset(x: direction > 0 ? -16 : 16)
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
