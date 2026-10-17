import Foundation

@main struct GlancePresentationCheck {
    static func main() throws {
        func project(_ state: BBThreadState? = nil, connected: Bool = true, stale: Bool = false, draft: RecordingDraft? = nil, sending: Bool = false) -> GlancePresentation {
            .project(threadID: "exact-child", state: state, connected: connected, stale: stale, delivery: draft, sending: sending)
        }
        let reply = BBMessage(id: "reply", role: "assistant", text: "The full original is here.")
        let user = BBMessage(id: "user", role: "user", text: "Another request")
        let previous = BBThreadState(messages: [reply, user], status: "idle")
        precondition(project(previous).status == "Message", "An old reply must not mark a later user request done")
        precondition(project(BBThreadState(messages: [reply], status: "idle")).status == "Reply")
        precondition(project(previous, stale: true).status == "Update failed")
        precondition(project(previous, connected: false).status == "Offline")
        precondition(project(BBThreadState(messages: [reply])).status == "Updating")
        let active = BBThreadState(messages: [reply], status: "active", working: true, activity: "Checking the current task")
        precondition(project(active).text == "Checking the current task")
        let repeatedPoll = BBThreadState(messages: [BBMessage(id: "reply", role: "assistant", text: "The full original is here.")], status: "active", working: true, activity: "Checking the current task")
        precondition(project(active) == project(repeatedPoll), "Independent identical polls retain presentation identity")
        var progressed = repeatedPoll; progressed.activity = "Verifying the result"
        precondition(project(active) != project(progressed), "Changed source content replaces the complete text block")
        var unknown = RecordingDraft(state: .checkingDelivery, destination: .thread(id: "exact-child"))
        precondition(project(active, draft: unknown).status == "Delivery unconfirmed")
        precondition(project(active, draft: unknown, sending: true).status == "Sending transcript")
        unknown.state = .accepted; unknown.acceptanceReceipt = "receipt"
        precondition(project(draft: unknown).status == "Accepted by BB", "A send receipt is not agent completion")
        unknown.state = .transcribing
        precondition(project(draft: unknown).status == "Transcribing")
        print("PASS: source freshness, latest-message role, activity, receipt vs completion, ambiguous mutation, stable presentation")
    }
}
