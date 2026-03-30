import SwiftUI
import SwiftData

@main
struct HabitXApp: App {
    var body: some Scene {
        WindowGroup {
            TabRootView()
        }
        .modelContainer(SharedModelContainer.container)
    }
}
