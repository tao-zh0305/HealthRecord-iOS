import AppIntents
import Foundation

/// 快捷指令直接调用的动作：在后台写入记录，不切换到 App 界面
struct ImportHealthIntent: AppIntent {
    static let title: LocalizedStringResource = "导入健康数据"
    static let description = IntentDescription("把快捷指令读取到的健康数据写入健康记录，全程不打开界面。")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "数据", description: "以 [ 开头、] 结尾的 JSON 文本")
    var payload: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let records = ShortcutBridge.records(from: payload)
        guard !records.isEmpty else {
            return .result(dialog: "没有读到可用数据，检查 JSON 是否完整")
        }
        let result = HealthRecordFile.upsert(records)
        let total = result.inserted + result.updated
        ShortcutBridge.noteImport(count: total)
        if total == 0 {
            return .result(dialog: "数据没有变化")
        }
        return .result(dialog: "已写入 \(result.inserted) 条，更新 \(result.updated) 条")
    }
}

/// 供 App Intent 使用：与 Store 共用同一份 records.json
enum HealthRecordFile {
    static var url: URL {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("records.json")
    }

    static func load() -> [Record] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Record].self, from: data)) ?? []
    }

    static func upsert(_ incoming: [Record]) -> (inserted: Int, updated: Int) {
        var records = load()
        let result = Store.upsert(incoming, into: &records)
        guard result.inserted > 0 || result.updated > 0 else { return result }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(records) {
            try? data.write(to: url, options: .atomic)
        }
        return result
    }
}
