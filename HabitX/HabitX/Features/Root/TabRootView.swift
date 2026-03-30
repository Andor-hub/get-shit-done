import SwiftUI

struct TabRootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "house")
                }
            Text("History — Coming Soon")
                .font(.title3)
                .foregroundStyle(.secondary)
                .tabItem {
                    Label("History", systemImage: "clock")
                }
            Text("Stats — Coming Soon")
                .font(.title3)
                .foregroundStyle(.secondary)
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
