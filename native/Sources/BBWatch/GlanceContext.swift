import Foundation

private struct NewContext: Codable {
    var identity: String
    var enabled: Bool
    var projectID: String?
    var pendingCreationID: UUID?
    var providerID: String?
    var modelID: String?
    var modelName: String?
}

extension AppModel {
    var activeDraft: RecordingDraft? { activeID.flatMap(draft) }
    var contextDestination: RecordingDestination? {
        if let activeDraft { return activeDraft.destination }
        return recordTarget
    }
    var contextTitle: String {
        guard let destination = contextDestination else { return activeID != nil ? "Choose recipient" : newThreadMode ? "New" : currentThread?.displayTitle ?? "Choose thread" }
        switch destination {
        case .thread(let id): return threads.first { $0.id == id }?.displayTitle ?? "Saved thread"
        case .project: return "New"
        }
    }
    var contextThread: BBThread? {
        guard case .thread(let id) = contextDestination else { return nil }
        return threads.first { $0.id == id }
    }
    var contextProject: BBProject? {
        if case .project(let id) = activeDraft?.destination { return projects.first { $0.id == id } }
        return newThreadProject
    }
    var contextModelName: String {
        if let activeDraft { return activeDraft.modelName ?? "Project default" }
        return selectedModelName ?? "Project default"
    }
    var currentDelivery: RecordingDraft? {
        let unfinished: [RecordingState] = [.queued, .transcribing, .checkingDelivery, .failed]
        return drafts.filter { value in
            guard value.id != activeID else { return false }
            if value.id == focusedDeliveryID, value.state == .accepted, stage?.status == nil { return true }
            guard unfinished.contains(value.state) else { return false }
            if let focusedDeliveryID, value.id == focusedDeliveryID { return true }
            if case .thread = recordTarget { return value.destination == recordTarget }
            return value.id == pendingCreationID
        }.max { ($0.enqueuedAt ?? $0.createdAt) < ($1.enqueuedAt ?? $1.createdAt) }
    }
    var presentation: GlancePresentation {
        GlancePresentation.project(threadID: currentThreadID, state: stage, connected: connected,
                                   stale: stageSyncFailed, delivery: currentDelivery,
                                   sending: currentDelivery.map { sending.contains($0.id) } ?? false)
    }
    func destinationLabel(_ value: RecordingDraft) -> String {
        switch value.destination {
        case .thread(let id): threads.first { $0.id == id }?.displayTitle ?? "Saved thread"
        case .project(let id): "New · " + (projects.first { $0.id == id }?.name ?? "Saved project")
        case nil: "Choose recipient"
        }
    }
    func recordingTopic(_ value: RecordingDraft) -> String {
        guard let text = value.transcript?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return "Voice recording" }
        return text
    }
    func selectThread(_ threadID: String) {
        if var value = activeDraft {
            guard value.state == .draft, value.enqueuedAt == nil else { return }
            value.creatingRequestID = nil
            value.destination = .thread(id: threadID)
            value.providerID = nil; value.modelID = nil; value.modelName = nil
            do { try save(value) } catch { self.error = error.localizedDescription }
        } else {
            currentThreadID = threadID; newThreadMode = false; pendingCreationID = nil; focusedDeliveryID = nil; recorderPresented = false
        }
    }
    func selectNew() {
        if activeID == nil { pendingCreationID = nil }
        if newThreadProject == nil {
            newThreadProject = projects.first { $0.id == currentThread?.projectId } ?? projects.first
        }
        if var value = activeDraft {
            guard value.state == .draft, value.enqueuedAt == nil else { return }
            value.creatingRequestID = nil
            value.destination = newThreadProject.map { .project(id: $0.id) }
            value.providerID = selectedProviderID; value.modelID = selectedModelID; value.modelName = selectedModelName
            do { try save(value) } catch { self.error = error.localizedDescription }
        } else { newThreadMode = true; recorderPresented = false; focusedDeliveryID = nil }
    }
    func selectProject(_ project: BBProject) {
        if activeID == nil { pendingCreationID = nil }
        newThreadProject = project
        selectedProviderID = nil; selectedModelID = nil; selectedModelName = nil
        if var value = activeDraft, value.state == .draft, value.enqueuedAt == nil {
            value.creatingRequestID = nil
            value.destination = .project(id: project.id); value.providerID = nil; value.modelID = nil; value.modelName = nil
            do { try save(value) } catch { self.error = error.localizedDescription }
        }
    }
    func selectModel(providerID: String?, modelID: String?, name: String?) {
        selectedProviderID = providerID; selectedModelID = modelID; selectedModelName = name
        if var value = activeDraft, value.state == .draft, value.enqueuedAt == nil, case .project = value.destination {
            value.providerID = providerID; value.modelID = modelID; value.modelName = name
            do { try save(value) } catch { self.error = error.localizedDescription }
        }
    }
    func followCreatedThread(_ thread: BBThread, requestID: UUID) {
        if !threads.contains(where: { $0.id == thread.id }) { threads.append(thread) }
        guard pendingCreationID == requestID, newThreadMode else { return }
        currentThreadID = thread.id; newThreadMode = false; pendingCreationID = nil
    }
    func persistNewContext() {
        guard !isFixture else { return }
        let context = NewContext(identity: identity, enabled: newThreadMode, projectID: newThreadProject?.id, pendingCreationID: pendingCreationID,
                                 providerID: selectedProviderID, modelID: selectedModelID, modelName: selectedModelName)
        if let data = try? JSONEncoder().encode(context) { UserDefaults.standard.set(data, forKey: "newThreadContext") }
    }
    func restoreNewContext() {
        guard let data = UserDefaults.standard.data(forKey: "newThreadContext"),
              let context = try? JSONDecoder().decode(NewContext.self, from: data), context.identity == identity else { return }
        newThreadProject = projects.first { $0.id == context.projectID }
        selectedProviderID = context.providerID; selectedModelID = context.modelID; selectedModelName = context.modelName
        newThreadMode = context.enabled
        pendingCreationID = context.pendingCreationID
        if let id = pendingCreationID, let parent = draft(id), parent.state == .accepted, case .thread(let threadID) = parent.destination, parent.serverIdentity == identity, newThreadMode {
            currentThreadID = threadID; newThreadMode = false; pendingCreationID = nil
        }
    }
    func reopen(_ id: UUID) {
        guard activeID == nil, var value = draft(id), [.draft, .failed].contains(value.state), value.recoveryIssue == nil else { return }
        value.state = .draft; value.enqueuedAt = nil; value.error = nil
        do { try save(value); activeID = id; recorderPresented = true }
        catch { self.error = error.localizedDescription }
    }
}
