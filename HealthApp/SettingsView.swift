import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var bridge: ShortcutBridge
    @Environment(\.openURL) private var openURL

    @State private var share: ShareItem?
    @State private var importing = false
    @State private var showClearConfirm = false
    @State private var alertMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("设置")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .padding(.bottom, 16)

                sectionTitle("快捷指令同步")
                VStack(spacing: 0) {
                    SettingsRow(icon: "bolt.horizontal.circle",
                                tint: Theme.accent,
                                title: "运行「\(ShortcutBridge.shortcutName)」",
                                subtitle: bridge.status,
                                action: runShortcut)
                    Divider().padding(.leading, 56)
                    SettingsRow(icon: "doc.on.doc",
                                tint: Theme.accent,
                                title: "复制 JSON 模板",
                                subtitle: "拼快捷指令数据时可直接套用",
                                action: copyTemplate)
                }
                .cardStyle()
                .padding(.bottom, 10)

                Text("在「快捷指令」App 里新建「\(ShortcutBridge.shortcutName)」：读取健康样本 → 按日期汇总 → 生成 JSON 文本 → Base64 编码 → 打开 URL，内容为 \(ShortcutBridge.importPrefix) 加上编码结果。完成后建议添加到主屏，或做成每天自动运行的自动化。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineSpacing(3)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 14)

                sectionTitle("自动同步")
                VStack(spacing: 0) {
                    SettingsRow(icon: "clock.arrow.circlepath",
                                tint: Theme.accent,
                                title: "每小时自动运行",
                                subtitle: "在「快捷指令 → 自动化 → 特定时间」里按整点各建一条；iOS 不支持一次设成「每小时」，需逐个添加",
                                showsChevron: false)
                    Divider().padding(.leading, 56)
                    SettingsRow(icon: "bolt.badge.clock",
                                tint: Theme.accent,
                                title: "打开 App 时同步",
                                subtitle: "再建一条「App 打开时」自动化，运行同一个快捷指令，日常几乎不用手动点",
                                showsChevron: false)
                    Divider().padding(.leading, 56)
                    SettingsRow(icon: "hand.tap",
                                tint: .secondary,
                                title: "随时手动获取",
                                subtitle: "今日页点「立即同步」，或直接运行快捷指令",
                                showsChevron: false)
                }
                .cardStyle()
                .padding(.bottom, 14)

                sectionTitle("数据概览")
                VStack(spacing: 0) {
                    SettingsRow(icon: "list.number",
                                tint: .secondary,
                                title: "记录总数",
                                value: "\(store.records.count) 条",
                                showsChevron: false)
                    Divider().padding(.leading, 56)
                    SettingsRow(icon: "calendar",
                                tint: .secondary,
                                title: "最早记录",
                                value: store.earliestDay.map { DateText.day($0) } ?? "—",
                                showsChevron: false)
                    Divider().padding(.leading, 56)
                    SettingsRow(icon: "calendar.badge.clock",
                                tint: .secondary,
                                title: "最近记录",
                                value: store.latestDay.map { DateText.day($0) } ?? "—",
                                showsChevron: false)
                }
                .cardStyle()
                .padding(.bottom, 14)

                sectionTitle("备份与导出")
                VStack(spacing: 0) {
                    SettingsRow(icon: "tablecells",
                                tint: Theme.accent,
                                title: "导出 CSV",
                                subtitle: "可用 Numbers 或 Excel 打开",
                                action: exportCSV)
                    Divider().padding(.leading, 56)
                    SettingsRow(icon: "doc.badge.arrow.up",
                                tint: Theme.accent,
                                title: "导出 JSON 备份",
                                subtitle: "恢复时用这个文件",
                                action: exportJSON)
                    Divider().padding(.leading, 56)
                    SettingsRow(icon: "arrow.down.doc",
                                tint: Theme.accent,
                                title: "从备份恢复",
                                subtitle: "合并导入，不会覆盖已有记录",
                                action: { importing = true })
                }
                .cardStyle()
                .padding(.bottom, 14)

                sectionTitle("数据管理")
                VStack(spacing: 0) {
                    SettingsRow(icon: "trash",
                                tint: Theme.danger,
                                title: "清空所有记录",
                                titleColor: Theme.danger,
                                action: { showClearConfirm = true })
                }
                .cardStyle()
                .padding(.bottom, 14)

                Text("数据只保存在本机 App 内，不会上传到任何服务器。卸载 App 会一并删除数据，建议定期导出备份。健康数据由快捷指令写入本 App，App 本身不直接读取 Apple 健康，手动记录始终可用。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineSpacing(3)
                    .padding(.horizontal, 4)

                Text("健康记录 1.0")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(item: $share) { item in
            ShareSheet(items: [item.url])
        }
        .fileImporter(isPresented: $importing,
                      allowedContentTypes: [.json],
                      allowsMultipleSelection: false) { result in
            handleImport(result)
        }
        .confirmationDialog("确定清空所有记录？此操作不可撤销。",
                            isPresented: $showClearConfirm,
                            titleVisibility: .visible) {
            Button("清空", role: .destructive) { store.clear() }
            Button("取消", role: .cancel) {}
        }
        .alert("提示", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
            .padding(.bottom, 7)
    }

    // MARK: - 快捷指令

    private func runShortcut() {
        guard let url = ShortcutBridge.runURL else { return }
        openURL(url)
    }

    private func copyTemplate() {
        UIPasteboard.general.string = ShortcutBridge.sampleJSON
        alertMessage = "JSON 模板已复制"
    }

    // MARK: - 导出

    private func exportCSV() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        var lines = ["日期,时间,类型,数值,单位,备注"]
        for record in store.records.sorted(by: { $0.createdAt < $1.createdAt }) {
            let value: String
            if record.type == .bp {
                value = Fmt.int(record.v1) + "/" + Fmt.int(record.v2)
            } else {
                value = Fmt.plain(record.v1)
            }
            let note = (record.note ?? "").replacingOccurrences(of: ",", with: "，")
            let fields = [dateFormatter.string(from: record.day),
                          timeFormatter.string(from: record.createdAt),
                          record.type.title,
                          value,
                          record.type.unit,
                          note]
            lines.append(fields.joined(separator: ","))
        }

        let name = "健康记录-" + dateFormatter.string(from: Date()) + ".csv"
        if let url = writeTemp(name, "\u{FEFF}" + lines.joined(separator: "\n")) {
            share = ShareItem(url: url)
        } else {
            alertMessage = "导出失败"
        }
    }

    private func exportJSON() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(store.records) else {
            alertMessage = "导出失败"
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let name = "健康记录备份-" + formatter.string(from: Date()) + ".json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            share = ShareItem(url: url)
        } catch {
            alertMessage = "导出失败"
        }
    }

    private func writeTemp(_ name: String, _ content: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - 导入

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                alertMessage = "读取文件失败"
                return
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let list = try? decoder.decode([Record].self, from: data) else {
                alertMessage = "这不是有效的备份文件"
                return
            }
            let count = store.merge(list)
            alertMessage = "已合并 \(count) 条记录"
        case .failure:
            alertMessage = "读取文件失败"
        }
    }
}

private struct SettingsRow: View {
    let icon: String
    let tint: Color
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var titleColor: Color? = nil
    var showsChevron: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action = action {
                Button(action: action) { content }
                    .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private var content: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(titleColor ?? Color.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if let value = value {
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
