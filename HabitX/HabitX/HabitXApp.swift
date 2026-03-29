import SwiftUI
import SwiftData

@main
struct HabitXApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(SharedModelContainer.container)
    }
}
