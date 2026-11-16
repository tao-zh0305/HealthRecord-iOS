import SwiftUI
import UIKit

struct RootTabView: View {
    @StateObject private var store = Store()
    @StateObject private var bridge = ShortcutBridge()

    @State private var importMessage = ""
    @State private var showImportResult = false

    var body: some View {
        TabView {
            TodayView()
                .environmentObject(store)
                .environmentObject(bridge)
                .tabItem { Label("今日", systemImage: "list.bullet") }

            TrendsView()
                .environmentObject(store)
                .tabItem { Label("趋势", systemImage: "chart.xyaxis.line") }

            SettingsView()
                .environmentObject(store)
                .environmentObject(bridge)
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .tint(Theme.accent)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            bridge.refreshStatus()
        }
        .onOpenURL { url in
            guard let message = bridge.handle(url, into: store) else { return }
            importMessage = message
            showImportResult = true
        }
        .alert("快捷指令导入", isPresented: $showImportResult) {
            Button("好", role: .cancel) {}
        } message: {
            Text(importMessage)
        }
    }
}
