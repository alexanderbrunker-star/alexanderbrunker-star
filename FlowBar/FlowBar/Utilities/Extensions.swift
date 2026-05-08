import SwiftUI
import Foundation

// MARK: - Date

extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    var shortFormatted: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .none
        fmt.timeStyle = .short
        return fmt.string(from: self)
    }
}

// MARK: - Color

extension Color {
    static let glassBackground = Color(NSColor.windowBackgroundColor).opacity(0.85)
}

// MARK: - View

extension View {
    func cardStyle() -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}

// MARK: - String

extension String {
    var expandingTildeInPath: String {
        (self as NSString).expandingTildeInPath
    }

    func truncated(to maxLength: Int) -> String {
        count > maxLength ? String(prefix(maxLength)) + "…" : self
    }
}

// MARK: - WorkflowStatus Color (SwiftUI)

extension WorkflowStatus {
    var swiftUIColor: Color {
        switch self {
        case .idle:     return .gray
        case .running:  return .blue
        case .success:  return .green
        case .failed:   return .red
        case .skipped:  return .orange
        case .disabled: return .gray.opacity(0.5)
        }
    }
}
