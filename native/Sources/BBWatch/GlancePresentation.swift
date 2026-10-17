import Foundation

/// A display value: no inferred receipts, elapsed times, or mutation decisions.
struct GlancePresentation: Hashable {
    var symbol: String
    var status: String
    var text: String
    var detail: String? = nil
    var sourceID: String

    static func project(threadID: String?, state: BBThreadState?, connected: Bool, stale: Bool,
                        delivery: RecordingDraft?, sending: Bool) -> Self {
        if let delivery {
            let status = delivery.creatingRequestID != nil ? "Waiting for new thread" : delivery.state == .checkingDelivery && sending ? "Sending transcript" : label(delivery.state)
            let detail: String?
            switch delivery.state {
            case .checkingDelivery: detail = sending ? "Original saved on watch." : "Check BB before retrying. Audio saved."
            case .failed: detail = "Original saved. Open to review."
            case .queued: detail = delivery.creatingRequestID != nil ? "Waiting for its first request. Audio saved." : connected ? "Waiting for delivery." : "Connect BB to continue. Audio saved."
            default: detail = "Original saved on watch."
            }
            return Self(symbol: symbol(delivery.state, sending: sending), status: status, text: status, detail: detail, sourceID: delivery.id.uuidString)
        }
        let latest = state?.messages.last
        let text = state?.working == true ? (state?.activity ?? latest?.text ?? "Agent is working.") : (latest?.text ?? "Record a message to begin.")
        if !connected { return Self(symbol: "wifi.slash", status: "Offline", text: text, detail: "Offline · showing saved content", sourceID: threadID ?? "offline") }
        if stale { return Self(symbol: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90", status: "Update failed", text: text, detail: "Could not update · showing saved content", sourceID: threadID ?? "stale") }
        guard let status = state?.status else { return Self(symbol: "arrow.trianglehead.2.clockwise", status: "Updating", text: text, detail: "Updating conversation", sourceID: threadID ?? "loading") }
        if status == "waiting-for-host" { return Self(symbol: "network.slash", status: "Waiting for host", text: text, detail: "Waiting for BB host", sourceID: threadID ?? "waiting") }
        if state?.failed == true { return Self(symbol: "exclamationmark.circle", status: "Agent error", text: text, detail: "Agent stopped with an error", sourceID: threadID ?? "error") }
        let working = state?.working == true
        // An idle thread with a last user message does not prove an agent result.
        let complete = !working && latest?.role == "assistant" && ["idle", "completed"].contains(status)
        return Self(symbol: working ? "circle.dotted" : complete ? "checkmark.circle" : "text.bubble", status: working ? "Working" : complete ? "Reply" : "Message", text: text, sourceID: latest?.id ?? threadID ?? "empty")
    }
    static func label(_ state: RecordingState) -> String {
        switch state {
        case .draft: "Saved on watch"
        case .queued: "Queued on watch"
        case .transcribing: "Transcribing"
        case .checkingDelivery: "Delivery unconfirmed"
        case .accepted: "Accepted by BB"
        case .failed: "Not sent"
        }
    }
    static func symbol(_ state: RecordingState, sending: Bool = false) -> String {
        switch state {
        case .draft: "waveform"
        case .queued: "clock"
        case .transcribing: "waveform.and.magnifyingglass"
        case .checkingDelivery: sending ? "arrow.up" : "questionmark.circle"
        case .accepted: "checkmark.circle"
        case .failed: "exclamationmark.circle"
        }
    }
}
