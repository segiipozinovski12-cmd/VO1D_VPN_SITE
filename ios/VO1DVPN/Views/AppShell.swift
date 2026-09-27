import SwiftUI

enum AppTab: String, CaseIterable {
    case home = "Home", locations = "Locations", profile = "Profile"
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
    @State private var tab: AppTab = .home
    @Namespace private var tabSelection
    var body: some View {
        NavigationStack {
            Group {
                switch tab {
                case .home: HomeView(openLocations: { tab = .locations }, openProfile: { tab = .profile })
                case .locations: ServersView()
                case .profile: ProfileView()
                }
            }
            .id(tab)
            .transition(.opacity)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: tab)
    }
    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { item in
                Button {
                    tab = item
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: item.icon).font(.system(size: 15))
                        Text(item.rawValue).font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(tab == item ? .white : VO1DStyle.secondary)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background {
                        if tab == item {
                            Capsule().fill(.white.opacity(0.09)).matchedGeometryEffect(id: "tab", in: tabSelection)
                        }
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("tab.\(item.rawValue.lowercased())")
                .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }
        .padding(6).vo1dSurface(radius: 32)
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 5)
        .background(VO1DStyle.background)
    }
}
