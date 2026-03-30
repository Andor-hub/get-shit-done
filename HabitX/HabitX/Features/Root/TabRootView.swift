import SwiftUI

struct TabRootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "house")
                }
            HistoryListView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
            StatsListView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
        }
        .tint(.appAccent)
    }
}

#Preview {
    TabRootView()
}
