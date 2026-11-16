import Foundation
import Combine

/// 快捷指令桥接
/// 链接：healthrecord://import?payload=<Base64(JSON)>
/// JSON 支持直接是数组，或 {"records": [...]}
/// 示例：
/// [{"type":"steps","day":"2026-11-15","v1":8234},
///  {"type":"sleep","day":"2026-11-15","v1":7.5},
///  {"type":"weight","day":"2026-11-15","v1":68.2,"v2":18.5},
///  {"type":"bp","day":"2026-11-15","v1":118,"v2":76,"v3":68},
///  {"type":"hr","day":"2026-11-15","v1":72},
///  {"type":"exercise","day":"2026-11-15","v1":35,"text":"户外步行"}]
final class ShortcutBridge: ObservableObject {
    static let scheme = "healthrecord"
    static let shortcutName = "同步健康记录"
    static let importPrefix = "healthrecord://import?payload="
    /// 快捷指令写入的记录会带上这个标记，便于按天更新而不是重复堆积
    static let note = "快捷指令"

    @Published private(set) var lastSync: Date?
    @Published private(set) var lastCount: Int = 0

    private let defaults: UserDefaults

    private enum Key {
        static let lastSync = "shortcut.lastSync"
        static let lastCount = "shortcut.lastCount"
        static let lastAutoRun = "shortcut.lastAutoRun"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        lastSync = defaults.object(forKey: Key.lastSync) as? Date
        lastCount = defaults.integer(forKey: Key.lastCount)
    }

    var status: String {
        guard let lastSync = lastSync else {
            return "还没有同步过，点「立即同步」运行快捷指令"
        }
        var text = "最近导入 \(lastCount) 条 · " + DateText.relative(lastSync)
        if isStale { text += "（已超过 1 小时）" }
        return text
    }

    /// 距离上次同步超过 1 小时
    var isStale: Bool {
        guard let lastSync = lastSync else { return true }
        return Date().timeIntervalSince(lastSync) > 3600
    }

    /// 回到前台时刷新界面上的时间文案
    func refreshStatus() {
        objectWillChange.send()
    }

    // MARK: - 打开 App 时自动同步

    /// 是否需要在本次启动/回到前台时自动运行快捷指令
    /// 首次（从未成功同步）不自动跳转，避免快捷指令还没建好时反复被带走
    func shouldAutoRun() -> Bool {
        guard let lastSync = lastSync else { return false }
        if Date().timeIntervalSince(lastSync) < 60 { return false }
        if let last = defaults.object(forKey: Key.lastAutoRun) as? Date,
           Date().timeIntervalSince(last) < 600 { return false }
        return true
    }

    func markAutoRun() {
        defaults.set(Date(), forKey: Key.lastAutoRun)
    }

    /// 打开「快捷指令」App 并运行同名快捷指令
    static var runURL: URL? {
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "run-shortcut"
        components.queryItems = [URLQueryItem(name: "name", value: shortcutName)]
        return components.url
    }

    static let sampleJSON = """
    [{"type":"steps","day":"2026-11-15","v1":8234},
     {"type":"sleep","day":"2026-11-15","v1":7.5},
     {"type":"weight","day":"2026-11-15","v1":68.2,"v2":18.5},
     {"type":"bp","day":"2026-11-15","v1":118,"v2":76,"v3":68},
     {"type":"hr","day":"2026-11-15","v1":72},
     {"type":"exercise","day":"2026-11-15","v1":35,"text":"户外步行"}]
    """

    func canHandle(_ url: URL) -> Bool {
        url.scheme?.lowercased() == Self.scheme
    }

    /// 处理回链，返回给用户的提示；不是导入请求时返回 nil
    @discardableResult
    func handle(_ url: URL, into store: Store) -> String? {
        guard canHandle(url) else { return nil }
        guard url.host?.lowercased() == "import" else { return nil }
        guard let entries = Self.entries(from: url) else {
            return "链接里没有可解析的数据，请检查快捷指令中的 Base64 内容"
        }
        let records = entries.compactMap { $0.record() }
        guard !records.isEmpty else {
            return "数据能解码，但缺少 type / day（或数值为空）"
        }
        let result = store.upsertShortcut(records)
        lastCount = result.inserted + result.updated
        lastSync = Date()
        defaults.set(lastCount, forKey: Key.lastCount)
        defaults.set(lastSync, forKey: Key.lastSync)

        if result.inserted == 0 && result.updated == 0 {
            return "没有新数据（同一天的手动记录不会被覆盖）"
        }
        var parts: [String] = []
        if result.inserted > 0 { parts.append("新增 \(result.inserted) 条") }
        if result.updated > 0 { parts.append("更新 \(result.updated) 条") }
        return "同步完成：" + parts.joined(separator: "，")
    }

