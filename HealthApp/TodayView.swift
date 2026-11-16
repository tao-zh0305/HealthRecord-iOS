import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var bridge: ShortcutBridge
    @Environment(\.openURL) private var openURL
    @State private var sheet: EntryContext?

    private var todayRecords: [Record] { store.records(on: Date()) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 18)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 11),
                                    GridItem(.flexible(), spacing: 11)],
                          spacing: 11) {
                    weightCard
                    bpCard
                    sleepCard
                    exerciseCard
                }

                HStack {
                    Text("快速记录")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("点一下即可录入")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 22)
                .padding(.bottom, 11)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3),
                          spacing: 9) {
                    ForEach(MetricType.allCases) { type in
                        QuickButton(type: type) {
                            sheet = EntryContext(type: type)
                        }
                    }
                }

                HStack {
                    Text("今天的记录")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(todayRecords.count) 条")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 24)
                .padding(.bottom, 10)

                if todayRecords.isEmpty {
                    EmptyCard(title: "今天还没有记录",
                              subtitle: "从上面的按钮开始，3 秒记一条。")
                } else {
                    VStack(spacing: 8) {
                        ForEach(todayRecords) { record in
                            Button {
                                sheet = EntryContext(type: record.type, record: record)
                            } label: {
                                RecordRow(record: record)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(item: $sheet) { context in
            EntrySheet(context: context)
                .environmentObject(store)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(DateText.greeting())
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                    Text(DateText.long(Date()))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                syncButton
            }

            Text(bridge.status)
                .font(.caption2)
                .foregroundStyle(bridge.isStale ? Theme.accent : Color.secondary)
        }
    }

    private var syncButton: some View {
        Button {
            if let url = ShortcutBridge.runURL {
                openURL(url)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("立即同步")
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Theme.accent.opacity(0.12), in: Capsule())
            .foregroundStyle(Theme.accent)
        }
    }

    private var weightCard: some View {
        let record = store.latest(.weight)
        let sub: String
        if let record = record, let fat = record.v2 {
            sub = "体脂 " + Fmt.num(fat) + "%"
        } else if let record = record {
            sub = DateText.relative(record.createdAt)
        } else {
            sub = "还没有记录"
        }
        return SummaryCard(title: "体重",
                           value: record.map { Fmt.num($0.v1) } ?? "—",
                           unit: record == nil ? "" : "kg",
                           sub: sub,
                           tint: MetricType.weight.tint)
    }

    private var bpCard: some View {
        let record = store.latest(.bp)
        let value: String
        if let record = record {
            value = Fmt.int(record.v1) + "/" + Fmt.int(record.v2)
        } else {
            value = "—"
        }
        return SummaryCard(title: "血压",
                           value: value,
                           unit: record == nil ? "" : "mmHg",
                           sub: record.map { DateText.relative($0.createdAt) } ?? "还没有记录",
                           tint: MetricType.bp.tint)
    }

    private var sleepCard: some View {
        let today = todayRecords.first { $0.type == .sleep }
        let record = today ?? store.latest(.sleep)
        let sub: String
        if let record = record, let quality = record.v2 {
            sub = Fmt.quality(Int(quality)) + " · " + DateText.relative(record.createdAt)
        } else if let record = record {
            sub = DateText.relative(record.createdAt)
        } else {
            sub = "还没有记录"
        }
        return SummaryCard(title: "睡眠",
                           value: record.map { Fmt.num($0.v1) } ?? "—",
                           unit: record == nil ? "" : "小时",
                           sub: sub,
                           tint: MetricType.sleep.tint)
    }

    private var exerciseCard: some View {
        let total = store.todayTotal(.exercise)
        let count = todayRecords.filter { $0.type == .exercise }.count
        return SummaryCard(title: "今日运动",
                           value: count == 0 ? "—" : Fmt.num(total),
                           unit: count == 0 ? "" : "分钟",
                           sub: count == 0 ? "今天还没记录" : "共 \(count) 次",
                           tint: MetricType.exercise.tint)
    }
}
