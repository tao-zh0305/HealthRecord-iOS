import SwiftUI
import UIKit

struct SummaryCard: View {
    let title: String
    let value: String
    let unit: String
    let sub: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(tint).frame(width: 7, height: 7)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Text(sub)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(14)
        .cardStyle(radius: 20)
    }
}

struct QuickButton: View {
    let type: MetricType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(type.tint)
                    .frame(width: 38, height: 38)
                    .background(type.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                Text(type.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .cardStyle(radius: 18)
        }
        .buttonStyle(.plain)
    }
}

struct RecordRow: View {
    let record: Record

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.type.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(record.type.tint)
                .frame(width: 34, height: 34)
                .background(record.type.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(record.type.title)
                        .font(.subheadline.weight(.semibold))
                    Text(DateText.time(record.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if record.note == "Apple 健康" || record.note == "快捷指令" {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.accent)
                    }
                }
                Text(record.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .cardStyle(radius: 16)
        .contentShape(Rectangle())
    }
}

struct EmptyCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