    // MARK: - 解析

    private static func entries(from url: URL) -> [ShortcutEntry]? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let raw = components.queryItems?
            .first(where: { $0.name == "payload" || $0.name == "data" })?
            .value
        guard let text = raw, !text.isEmpty else { return nil }

        var data = base64Data(text)
        if data == nil {
            data = text.removingPercentEncoding?.data(using: .utf8)
        }
        guard let json = data else { return nil }

        let decoder = JSONDecoder()
        if let list = try? decoder.decode([ShortcutEntry].self, from: json) { return list }
        if let wrapper = try? decoder.decode(ShortcutPayload.self, from: json) { return wrapper.records }
        return nil
    }

    private static func base64Data(_ text: String) -> Data? {
        var value = text
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .replacingOccurrences(of: " ", with: "+")
        if value.count % 4 != 0 {
            value += String(repeating: "=", count: 4 - value.count % 4)
        }
        return Data(base64Encoded: value)
    }

    private static let aliases: [String: MetricType] = [
        "weight": .weight, "体重": .weight,
        "bp": .bp, "bloodpressure": .bp, "血压": .bp,
        "hr": .hr, "heartrate": .hr, "心率": .hr,
        "sleep": .sleep, "sleepanalysis": .sleep, "睡眠": .sleep,
        "exercise": .exercise, "appleexercisetime": .exercise, "运动": .exercise,
        "steps": .steps, "stepcount": .steps, "步数": .steps
    ]

    static func metric(for raw: String) -> MetricType? {
        let key = raw.lowercased()
            .replacingOccurrences(of: "hkquantitytypeidentifier", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        if let exact = aliases[key] { return exact }
        if key.contains("step") || key.contains("步") { return .steps }
        if key.contains("sleep") || key.contains("睡眠") { return .sleep }
        if key.contains("exercise") || key.contains("运动") { return .exercise }
        if key.contains("heartrate") || key == "hr" || key.contains("心率") { return .hr }
        if key.contains("bloodpressure") || key == "bp" || key.contains("血压") { return .bp }
        if key.contains("weight") || key.contains("bodymass") || key.contains("体重") { return .weight }
        return nil
    }

    private static let dayFormats = [
        "yyyy-MM-dd",
        "yyyy/MM/dd",
        "yyyy-MM-dd HH:mm",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
        "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
    ]

    static func day(from raw: String?) -> Date? {
        guard let value = raw?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        for format in dayFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) { return date }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: value)
    }
}

// MARK: - 数据结构

private struct ShortcutPayload: Decodable {
    let records: [ShortcutEntry]
}

private struct ShortcutEntry: Decodable {
    let type: String
    let day: String?
    let date: String?
    let v1: Double?
    let v2: Double?
    let v3: Double?
    let text: String?
    let note: String?

    enum CodingKeys: String, CodingKey {
        case type, day, date, v1, v2, v3, text, note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? container.decode(String.self, forKey: .type)) ?? ""
        day = try? container.decode(String.self, forKey: .day)
        date = try? container.decode(String.self, forKey: .date)
        v1 = ShortcutEntry.double(container, .v1)
        v2 = ShortcutEntry.double(container, .v2)
        v3 = ShortcutEntry.double(container, .v3)
        text = try? container.decode(String.self, forKey: .text)
        note = try? container.decode(String.self, forKey: .note)
    }

    /// 兼容数字、整数与字符串三种写法
    private static func double(_ container: KeyedDecodingContainer<CodingKeys>,
                               _ key: CodingKeys) -> Double? {
        if let value = try? container.decode(Double.self, forKey: key) { return value }
        if let value = try? container.decode(Int.self, forKey: key) { return Double(value) }
        if let value = try? container.decode(String.self, forKey: key) { return Fmt.parse(value) }
        return nil
    }

    func record() -> Record? {
        guard let metric = ShortcutBridge.metric(for: type) else { return nil }
        guard let day = ShortcutBridge.day(from: self.day ?? date) else { return nil }

        switch metric {
        case .bp:
            guard v1 != nil, v2 != nil else { return nil }
        case .weight:
            guard v1 != nil || v2 != nil else { return nil }
        default:
            guard v1 != nil else { return nil }
        }

        let noteText = (note?.isEmpty == false ? note : nil) ?? ShortcutBridge.note
        return Record(type: metric,
                      day: day,
                      createdAt: day,
                      v1: v1,
                      v2: v2,
                      v3: v3,
                      text: text,
                      note: noteText)
    }
}
