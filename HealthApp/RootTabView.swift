import SwiftUI

struct RootTabView: View {
    @StateObject private var store = Store()
    @StateObject private var health = HealthKitManager()

    var body: some View {
        TabView {
            TodayView()
                .environmentObject(store)
                .environmentObject(health)
                .tabItem { Label("今日", systemImage: "list.bullet") }

            TrendsView()
                .environmentObject(store)
                .tabItem { Label("趋势", systemImage: "chart.xyaxis.line") }

            SettingsView()
                .environmentObject(store)
                .environmentObject(health)
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .tint(Theme.accent)
    }
}
