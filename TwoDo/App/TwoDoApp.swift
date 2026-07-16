import SwiftUI
import SwiftData

@main
struct TwoDoApp: App {
    private let container: ModelContainer

    init() {
        container = ModelContainerFactory.make()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
