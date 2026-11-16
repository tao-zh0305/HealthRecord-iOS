import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var health: HealthKitManager

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

                sectionTitle("健康数据")
                VStack(spacing: 0) {
                    SettingsRow(icon: "heart.text.square",
                                tint: Theme.accent,
                                title: "一键同步 Apple 健康",
                                subtitle: health.status,
                                value: health.lastSync.map { DateText.relative($0) },
                                showsChevron: false,
                                action: { health.sync(into: store) })
                    Divider().padding(.leading, 56)
                    SettingsRow(icon: "info.circle",
                                tint: .secondary,
                                title: "同步范围",
                                subtitle: "最近 30 天的步数、运动、心率、体重、体脂、血压与睡眠",
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

                Text("数据只保存在本机 App 内，不会上传到任何服务器。卸载 App 会一并删除数据，建议定期导出备份。健康数据同步需要你在系统弹窗中授权「健康」读取权限，未授权时手动记录不受影响。")
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
