import SwiftUI
import EventKit

struct RootTabView: View {
    @Bindable var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase
    @State private var calendars = DeviceCalendarService()

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
        .environment(calendars)
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
            calendars.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { calendars.refresh() }
        }
        .onOpenURL { url in
            _ = router.handle(url: url)
        }
    }
}

#Preview {
    RootTabView(router: AppRouter())
        .modelContainer(ModelContainerFactory.makePreview())
}
