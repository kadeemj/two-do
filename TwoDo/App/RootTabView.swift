import SwiftUI

struct RootTabView: View {
    @Bindable var router: AppRouter

    init(router: AppRouter) {
        self.router = router
        #if DEBUG
        // UI-test / screenshot hook: open directly on a given tab.
        if ProcessInfo.processInfo.environment["TWODO_SMOKE_TAB"] == "calendar" {
            router.selectedTab = .schedule
        }
        #endif
    }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            TodayView(
                requestedTaskID: $router.requestedTaskID,
                requestedCreateTask: $router.requestedCreateTask
            )
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
                .tag(AppTab.today)

            ScheduleView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(AppTab.schedule)

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(AppTab.search)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .tint(TwoDoColor.accentBlue)
        .onOpenURL { url in
            _ = router.handle(url: url)
        }
    }
}

#Preview {
    RootTabView(router: AppRouter())
        .modelContainer(ModelContainerFactory.makePreview())
}
