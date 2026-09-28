import SwiftUI

enum AppTab: String, CaseIterable {
    case home = "Home"
    case locations = "Locations"
    case profile = "Profile"

    var icon: String {
        switch self {
        case .home: return "circle.hexagongrid"
        case .locations: return "globe.europe.africa"
        case .profile: return "person.crop.circle"
        }
    }
}

struct AppShell: View {
    @Environment(\.vo1dReduceMotion) private var reduceMotion
    @EnvironmentObject private var preferences: Preferences

    @State private var tab: AppTab = .home
    @Namespace private var tabSelection

    var body: some View {
        NavigationStack {
            ZStack {
                DeepSpaceBackdrop().ignoresSafeArea()

                Group {
                    switch tab {
                    case .home:
                        HomeView(
                            openLocations: { select(.locations) },
                            openProfile: { select(.profile) }
                        )
                    case .locations:
                        ServersView()
                    case .profile:
                        ProfileView()
                    }
                }
                .id(tab)
                .transition(
                    reduceMotion
                    ? .opacity
                    : .opacity.combined(with: .scale(scale: 0.985))
                )
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    tabBar
                }
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.30), value: tab)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { item in
                Button {
                    select(item)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: item.icon)
                            .font(.system(size: 15, weight: tab == item ? .semibold : .regular))
                            .symbolRenderingMode(.hierarchical)
                            .symbolEffect(.bounce, value: tab == item)

                        Text(item.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(tab == item ? .white : VO1DStyle.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background {
                        if tab == item {
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    .white.opacity(0.12),
                                                    VO1DStyle.ice.opacity(0.06),
                                                    .white.opacity(0.035)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
                                .matchedGeometryEffect(id: "tab", in: tabSelection)
                        }
                    }
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.95))
                .accessibilityIdentifier("tab.\(item.rawValue.lowercased())")
                .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }
        .padding(6)
        .vo1dSurface(radius: 32)
        .padding(.horizontal, 20)
        .padding(.top, 9)
        .padding(.bottom, 5)
        .background(
            LinearGradient(
                colors: [.clear, VO1DStyle.background.opacity(0.78), VO1DStyle.background],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func select(_ next: AppTab) {
        guard next != tab else { return }
        Haptics.play(.selection, enabled: preferences.haptics)
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.30)) {
            tab = next
        }
    }
}
