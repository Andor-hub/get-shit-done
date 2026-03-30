import SwiftUI
import SwiftData

@main
struct HabitXApp: App {
    @State private var deepLinkHabitId: UUID? = nil

    var body: some Scene {
        WindowGroup {
            TabRootView(deepLinkHabitId: $deepLinkHabitId)
                .onOpenURL { url in
                    guard url.scheme == "habitx",
                          url.host == "log",
                          let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                          let idString = components.queryItems?.first(where: { $0.name == "id" })?.value,
                          let uuid = UUID(uuidString: idString)
                    else { return }
                    deepLinkHabitId = uuid
                }
        }
        .modelContainer(SharedModelContainer.container)
    }
}
