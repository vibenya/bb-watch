import Foundation

extension AppModel {
    /// Debug simulator only. Private, separate storage and no network loops or mutations.
    func configureFixture(_ scenario: String) {
        #if DEBUG && targetEnvironment(simulator)
        do {
            connection = ConnectionSettings(serverURL: "https://fixture.invalid", token: "local-fixture", machineID: "fixture")
            projects = [BBProject(id: "demo", name: "Watch app"), BBProject(id: "website", name: "Website")]
            threads = [BBThread(id: "watch", title: "Watch sync", projectId: "demo", updatedAt: Date().addingTimeInterval(-480).timeIntervalSince1970 * 1000, status: "active"),
                       BBThread(id: "release", title: "Release notes", projectId: "demo", updatedAt: Date().addingTimeInterval(-720).timeIntervalSince1970 * 1000, status: "idle")]
            currentThreadID = "watch"
            stage = BBThreadState(messages: [BBMessage(id: "request", role: "user", text: "Fix reply switching on the watch."), BBMessage(id: "reply", role: "assistant", text: "Reply switching now keeps each conversation in context. The saved recordings remain available.\n\nFull details: selecting a thread refreshes its messages independently from the sidebar. Existing audio is kept on the watch if a request fails.")], status: "active", working: true, activity: "Checking replies after switching conversations.")
            lastSync = Date()
            let sent = RecordingDraft(createdAt: Date().addingTimeInterval(-900), duration: 14, state: .accepted, destination: .thread(id: "release"), transcript: "Draft release notes", acceptanceReceipt: "fixture receipt")
            try save(sent)
            switch scenario {
            case "new", "lifecycle": selectNew()
            case "recording", "paused":
                let value = RecordingDraft(duration: 8, destination: .thread(id: "watch"), transcript: "Check the reply after switching threads.")
                try save(value); activeID = value.id; recorderPresented = true; fixtureRecording = scenario == "recording"
            case "question", "unsupported":
                stage?.working = false; stage?.status = "idle"
                questions = [BBQuestion(id: "q", threadID: "watch", title: "Watch sync", prompt: "Which version should I keep?", options: [BBOption(id: "simple", label: "Keep the simple version"), BBOption(id: "detailed", label: "Show the detailed version")], supported: scenario != "unsupported", questionID: "version")]
            case "result": stage?.working = false; stage?.status = "idle"
            case "offline": connection = ConnectionSettings(); stageSyncFailed = true
            case "stale": stageSyncFailed = true
            case "loading": stage?.status = nil; stage?.working = false
            case "waiting": stage?.status = "waiting-for-host"; stage?.working = false
            case "agent-error": stage?.failed = true; stage?.working = false; stage?.status = "error"
            case "transcribing", "sending", "unknown", "failed", "queued":
                let state: RecordingState = scenario == "transcribing" ? .transcribing : scenario == "failed" ? .failed : scenario == "queued" ? .queued : .checkingDelivery
                let value = RecordingDraft(duration: 12, enqueuedAt: Date(), state: state, destination: .thread(id: "watch"), transcript: "Check thread switching", error: scenario == "failed" ? "Transcription was unavailable. Your original is saved." : nil)
                try save(value); focusedDeliveryID = value.id
                if scenario == "sending" || scenario == "transcribing" { sending.insert(value.id) }
            default: break
            }
        } catch { self.error = error.localizedDescription }
        #endif
    }
    func advanceFixture() {
        #if DEBUG && targetEnvironment(simulator)
        guard fixtureScenario == "lifecycle", let id = fixtureRequestID, var value = draft(id) else { return }
        fixtureStep += 1
        switch fixtureStep {
        case 2: value.state = .checkingDelivery
        case 3:
            value.state = .accepted; value.acceptanceReceipt = "fixture receipt"
            value.destination = .thread(id: "created")
            followCreatedThread(BBThread(id: "created", title: "New request", projectId: "demo"), requestID: id)
            if currentThreadID == "created" { stage = nil }; sending.remove(id)
        case 4: if currentThreadID == "created" { stage = BBThreadState(status: "active", working: true, activity: "Checking the requested changes.") }
        case 5: if currentThreadID == "created" { stage = BBThreadState(messages: [BBMessage(id: "new-reply", role: "assistant", text: "The requested changes are ready for review.")], status: "idle") }
        default: break
        }
        do { try save(value); drafts = try store?.resolveCreationDependencies() ?? drafts } catch { self.error = error.localizedDescription }
        #endif
    }

    func fixtureDeliver(_ id: UUID, destination: RecordingDestination?) {
        #if DEBUG && targetEnvironment(simulator)
        guard var value = draft(id), [.draft, .failed].contains(value.state) else { return }
        if let destination { value.destination = destination }
        guard let target = value.destination else { return }
        value.state = .transcribing; value.enqueuedAt = Date(); value.serverIdentity = identity
        do { try save(value) } catch { self.error = error.localizedDescription; return }
        if case .project(let projectID) = target {
            newThreadMode = true; newThreadProject = projects.first { $0.id == projectID }
            pendingCreationID = value.creatingRequestID ?? id
        }
        fixtureRequestID = id
        fixtureStep = 1
        sending.insert(id)
        fixtureRecording = false; activeID = nil; recorderPresented = false; focusedDeliveryID = id
        if case .thread(let threadID) = target { currentThreadID = threadID; newThreadMode = false }
        #endif
    }
}
