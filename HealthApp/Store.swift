import Foundation
import Combine

final class Store: ObservableObject {
    @Published private(set) var records: [Record] = []

    private let fileURL: URL

    init() {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("records.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        records = (try? decoder.decode([Record].self, from: data)) ?? []
        records.sort { $0.createdAt > $1.createdAt }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func sortAndSave() {
        records.sort { $0.createdAt > $1.createdAt }
        persist()
    }

    func add(_ record: Record) {
        records.append(record)
        sortAndSave()
    }

    func update(_ record: Record) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index] = record
        sortAndSave()
    }

    func delete(_ record: Record) {
        records.removeAll { $0.id == record.id }
        persist()
    }

    func clear() {
        records = []
        persist()
    }

    @discardableResult
    func merge(_ incoming: [Record]) -> Int {
        let existing = Set(records.map { $0.id })
        let fresh = incoming.filter { !existing.contains($0.id) }
        guard !fresh.isEmpty else { return 0 }
        records.append(contentsOf: fresh)
        sortAndSave()
        return fresh.count
    }

    /// 导入健康数据时避免覆盖同一天的手动记录
    @discardableResult
    func insertIfMissing(_ incoming: [Record]) -> Int {
        var inserted = 0
        for record in incoming where !has(record.type, on: record.day) {
            records.append(record)
            inserted += 1
        }
        if inserted > 0 { sortAndSave() }
        return inserted
    }

    /// 快捷指令同步：同一天同一类型以最新数据为准
    /// 只更新快捷指令来源的记录，手动记录保持不变
    @discardableResult
    func upsertShortcut(_ incoming: [Record]) -> (inserted: Int, updated: Int) {
        var inserted = 0
        var updated = 0
        let cal = Calendar.current
        for record in incoming {
            if let index = records.firstIndex(where: {
                $0.type == record.type
                    && $0.note == ShortcutBridge.note
                    && cal.isDate($0.day, inSameDayAs: record.day)
            }) {
                var merged = records[index]
                merged.v1 = record.v1 ?? merged.v1
                merged.v2 = record.v2 ?? merged.v2
                merged.v3 = record.v3 ?? merged.v3
                merged.text = record.text ?? merged.text
                merged.createdAt = record.createdAt
                if merged != records[index] {
                    records[index] = merged
                    updated += 1
                }
            } else if !has(record.type, on: record.day) {
                records.append(record)
                inserted += 1
            }
        }
        if inserted > 0 || updated > 0 { sortAndSave() }
        return (inserted, updated)
    }

    func has(_ type: MetricType, on day: Date) -> Bool {
        records.contains {
            $0.type == type && Calendar.current.isDate($0.day, inSameDayAs: day)
        }
    }

    func records(on day: Date) -> [Record] {
        records
            .filter { Calendar.current.isDate($0.day, inSameDayAs: day) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func latest(_ type: MetricType) -> Record? {
        records.first { $0.type == type }
    }

    func todayTotal(_ type: MetricType) -> Double {
        records(on: Date())
            .filter { $0.type == type }
            .compactMap { $0.v1 }
            .reduce(0, +)
    }

    func dailySeries(_ type: MetricType, days: Int) -> [SeriesPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }

        let filtered = records.filter { record in
            let day = cal.startOfDay(for: record.day)
            return record.type == type && day >= start && day <= today
        }
        let grouped = Dictionary(grouping: filtered) { cal.startOfDay(for: $0.day) }

        return grouped.keys.sorted().compactMap { day -> SeriesPoint? in
            guard let rows = grouped[day], !rows.isEmpty else { return nil }
            switch type {
            case .weight, .bp:
                guard let last = rows.max(by: { $0.createdAt < $1.createdAt }) else { return nil }
                return SeriesPoint(date: day, value: last.v1 ?? 0, second: last.v2)
            case .hr:
                let values = rows.compactMap { $0.v1 }
                guard !values.isEmpty else { return nil }
                return SeriesPoint(date: day, value: values.reduce(0, +) / Double(values.count))
            case .sleep, .exercise, .steps:
                let values = rows.compactMap { $0.v1 }
                guard !values.isEmpty else { return nil }
                return SeriesPoint(date: day, value: values.reduce(0, +))
            }
        }
    }

    var earliestDay: Date? { records.map { $0.day }.min() }
    var latestDay: Date? { records.map { $0.day }.max() }
}
