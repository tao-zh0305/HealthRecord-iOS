import SwiftUI
import UIKit

struct EntryContext: Identifiable {
    let id = UUID()
    var type: MetricType
    var record: Record? = nil
}

struct EntrySheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    let context: EntryContext

    @State private var v1: String
    @State private var v2: String
    @State private var v3: String
    @State private var note: String
    @State private var day: Date
    @State private var quality: Int
    @State private var kind: String
    @State private var showDeleteConfirm = false

    private let exerciseKinds = ["走路", "跑步", "骑行", "力量", "游泳", "其他"]

    init(context: EntryContext) {
        self.context = context
        let record = context.record
        _v1 = State(initialValue: Fmt.plain(record?.v1))
        _v2 = State(initialValue: Fmt.plain(record?.v2))
        _v3 = State(initialValue: Fmt.plain(record?.v3))
        _note = State(initialValue: record?.note ?? "")
        _day = State(initialValue: record?.day ?? Date())
        _quality = State(initialValue: Int(record?.v2 ?? 3))
        _kind = State(initialValue: record?.text ?? "走路")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("日期", selection: $day, displayedComponents: .date)
                }

                Section {
                    switch context.type {
                    case .weight:
                        numberRow("体重", unit: "kg", text: $v1, keyboard: .decimalPad)
                        numberRow("体脂率（可选）", unit: "%", text: $v2, keyboard: .decimalPad)
                    case .bp:
                        numberRow("收缩压（高压）", unit: "mmHg", text: $v1, keyboard: .numberPad)
                        numberRow("舒张压（低压）", unit: "mmHg", text: $v2, keyboard: .numberPad)
                        numberRow("脉搏（可选）", unit: "bpm", text: $v3, keyboard: .numberPad)
                    case .hr:
                        numberRow("心率", unit: "bpm", text: $v1, keyboard: .numberPad)
                    case .sleep:
                        numberRow("睡眠时长", unit: "小时", text: $v1, keyboard: .decimalPad)
                        Picker("睡眠质量", selection: $quality) {
                            ForEach(1...5, id: \.self) { q in
                                Text(Fmt.quality(q)).tag(q)
                            }
                        }
                    case .exercise:
                        numberRow("运动时长", unit: "分钟", text: $v1, keyboard: .numberPad)
                        Picker("运动类型", selection: $kind) {
                            ForEach(exerciseKinds, id: \.self) { k in
                                Text(k).tag(k)
                            }
                        }
                    case .steps:
                        numberRow("步数", unit: "步", text: $v1, keyboard: .numberPad)
                    }
                } header: {
                    Text(context.type.title)
                } footer: {
                    Text(footerText)
                }

                Section("备注") {
                    TextField("例如：空腹、运动后、服药前", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }

                if context.record != nil {
                    Section {
                        Button("删除这条记录", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle(context.record == nil ? "记录\(context.type.title)" : "编辑\(context.type.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .confirmationDialog("确定删除这条记录？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    if let record = context.record { store.delete(record) }
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    private var footerText: String {
        switch context.type {
        case .weight: return "同一日期重复记录会以最新一条为准显示在趋势里。"
        case .bp: return "建议在安静坐姿 5 分钟后测量，并记录测量前后是否服药。"
        case .hr: return "可记录静息心率或运动后的即时心率。"
        case .sleep: return "记录昨晚的睡眠总时长，可选一个主观质量。"
        case .exercise: return "同一天多次运动会累加计入趋势。"
        case .steps: return "可直接填手机或手表显示的当日步数。"
        }
    }

    private func numberRow(_ title: String, unit: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
            Text(unit)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var canSave: Bool {
        switch context.type {
        case .weight, .hr, .sleep, .exercise, .steps:
            return Fmt.parse(v1) != nil
        case .bp:
            return Fmt.parse(v1) != nil && Fmt.parse(v2) != nil
        }
    }

    private func save() {
        guard canSave, let primary = Fmt.parse(v1) else { return }

        var record = context.record ?? Record(type: context.type, day: Calendar.current.startOfDay(for: day))
        record.type = context.type
        record.day = Calendar.current.startOfDay(for: day)

        switch context.type {
        case .weight:
            record.v1 = primary
            record.v2 = Fmt.parse(v2)
        case .bp:
            record.v1 = primary
            record.v2 = Fmt.parse(v2)
            record.v3 = Fmt.parse(v3)
        case .hr, .steps:
            record.v1 = primary
        case .sleep:
            record.v1 = primary
            record.v2 = Double(quality)
        case .exercise:
            record.v1 = primary
            record.text = kind
        }

        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        record.note = trimmed.isEmpty ? nil : trimmed

        if context.record == nil {
            store.add(record)
        } else {
            store.update(record)
        }
        dismiss()
    }
}
