import SwiftUI
import UIKit

enum Theme {
    static let accent = Color(red: 0.055, green: 0.541, blue: 0.408)
    static let bg = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let line = Color(uiColor: .separator).opacity(0.55)
    static let danger = Color(red: 0.82, green: 0.29, blue: 0.29)
}

extension MetricType {
    var tint: Color {
        switch self {
        case .weight: return Theme.accent
        case .bp: return Color(red: 0.84, green: 0.32, blue: 0.30)
        case .hr: return Color(red: 0.90, green: 0.25, blue: 0.36)
        case .sleep: return Color(red: 0.36, green: 0.42, blue: 0.78)
        case .exercise: return Color(red: 0.93, green: 0.55, blue: 0.18)
        case .steps: return Color(red: 0.20, green: 0.62, blue: 0.86)
        }
    }
}

struct CardBackground: ViewModifier {
    var radius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Theme.line, lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle(radius: CGFloat = 20) -> some View {
        modifier(CardBackground(radius: radius))
    }
}
