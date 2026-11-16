import SwiftUI
import UIKit

struct RootTabView: View {
    @StateObject private var store = Store()
    @StateObject private var bridge = ShortcutBridge()
    @Environment(\.openURL) private var openURL

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
        .onAppear { didBecomeActive() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            didBecomeActive()
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

    /// 启动或回到前台：刷新状态，必要时自动跑一次快捷指令
    private func didBecomeActive() {
        store.reload()
        bridge.refreshStatus()
        guard bridge.shouldAutoRun(), let url = ShortcutBridge.runURL else { return }
        bridge.markAutoRun()
        openURL(url)
    }
}
