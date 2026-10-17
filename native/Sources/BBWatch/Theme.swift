import SwiftUI

/// One mood drives the whole screen: background colour, the big word, the glass tint.
enum Mood: Equatable {
    case offline, idle, loading, syncFailed, waiting, working, needsYou, done, error, recording, sending

    var tint: Color {
        switch self {
        case .offline, .loading, .waiting: Color(white: 0.55)
        case .idle: Color(white: 0.92)
        case .working: Color(red: 0.80, green: 1.00, blue: 0.20)   // volt
        case .needsYou: Color(red: 1.00, green: 0.47, blue: 0.12)  // infrared
        case .done: Color(red: 0.45, green: 0.90, blue: 1.00)      // glacier
        case .error, .syncFailed: Color(red: 1.00, green: 0.30, blue: 0.32)
        case .recording: Color(red: 1.00, green: 0.23, blue: 0.19)
        case .sending: Color(red: 0.70, green: 0.60, blue: 1.00)
        }
    }
    var word: String {
        switch self {
        case .offline: "OFFLINE"
        case .idle: "READY"
        case .loading: "LOADING"
        case .syncFailed: "SYNC FAILED"
        case .waiting: "WAITING"
        case .working: "WORKING"
        case .needsYou: "NEEDS YOU"
        case .done: "DONE"
        case .error: "FAILED"
        case .recording: "REC"
        case .sending: "SENDING"
        }
    }
    var glow: Double {
        switch self { case .idle, .offline, .loading, .waiting: 0.28; default: 0.6 }
    }
}

/// Full-screen stage: black base, one colour bleeding in from below, the BB mark as frosted glass.
struct Stage: View {
    var mood: Mood
    @Environment(\.isLuminanceReduced) private var dimmed
    var body: some View {
        // Overlays keep the oversized logo out of layout: the stage must never grow past the screen.
        Color.black
            .overlay { RadialGradient(colors: [mood.tint.opacity(dimmed ? 0.15 : mood.glow), .clear], center: UnitPoint(x: 0.5, y: 1.2), startRadius: 8, endRadius: 250) }
            .overlay {
                Image("BBLogo").renderingMode(.template).resizable().scaledToFit()
                    .frame(width: 250)
                    .rotationEffect(.degrees(-14))
                    .offset(x: 62, y: 52)
                    .foregroundStyle(.ultraThinMaterial)
                    .opacity(dimmed ? 0.4 : 0.9)
            }
            .clipped()
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.9), value: mood)
    }
}

extension Font {
    /// The poster face: SF Compact, black, condensed. Numbers stay tabular.
    static func poster(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .default).width(.condensed) }
    static let kicker = Font.system(size: 12, weight: .semibold).width(.condensed)
}

struct Kicker: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.kicker).tracking(1.2).lineLimit(1).foregroundStyle(.secondary)
    }
}

/// Glass capsule button used across pages.
struct GlassButton: View {
    let title: String
    var symbol: String? = nil
    var tint: Color = .white
    var prominent = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).font(.system(size: 14, weight: .bold)) }
                Text(title).font(.system(size: 15, weight: .bold).width(.condensed))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(prominent ? .black : tint)
            .padding(.horizontal, 14).padding(.vertical, 8).frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .glassEffect(prominent ? .regular.tint(tint).interactive() : .regular.interactive(), in: .capsule)
    }
}

func haptic(_ type: WKHapticType) { WKInterfaceDevice.current().play(type) }

func relativeLabel(_ millis: Double?) -> String {
    guard let millis, millis > 0 else { return "" }
    let seconds = max(0, Date().timeIntervalSince1970 - millis / 1000)
    switch seconds {
    case ..<60: return "now"
    case ..<3600: return "\(Int(seconds / 60))m"
    case ..<86400: return "\(Int(seconds / 3600))h"
    default: return "\(Int(seconds / 86400))d"
    }
}

func durationLabel(_ value: TimeInterval) -> String {
    let seconds = max(0, Int(value))
    return seconds >= 3600 ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) : String(format: "%02d:%02d", seconds / 60, seconds % 60)
}
func statusLabel(_ value: RecordingState) -> String {
    switch value {
    case .draft: "Saved on watch"
    case .queued: "Queued"
    case .transcribing: "Transcribing"
    case .checkingDelivery: "Checking delivery"
    case .accepted: "Delivered"
    case .failed: "Send failed"
    }
}
