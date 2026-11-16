import SwiftUI
import Charts

struct TrendsView: View {
    @EnvironmentObject var store: Store
    @State private var metric: MetricType = .weight
    @State private var days: Int = 30

    private var series: [SeriesPoint] { store.dailySeries(metric, days: days) }
    private var recent: [Record] { Array(store.records.filter { $0.type == metric }.prefix(5)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("趋势")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                    Text("\(metric.title) · 最近 \(days) 天")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 16)

                chips
                rangePicker
                chartCard
                statsGrid
                recentCard
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(MetricType.allCases) { type in
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { metric = type }
                    } label: {
                        Text(type.title)
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background(metric == type ? Theme.ink : Theme.card, in: Capsule())
                            .foregroundStyle(metric == type ? Theme.bg : Color.secondary)
                            .overlay(
                                Capsule().stroke(Theme.line, lineWidth: metric == type ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var rangePicker: some View {
        Picker("范围", selection: $days) {
            Text("7 天").tag(7)
            Text("30 天").tag(30)
            Text("90 天").tag(90)
        }
        .pickerStyle(.segmented)
        .padding(.top, 10)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if series.isEmpty {
                EmptyCard(title: "还没有\(metric.title)数据",
                          subtitle: "记录几条后，这里会出现趋势曲线。")
            } else {
                chart
                if metric == .bp {
                    HStack(spacing: 14) {
                        legendItem("收缩压", Color(red: 0.84, green: 0.32, blue: 0.30))
                        legendItem("舒张压", Color(red: 0.36, green: 0.42, blue: 0.78))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .cardStyle()
        .padding(.top, 12)
    }

    private var chart: some View {
        Chart {
            if metric == .bp {
                ForEach(series) { point in
                    LineMark(x: .value("日期", point.date),
                             y: .value("数值", point.value))
                        .foregroundStyle(by: .value("类型", "收缩压"))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    if let low = point.second {
                        LineMark(x: .value("日期", point.date),
                                 y: .value("数值", low))
                            .foregroundStyle(by: .value("类型", "舒张压"))
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    }
                }
            } else {
                ForEach(series) { point in
                    AreaMark(x: .value("日期", point.date),
                             y: .value("数值", point.value))
                        .foregroundStyle(
                            LinearGradient(colors: [metric.tint.opacity(0.24), metric.tint.opacity(0.02)],
                                           startPoint: .top,
                                           endPoint: .bottom)
                        )
                    LineMark(x: .value("日期", point.date),
                             y: .value("数值", point.value))
                        .foregroundStyle(metric.tint)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    if series.count <= 14 {
                        PointMark(x: .value("日期", point.date),
                                  y: .value("数值", point.value))
                            .foregroundStyle(metric.tint)
                            .symbolSize(20)
                    }
                }
            }
        }
        .chartForegroundStyleScale([
            "收缩压": Color(red: 0.84, green: 0.32, blue: 0.30),
            "舒张压": Color(red: 0.36, green: 0.42, blue: 0.78)
        ])
        .chartLegend(metric == .bp ? .visible : .hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month().day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .frame(height: 200)
    }

    private func legendItem(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Capsule().fill(color).frame(width: 14, height: 3)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var stats: [(String, String, String)] {
        let values = series.map { $0.value }
        guard !values.isEmpty, let last = series.last else { return [] }
        let average = values.reduce(0, +) / Double(values.count)

        if metric == .bp {
            let lowers = series.compactMap { $0.second }
            let averageLow = lowers.isEmpty ? 0 : lowers.reduce(0, +) / Double(lowers.count)
            return [
                ("最近", Fmt.int(last.value) + "/" + Fmt.int(last.second), "mmHg"),
                ("平均高压", Fmt.int(average), "mmHg"),
                ("平均低压", Fmt.int(averageLow), "mmHg"),
                ("记录天数", "\(series.count)", "天")
            ]
        }

        return [
            ("最近", Fmt.num(last.value), metric.unit),
            ("平均", Fmt.num(average), metric.unit),
            ("最低", Fmt.num(values.min() ?? 0), metric.unit),
            ("最高", Fmt.num(values.max() ?? 0), metric.unit)
        ]
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 9),
                            GridItem(.flexible(), spacing: 9)],
                  spacing: 9) {
            ForEach(Array(stats.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.0)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(item.1)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(item.2)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(.top, 12)
        .opacity(stats.isEmpty ? 0 : 1)
    }

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("最近记录")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)

            if recent.isEmpty {
                Text("暂无")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 10)
            } else {
                ForEach(Array(recent.enumerated()), id: \.element.id) { index, record in
                    HStack {
                        Text(DateText.day(record.day))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(record.summary)
                            .font(.footnote.weight(.semibold))
                    }
                    .padding(.vertical, 9)
                    if index < recent.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(14)
        .cardStyle()
        .padding(.top, 12)
    }
}
