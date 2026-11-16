import Foundation

enum MetricType: String, Codable, CaseIterable, Identifiable {
    case weight, bp, hr, sleep, exercise, steps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: return "体重"
        case .bp: return "血压"
        case .hr: return "心率"
        case .sleep: return "睡眠"
        case .exercise: return "运动"
        case .steps: return "步数"
        }
    }

    var unit: String {
        switch self {
        case .weight: return "kg"
        case .bp: return "mmHg"
        case .hr: return "bpm"
        case .sleep: return "小时"
        case .exercise: return "分钟"
        case .steps: return "步"
        }
    }

    var symbol: String {
        switch self {
        case .weight: return "scalemass.fill"
        case .bp: return "waveform.path.ecg"
        case .hr: return "heart.fill"
        case .sleep: return "bed.double.fill"
        case .exercise: return "figure.run"
        case .steps: return "figure.walk"
        }
    }

    var chartTitle: String { title }
}

struct Record: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var type: MetricType
    var day: Date
    var createdAt: Date = Date()
    var v1: Double? = nil
    var v2: Double? = nil
    var v3: Double? = nil
    var text: String? = nil
    var note: String? = nil

    var summary: String {
        switch type {
        case .weight:
            var s = Fmt.num(v1) + " kg"
            if let fat = v2 { s += " · 体脂 " + Fmt.num(fat) + "%" }
            return s
        case .bp:
            var s = Fmt.int(v1) + "/" + Fmt.int(v2) + " mmHg"
            if let p = v3 { s += " · 脉搏 " + Fmt.int(p) }
            return s
        case .hr:
            return Fmt.int(v1) + " bpm"
        case .sleep:
            var s = Fmt.num(v1) + " 小时"
            if let q = v2 { s += " · " + Fmt.quality(Int(q)) }
            return s
        case .exercise:
            var s = Fmt.num(v1) + " 分钟"
            if let k = text, !k.isEmpty { s += " · " + k }
            return s
        case .steps:
            return Fmt.group(v1) + " 步"
        }
    }
}

struct SeriesPoint: Identifiable {
    var date: Date
    var value: Double
    var second: Double?

    var id: Date { date }
}

enum Fmt {
    static func num(_ v: Double?) -> String {
        guard let v = v else { return "—" }
        if abs(v - v.rounded()) < 0.0001 { return String(Int(v.rounded())) }
        return String(format: "%.1f", v)
    }

    static func int(_ v: Double?) -> String {
        guard let v = v else { return "—" }
        return String(Int(v.rounded()))
    }

    static func group(_ v: Double?) -> String {
        guard let v = v else { return "—" }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? String(Int(v))
    }

    static func plain(_ v: Double?) -> String {
        guard let v = v else { return "" }
        if abs(v - v.rounded()) < 0.0001 { return String(Int(v.rounded())) }
        return String(format: "%.1f", v)
    }

    static func quality(_ q: Int) -> String {
        switch q {
        case 1: return "很差"
        case 2: return "较差"
        case 3: return "一般"
        case 4: return "良好"
        default: return "很好"
        }
    }

    static func parse(_ s: String) -> Double? {
        let t = s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        return Double(t)
    }
}

enum DateText {
    static func greeting() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 5 { return "夜深了" }
        if h < 11 { return "早上好" }
        if h < 14 { return "中午好" }
        if h < 18 { return "下午好" }
        return "晚上好"
    }

    static func long(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: d)
    }

    static func day(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f.string(from: d)
    }

    static func time(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    static func relative(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "今天 " + time(d) }
        if cal.isDateInYesterday(d) { return "昨天 " + time(d) }
        return day(d) + " " + time(d)
    }
}
