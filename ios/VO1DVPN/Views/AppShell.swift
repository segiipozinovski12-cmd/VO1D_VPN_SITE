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
    @EnvironmentObject private var model: AppViewModel
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
        .fullScreenCover(
            isPresented: Binding(
                get: { model.paywallRequested },
                set: { shown in
                    if !shown {
                        model.dismissPaywall()
                    }
                }
            )
        ) {
            LoginView {
                model.dismissPaywall()
            }
        }
    }

    private var referenceTabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { item in
                Button {
                    select(item)
                } label: {
                    ZStack {
                        if tab == item {
                            RoundedRectangle(
                                cornerRadius: 16,
                                style: .continuous
                            )
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.12),
                                        VO1DStyle.frost.opacity(0.055),
                                        VO1DStyle.midnight.opacity(0.44)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: 16,
                                    style: .continuous
                                )
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.32),
                                            VO1DStyle.chrome.opacity(0.10),
                                            .white.opacity(0.04)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.7
                                )
                            }
                            .shadow(
                                color: VO1DStyle.frost.opacity(0.08),
                                radius: 10
                            )
                            .padding(.horizontal, 4)
                            .padding(.vertical, 5)
                            .transition(
                                .scale(scale: 0.92)
                                .combined(with: .opacity)
                            )
                        }

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
                                .shadow(
                                    color:
                                        tab == item
                                        ? .white.opacity(0.24)
                                        : .clear,
                                    radius: 6
                                )

                            Text(item.rawValue)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(
                            tab == item
                            ? .white
                            : .white.opacity(0.34)
                        )
                    }
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
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(0.11),
                        VO1DStyle.graphite.opacity(0.82),
                        .black.opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
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
                        .white.opacity(0.36),
                        .white.opacity(0.08),
                        VO1DStyle.frost.opacity(0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.8
            )
        }
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.46),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 92, height: 1.2)
                .padding(.leading, 30)
                .padding(.top, 1)
                .blur(radius: 0.5)
        }
        .shadow(color: .white.opacity(0.05), radius: 14)
        .shadow(color: .black.opacity(0.68), radius: 22, y: 12)
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
