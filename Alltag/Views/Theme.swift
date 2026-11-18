import SwiftUI

enum Theme {
    static let deep = Color(red: 0.11, green: 0.29, blue: 0.26)
    static let accent = Color(red: 0.95, green: 0.71, blue: 0.20)
    static let whatsapp = Color(red: 0.12, green: 0.54, blue: 0.36)
    static let warn = Color(red: 0.76, green: 0.33, blue: 0.12)
}

extension Area {
    var color: Color { self == .arbeit ? Theme.deep : Theme.accent }
}

struct Chip: View {
    var text: String
    var color: Color = .secondary
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
