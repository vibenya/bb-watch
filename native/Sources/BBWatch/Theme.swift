import SwiftUI
import WatchKit

enum GlanceStyle {
    static let lime = Color(red: 213 / 255, green: 1, blue: 0)
    static let surface = Color(white: 0.09)
}

/// Semantic fonts scale with the user's watch text size.
extension Font {
    static let glance = Font.system(.callout, design: .rounded)
    static let kicker = Font.system(.caption2, design: .rounded)
}
struct Kicker: View {
    let text: String
    var body: some View { Text(text).font(.kicker).foregroundStyle(.secondary) }
}
struct GlassButton: View {
    let title: String
    var symbol: String? = nil
    var tint: Color = .white
    var prominent = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol) }
                Text(title).fixedSize(horizontal: false, vertical: true)
            }.font(.glance).frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.bordered).tint(prominent ? tint : GlanceStyle.surface)
        .foregroundStyle(prominent ? .black : tint)
    }
}
struct IconAction: View {
    let symbol: String
    let label: String
    var prominent = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(prominent ? GlanceStyle.lime : GlanceStyle.surface, in: Capsule())
        .foregroundStyle(prominent ? .black : .white)
        .accessibilityLabel(label)
    }
}
func haptic(_ type: WKHapticType) { WKInterfaceDevice.current().play(type) }
func relativeLabel(_ millis: Double?) -> String {
    guard let millis, millis.isFinite, millis > 0 else { return "" }
    let seconds = max(0, Date().timeIntervalSince1970 - millis / 1000)
    switch seconds {
    case ..<60: return "Just now"
    case ..<3600: return "\(Int(seconds / 60))m ago"
    case ..<86400: return "\(Int(seconds / 3600))h ago"
    default: return "\(Int(seconds / 86400))d ago"
    }
}
func durationLabel(_ value: TimeInterval) -> String {
    let seconds = value.isFinite ? max(0, Int(value)) : 0
    return seconds >= 3600 ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) : String(format: "%02d:%02d", seconds / 60, seconds % 60)
}
func statusLabel(_ value: RecordingState) -> String {
    switch value {
    case .draft: "Saved on watch"
    case .queued: "Queued on watch"
    case .transcribing: "Transcribing"
    case .checkingDelivery: "Delivery unconfirmed"
    case .accepted: "Accepted by BB"
    case .failed: "Not sent"
    }
}
