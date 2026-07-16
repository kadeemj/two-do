import SwiftUI

struct RootTabView: View {
    @State private var selectedTab: Tab = .today

    enum Tab: Hashable {
        case today, schedule, search, settings
    }

    init() {
        #if DEBUG
        // UI-test / screenshot hook: open directly on a given tab.
        if ProcessInfo.processInfo.environment["TWODO_SMOKE_TAB"] == "calendar" {
            _selectedTab = State(initialValue: .schedule)
        }
        #endif
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
                .tag(Tab.today)

            ScheduleView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(Tab.schedule)

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(Tab.search)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
        .tint(TwoDoColor.accentBlue)
    }
}

#Preview {
    RootTabView()
        .modelContainer(ModelContainerFactory.makePreview())
}
