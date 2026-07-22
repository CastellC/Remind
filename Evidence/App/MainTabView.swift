import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: MainTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label(
                        String(localized: "tab.today", defaultValue: "Today"),
                        systemImage: "sun.max"
                    )
                }
                .tag(MainTab.today)
                .accessibilityIdentifier("tab.today")

            CollectionView()
                .tabItem {
                    Label(
                        String(localized: "tab.collection", defaultValue: "Collection"),
                        systemImage: "square.stack.3d.up"
                    )
                }
                .tag(MainTab.collection)
                .accessibilityIdentifier("tab.collection")

            SettingsView()
                .tabItem {
                    Label(
                        String(localized: "tab.settings", defaultValue: "Settings"),
                        systemImage: "gearshape"
                    )
                }
                .tag(MainTab.settings)
                .accessibilityIdentifier("tab.settings")
        }
        .tint(EvidenceFallbackColors.accent)
        .accessibilityIdentifier("main.tabs")
    }
}

#Preview {
    let container = AppContainer.preview()
    return MainTabView()
        .environment(container)
        .environmentObject(container.environment)
        .modelContainer(container.modelContainer)
}
