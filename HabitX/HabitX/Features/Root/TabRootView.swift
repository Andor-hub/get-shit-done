import SwiftUI
import SwiftData
import WidgetKit

struct TabRootView: View {
    @Binding var deepLinkHabitId: UUID?
    @State private var selectedTab: Int = 0
    @Environment(\.scenePhase) private var scenePhase
    @Query private var habits: [HabitSchemaV1.Habit]

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(deepLinkHabitId: $deepLinkHabitId)
                .tabItem {
                    Label("Today", systemImage: "house")
                }
                .tag(0)
            HistoryListView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(1)
            StatsListView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
                .tag(2)
        }
        .tint(.appAccent)
        .onChange(of: deepLinkHabitId) { _, newValue in
            if newValue != nil {
                selectedTab = 0
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                WidgetCenter.shared.reloadAllTimelines()
                NotificationService.cancelRemindersForCompletedHabits(habits)
            }
        }
    }
}

#Preview {
    TabRootView(deepLinkHabitId: .constant(nil))
}
