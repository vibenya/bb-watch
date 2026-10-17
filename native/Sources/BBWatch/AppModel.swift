import Foundation
import AVFoundation
import Network
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var drafts: [RecordingDraft] = []
    @Published var pending: [PendingAnswer] = []
    @Published var projects: [BBProject] = []
    @Published var threads: [BBThread] = []
    @Published var questions: [BBQuestion] = []
    @Published var activeID: UUID?
    @Published var error: String?
    @Published var refreshing = false
    @Published var syncError: String?
    @Published var questionsError: String?
    @Published var sending: Set<UUID> = []
    @Published var connection = ConnectionSettings() {
        didSet {
            if oldValue != connection {
                connectionRevision = UUID()
                stageRevision = UUID()
                stage = nil
                stageSyncFailed = false
            }
        }
    }
    @Published var lastSync: Date?
    /// The thread the stage shows and recordings go to by default. Survives relaunch.
    @Published var currentThreadID: String? = UserDefaults.standard.string(forKey: "currentThreadID") {
        didSet {
            UserDefaults.standard.set(currentThreadID, forKey: "currentThreadID")
            if oldValue != currentThreadID { stageRevision = UUID(); stage = nil; stageSyncFailed = false }
        }
    }
    /// Changing away and back must invalidate both requests and the SwiftUI task key.
    @Published private(set) var stageRevision = UUID()
    private var connectionRevision = UUID()
    /// Live projection of the current thread (messages + agent activity).
    @Published var stage: BBThreadState?
    @Published var stageSyncFailed = false
    /// Set when the next recording should open a new thread in this project instead of replying.
    @Published var newThreadProject: BBProject?
    let recorder = WatchRecorder()
    let playback = WatchPlayback()
    private(set) var store: DurableStore?
    private var offlineCache: OfflineCache?
    private var nextAnswerAttempt = Date.distantPast
    private var answering = false
    private var processingQueue = false
    private var queueTask: Task<Void, Never>?
    private let pathMonitor = NWPathMonitor()
    private var cachedClient: BBClient?
    private var cachedClientSettings: ConnectionSettings?
    private var capturePersistenceFailed = false
    private var captureFailures: Set<UUID> = []
    private var clock: Timer?
    var connected: Bool { !connection.token.isEmpty }
    var client: BBClient {
        if cachedClientSettings != connection || cachedClient == nil {
            cachedClient = BBClient(serverURL: URL(string: connection.serverURL) ?? URL(fileURLWithPath: "/"), credential: connection.token)
            cachedClientSettings = connection
        }
        return cachedClient!
    }
    var identity: String { connection.identity }
    var chats: [ChatList.Row] { ChatList.build(threads: threads, projects: projects) }

    init() {
        do {
            let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("BBWatch")
            store = try DurableStore(directory: root)
            connection = try ConnectionSettings.load()
            reload()
            loadCache()
        } catch { self.error = error.localizedDescription }
        Task { await WatchDiagnostics.shared.record(.appStarted) }
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { await WatchDiagnostics.shared.record(path.status == .satisfied ? .networkAvailable : .networkUnavailable) }
            guard path.status == .satisfied else { return }
            Task { @MainActor in self?.resumeQueuedDelivery() }
        }
        pathMonitor.start(queue: DispatchQueue(label: "dev.tokenville.bbwatch.reachability"))
        recorder.onInterruption = { [weak self] in self?.finishCapture() }
        clock = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.commitAnswers() }
        }
    }
    func reload() {
        guard let store else { return }
        do {
            drafts = try store.loadDrafts().filter { $0.serverIdentity == nil || $0.serverIdentity == identity }
            // Transcription has no irreversible BB side effect; interrupted work can resume.
            for index in drafts.indices where drafts[index].state == .transcribing && drafts[index].recoveryIssue == nil && !sending.contains(drafts[index].id) {
                drafts[index].state = .queued
                try store.saveDraft(drafts[index])
            }
            pending = try store.loadPendingAnswers().filter { $0.serverIdentity == identity }
        } catch { self.error = error.localizedDescription }
    }
    private var cacheURL: URL? { store?.directory.appendingPathComponent("offline-cache.json") }
    private func loadCache() {
        guard let cacheURL, let data = try? Data(contentsOf: cacheURL),
              let cache = try? JSONDecoder().decode(OfflineCache.self, from: data), cache.identity == identity else { return }
        offlineCache = cache; projects = cache.projects; threads = cache.threads; questions = cache.questions; lastSync = cache.updatedAt
    }
    private func saveCache() throws {
        guard let cacheURL, let offlineCache else { return }
        try JSONEncoder().encode(offlineCache).write(to: cacheURL, options: .atomic)
    }
    func cachedMessages(threadID: String) -> [BBMessage] { offlineCache?.messages[threadID] ?? [] }
    func loadMessages(threadID: String) async throws -> [BBMessage] { try await loadState(threadID: threadID).messages }
    func loadState(threadID: String, operation: DiagnosticOperation = DiagnosticOperation(), selection: UUID? = nil) async throws -> BBThreadState {
        let expected = connectionRevision
        let requestClient = client
        await WatchDiagnostics.shared.record(.timelineStarted, operation: operation, selection: selection, foreground: foreground)
        let result: BBThreadState
        do {
            try Task.checkCancellation()
            guard connectionRevision == expected else { throw AppFailure.connectionChanged }
            result = try await requestClient.timeline(threadID: threadID)
        }
        catch { await WatchDiagnostics.shared.record(.timelineFailed, operation: operation, selection: selection, foreground: foreground, error: error); throw error }
        await WatchDiagnostics.shared.record(.timelineReceived, operation: operation, selection: selection, foreground: foreground, count: result.messages.count)
        try Task.checkCancellation()
        guard connectionRevision == expected else { throw AppFailure.connectionChanged }
        if offlineCache == nil { offlineCache = OfflineCache(identity: identity, updatedAt: .distantPast, projects: projects, threads: threads, questions: questions) }
        if offlineCache?.messages[threadID] != result.messages { offlineCache?.messages[threadID] = result.messages; try saveCache() }
        return result
    }
    var currentThread: BBThread? { currentThreadID.flatMap { id in threads.first { $0.id == id } } }
    /// Where the next recording goes: a new thread in the chosen project, else the current thread.
    var recordTarget: RecordingDestination? {
        if let project = newThreadProject { return .project(id: project.id) }
        return currentThreadID.map { .thread(id: $0) }
    }
    /// True while the screen is on and the app is in front; the stage loop sleeps otherwise.
    @Published var foreground = false
    /// Read-only polling has its own view lifetime, independent of sidebar/voice work.
    /// SwiftUI restarts this immediately on selection, send, connection or foreground changes.
    func watchStage() async {
        guard foreground, connected else { return }
        let revision = stageRevision
        while !Task.isCancelled {
            guard stageRevision == revision else { return }
            if let id = currentThreadID {
                if stage == nil { stage = BBThreadState(messages: cachedMessages(threadID: id)) }
                let operation = DiagnosticOperation()
                do {
                    let state = try await loadState(threadID: id, operation: operation, selection: revision)
                    guard !Task.isCancelled, stageRevision == revision else {
                        await WatchDiagnostics.shared.record(.stageDiscarded, operation: operation, selection: revision, foreground: foreground)
                        return
                    }
                    stageSyncFailed = false
                    if state != stage { stage = state }
                    await WatchDiagnostics.shared.record(.stageApplied, operation: operation, selection: revision, foreground: foreground, count: state.messages.count)
                } catch {
                    guard !Task.isCancelled, stageRevision == revision else {
                        await WatchDiagnostics.shared.record(.stageDiscarded, operation: operation, selection: revision, foreground: foreground)
                        return
                    }
                    stageSyncFailed = true
                }
            }
            let busy = stage?.working == true || !sending.isEmpty || currentThread?.status == "active"
            do { try await Task.sleep(for: .seconds(busy ? 3 : 20)) }
            catch { return }
        }
    }
    /// Sidebar failures or slow questions never postpone the current conversation.
    func watchSidebar() async {
        guard foreground, connected else { return }
        resumeQueuedDelivery()
        while !Task.isCancelled {
            // A cancelled prior foreground task may still be unwinding its request.
            // Wait for that owner instead of skipping this wake-up for a whole minute.
            while refreshing {
                do { try await Task.sleep(for: .milliseconds(100)) }
                catch { return }
            }
            guard !Task.isCancelled else { return }
            await refresh()
            guard !Task.isCancelled else { return }
            adoptDefaultThread()
            do { try await Task.sleep(for: .seconds(60)) }
            catch { return }
        }
    }
    /// Keep at most one queue runner. Scene cancellation must not interrupt a mutation
    /// after its acceptance boundary; durable state remains the source of retry decisions.
    private func resumeQueuedDelivery() {
        guard queueTask == nil else { return }
        queueTask = Task {
            await processQueue()
            queueTask = nil
        }
    }
    /// Pick a sensible stage on first run: the most recently active visible chat.
    func adoptDefaultThread() {
        guard currentThreadID == nil || currentThread == nil, let first = chats.max(by: { $0.activityAt < $1.activityAt }) else { return }
        currentThreadID = first.id
    }
    func cancelQueue(_ id: UUID) {
        guard !sending.contains(id), var value = draft(id), value.state == .queued else { return }
        value.state = .draft; value.enqueuedAt = nil; value.error = nil
        do { try save(value) } catch { self.error = error.localizedDescription }
    }
    func draft(_ id: UUID) -> RecordingDraft? { drafts.first { $0.id == id } }
    func save(_ value: RecordingDraft) throws {
        guard let store else { throw CocoaError(.fileWriteUnknown) }
        try store.saveDraft(value)
        if let index = drafts.firstIndex(where: { $0.id == value.id }) { drafts[index] = value }
        else { drafts.append(value) }
    }
    func recover(_ id: UUID) {
        guard !sending.contains(id), activeID != id, var value = draft(id), value.recoveryIssue != nil, let store else { return }
        do {
            guard value.state != .accepted, value.state != .checkingDelivery, !value.chunks.isEmpty else { throw AppFailure.reviewRequired }
            let folder = try store.chunksDirectory(for: id)
            var verified: [AudioChunk] = []
            for chunk in value.chunks.sorted(by: { $0.filename < $1.filename }) {
                guard !chunk.filename.isEmpty, !chunk.filename.contains("/"), chunk.filename != ".", chunk.filename != ".." else { throw AppFailure.audio }
                let file = folder.appendingPathComponent(chunk.filename)
                let properties = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard properties.isRegularFile == true, properties.isSymbolicLink != true else { throw AppFailure.audio }
                let reader = try AVAudioFile(forReading: file)
                guard reader.length > 0, reader.processingFormat.sampleRate > 0,
                      let buffer = AVAudioPCMBuffer(pcmFormat: reader.processingFormat, frameCapacity: 4096) else { throw AppFailure.audio }
                var frames: AVAudioFramePosition = 0
                while reader.framePosition < reader.length {
                    try reader.read(into: buffer)
                    guard buffer.frameLength > 0 else { throw AppFailure.audio }
                    frames += AVAudioFramePosition(buffer.frameLength)
                }
                guard frames == reader.length else { throw AppFailure.audio }
                verified.append(AudioChunk(filename: chunk.filename, duration: Double(frames) / reader.processingFormat.sampleRate))
            }
            value.chunks = verified; value.duration = verified.reduce(0) { $0 + $1.duration }
            if let transcript = value.transcript { value.previousTranscript = transcript }
            value.transcript = nil; value.state = .draft; value.enqueuedAt = nil
            value.error = nil; value.recoveryIssue = nil
            try store.repairDraft(value)
            captureFailures.remove(id)
            reload()
        } catch { self.error = "Recovery stopped because a part is missing, damaged, or has unconfirmed delivery. All originals were kept. \(error.localizedDescription)" }
    }
    func start(destination: RecordingDestination? = nil, existing: UUID? = nil) async {
        guard activeID == nil else { return }
        playback.stop()
        do {
            var value = existing.flatMap(draft) ?? RecordingDraft(destination: destination)
            guard value.state == .draft || value.state == .failed else { return }
            guard !sending.contains(value.id), value.recoveryIssue == nil else { throw AppFailure.reviewRequired }
            value.state = .draft; value.enqueuedAt = nil
            value.serverIdentity = connected ? identity : value.serverIdentity
            try save(value)
            activeID = value.id
            try await resume()
        } catch { activeID = nil; self.error = error.localizedDescription }
    }
    func resume() async throws {
        guard let id = activeID, let value = draft(id), let store else { return }
        guard !sending.contains(id), value.recoveryIssue == nil else { throw AppFailure.reviewRequired }
        capturePersistenceFailed = false
        let directory = try store.chunksDirectory(for: id)
        let captureIdentity = identity
        try await recorder.start(directory: directory, duration: value.duration) { [weak self] chunk in
            Task { @MainActor in self?.merge([chunk], into: id) }
        }
        if activeID != id || identity != captureIdentity {
            merge(recorder.pause(), into: id)
        }
    }
    private func merge(_ chunks: [AudioChunk], into id: UUID) {
        guard var value = draft(id) else { return }
        let additions = chunks.filter { chunk in !value.chunks.contains(where: { $0.filename == chunk.filename }) }
        guard !additions.isEmpty else { return }
        value.chunks.append(contentsOf: additions)
        if let transcript = value.transcript { value.previousTranscript = transcript }
        value.transcript = nil; value.acceptanceReceipt = nil; value.messageId = nil
        value.state = .draft
        value.duration = value.chunks.reduce(0) { $0 + $1.duration }
        do { try save(value) } catch { capturePersistenceFailed = true; self.error = "Could not save recording details. Audio files were kept for recovery." }
    }
    func pause() {
        guard let id = activeID else { return }
        merge(recorder.pause(), into: id)
        if capturePersistenceFailed || recorder.finalizationFailed { captureFailures.insert(id) }
    }
    func finishCapture() { pause() }
    func finish() -> UUID? {
        pause()
        guard !recorder.finalizationFailed, !capturePersistenceFailed else { error = recorder.error ?? error; return nil }
        let id = activeID; activeID = nil; return id
    }
    func pair(code: String) async {
        do {
            pause(); activeID = nil
            let pairing = try await BBClient.redeem(code: code)
            let settings = ConnectionSettings(serverURL: pairing.serverURL, token: pairing.credential, machineID: pairing.machineId)
            try settings.save(); connection = settings; projects = []; threads = []; questions = []; offlineCache = nil; lastSync = nil; reload(); loadCache(); await refresh()
        } catch { self.error = error.localizedDescription }
    }
    func refresh() async {
        guard connected, !refreshing else { return }
        let requestIdentity = identity
        let requestRevision = connectionRevision
        refreshing = true
        defer {
            refreshing = false
            if connectionRevision != requestRevision { Task { await refresh() } }
        }
        let requestClient = client
        let operation = DiagnosticOperation()
        await WatchDiagnostics.shared.record(.refreshStarted, operation: operation, foreground: foreground)
        guard !Task.isCancelled, connectionRevision == requestRevision else { return }
        do {
            // Publish chats before independent projects/questions requests: a failed
            // Needs You refresh must never hide the usable conversation list.
            let loadedThreads = try await requestClient.threads()
            guard !Task.isCancelled, connectionRevision == requestRevision else { return }
            threads = loadedThreads
            syncError = nil
            lastSync = Date()
            offlineCache = OfflineCache(identity: requestIdentity, updatedAt: lastSync!, projects: projects, threads: threads, questions: questions, messages: offlineCache?.messages ?? [:])
            try saveCache()
            // Publish and persist before yielding to diagnostics or another connection.
            await WatchDiagnostics.shared.record(.threadsApplied, operation: operation, foreground: foreground, count: loadedThreads.count)
            guard !Task.isCancelled, connectionRevision == requestRevision else { return }
            do {
                let loadedProjects = try await requestClient.projects()
                guard !Task.isCancelled, connectionRevision == requestRevision else { return }
                projects = loadedProjects
                offlineCache?.projects = projects
                try saveCache()
            } catch {
                guard !Task.isCancelled, connectionRevision == requestRevision else { return }
                syncError = error.localizedDescription
                await WatchDiagnostics.shared.record(.projectsFailed, operation: operation, foreground: foreground, error: error)
            }
            guard !Task.isCancelled, connectionRevision == requestRevision else { return }
            do {
                let candidates = loadedThreads.filter { $0.hasPendingInteraction != false }
                let loadedQuestions = try await requestClient.questions(threads: candidates)
                guard !Task.isCancelled, connectionRevision == requestRevision else { return }
                questions = loadedQuestions
                questionsError = nil
                offlineCache?.questions = questions
                try saveCache()
            } catch {
                guard !Task.isCancelled, connectionRevision == requestRevision else { return }
                // Keep cached questions and mark them stale, never imply resolved.
                questionsError = error.localizedDescription
                await WatchDiagnostics.shared.record(.questionsFailed, operation: operation, foreground: foreground, error: error)
            }
            await WatchDiagnostics.shared.record(.refreshFinished, operation: operation, foreground: foreground)
            guard !Task.isCancelled, connectionRevision == requestRevision else { return }
            resumeQueuedDelivery()
        } catch {
            await WatchDiagnostics.shared.record(.refreshFailed, operation: operation, foreground: foreground, error: error)
            guard !Task.isCancelled, connectionRevision == requestRevision else { return }
            syncError = error.localizedDescription
        }
    }

    func deliver(_ id: UUID, destination: RecordingDestination? = nil) async {
        guard connected else { error = ConnectionError.notConnected.localizedDescription; return }
        if activeID == id { pause() }
        guard !captureFailures.contains(id) else { error = "Could not safely finish recording. The original was kept for recovery."; return }
        guard !sending.contains(id), var value = draft(id), value.state != .accepted, value.state != .checkingDelivery else { return }
        guard value.recoveryIssue == nil else { error = AppFailure.reviewRequired.localizedDescription; return }
        guard !value.chunks.isEmpty || value.transcript?.isEmpty == false else { error = "An empty recording can't be sent."; return }
        guard value.serverIdentity == nil || value.serverIdentity == identity else { error = "This recording belongs to a different BB connection."; return }
        if let destination { value.destination = destination }
        guard let destination = value.destination else { return }
        // Queue order is the Send order, independent of when the recordings were created.
        value.serverIdentity = identity
        if value.enqueuedAt == nil { value.enqueuedAt = Date() }
        do { value.state = .queued; try save(value) } catch { self.error = error.localizedDescription; return }
        guard !drafts.contains(where: { $0.id != id && ($0.enqueuedAt ?? .distantFuture) < value.enqueuedAt! && $0.destination == destination && [.queued, .transcribing, .checkingDelivery, .failed].contains($0.state) }) else {
            error = "Finish the earlier send to this thread first."; return
        }
        let requestIdentity = identity
        let requestClient = client
        sending.insert(id); defer { sending.remove(id) }
        let operation = DiagnosticOperation()
        await WatchDiagnostics.shared.record(.deliveryStarted, operation: operation, foreground: foreground, count: value.chunks.count)
        do {
            value.serverIdentity = requestIdentity; value.state = .queued; value.error = nil; try save(value)
            if value.transcript?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                value.state = .transcribing; try save(value)
                value.transcript = try await transcribe(value, using: requestClient, identity: requestIdentity, operation: operation)
                guard identity == requestIdentity else { throw AppFailure.connectionChanged }
                try save(value)
            }
            guard let text = value.transcript, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AppFailure.noSpeech
            }
            guard identity == requestIdentity else { throw AppFailure.connectionChanged }
            // Persist uncertainty BEFORE the irreversible request. Never retry an unknown acceptance.
            value.state = .checkingDelivery; try save(value)
            await WatchDiagnostics.shared.record(.sendStarted, operation: operation, foreground: foreground)
            switch destination {
            case .thread(let threadID):
                let receipt = try await requestClient.send(text: text, threadID: threadID)
                value.acceptanceReceipt = String(data: try JSONEncoder().encode(receipt), encoding: .utf8)
            case .project(let projectID):
                let thread = try await requestClient.createThread(projectID: projectID, text: text)
                value.destination = .thread(id: thread.id)
                if identity == requestIdentity { currentThreadID = thread.id; newThreadProject = nil }
                value.acceptanceReceipt = "Created thread with initial prompt: \(thread.id)"
            }
            await WatchDiagnostics.shared.record(.sendAccepted, operation: operation, foreground: foreground)
            value.state = .accepted
            if identity == requestIdentity { try save(value); await refresh() }
            else { try store?.saveDraft(value) }
        } catch {
            await WatchDiagnostics.shared.record(.deliveryFailed, operation: operation, foreground: foreground, error: error)
            // Preserve checkingDelivery for ALL outcomes after the request boundary until reconciled.
            if value.state != .checkingDelivery && value.state != .accepted {
                let offline = (error as? URLError).map { [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost, .cannotFindHost].contains($0.code) } ?? false
                value.state = offline ? .queued : .failed
            }
            value.error = error.localizedDescription
            do { if identity == requestIdentity { try save(value) } else { try store?.saveDraft(value) } } catch { self.error = error.localizedDescription }
        }
    }
    private func processQueue() async {
        guard connected, !processingQueue else { return }
        processingQueue = true; defer { processingQueue = false }
        let queueIdentity = identity
        let candidates = drafts.filter { $0.state == .queued && $0.serverIdentity == queueIdentity && $0.recoveryIssue == nil }.sorted { ($0.enqueuedAt ?? .distantPast) < ($1.enqueuedAt ?? .distantPast) }
        for value in candidates {
            guard identity == queueIdentity else { return }
            guard !sending.contains(value.id), let destination = value.destination else { continue }
            let blocked = drafts.contains { other in
                other.id != value.id && other.destination == destination && (other.enqueuedAt ?? .distantFuture) < (value.enqueuedAt ?? .distantPast) && [.queued, .transcribing, .failed, .checkingDelivery].contains(other.state)
            }
            if !blocked { await deliver(value.id) }
        }
    }
    private func transcribe(_ draft: RecordingDraft, using requestClient: BBClient, identity requestIdentity: String, operation: DiagnosticOperation) async throws -> String {
        guard let store else { throw CocoaError(.fileReadUnknown) }
        let folder = try store.chunksDirectory(for: draft.id)
        var results: [String] = []
        // Group continuous checkpoints into ~30s transport files. Persist each result for retry.
        var group: [AudioChunk] = []; var duration: TimeInterval = 0
        for (index, chunk) in draft.chunks.enumerated() {
            group.append(chunk); duration += chunk.duration
            if duration >= 30 || index == draft.chunks.count - 1 {
                // Include BOTH ends and count: extending a previous short group invalidates its cache.
                let cache = folder.deletingLastPathComponent().appendingPathComponent("transcript-\(group.first!.filename)-\(group.last!.filename)-\(group.count).json")
                if FileManager.default.fileExists(atPath: cache.path) {
                    results.append(try JSONDecoder().decode(String.self, from: Data(contentsOf: cache)))
                    await WatchDiagnostics.shared.record(.transcriptionCached, operation: operation, foreground: foreground, group: results.count - 1)
                } else {
                    let upload = folder.deletingLastPathComponent().appendingPathComponent("upload.wav")
                    let chunks = group
                    await WatchDiagnostics.shared.record(.assemblyStarted, operation: operation, foreground: foreground, group: results.count, count: chunks.count)
                    try await Task.detached(priority: .utility) {
                        try Self.assemble(chunks, folder: folder, output: upload)
                    }.value
                    await WatchDiagnostics.shared.record(.assemblyFinished, operation: operation, foreground: foreground, group: results.count)
                    guard identity == requestIdentity else { throw AppFailure.connectionChanged }
                    let bytes = (try? upload.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
                    let audioMilliseconds = duration.isFinite && duration >= 0 && duration < Double(Int.max) / 1000 ? Int(duration * 1000) : nil
                    await WatchDiagnostics.shared.record(.transcriptionStarted, operation: operation, foreground: foreground, group: results.count, bytes: bytes, audioMilliseconds: audioMilliseconds)
                    let text = try await requestClient.transcribe(file: upload)
                    await WatchDiagnostics.shared.record(.transcriptionFinished, operation: operation, foreground: foreground, group: results.count)
                    guard identity == requestIdentity else { throw AppFailure.connectionChanged }
                    try JSONEncoder().encode(text).write(to: cache, options: .atomic)
                    try? FileManager.default.removeItem(at: upload)
                    results.append(text)
                }
                group = []; duration = 0
            }
        }
        return results.joined(separator: "\n")
    }
    private nonisolated static func assemble(_ chunks: [AudioChunk], folder: URL, output: URL) throws {
        var writer: AVAudioFile?
        for chunk in chunks {
            let reader = try AVAudioFile(forReading: folder.appendingPathComponent(chunk.filename))
            if writer == nil { writer = try AVAudioFile(forWriting: output, settings: reader.processingFormat.settings) }
            guard let buffer = AVAudioPCMBuffer(pcmFormat: reader.processingFormat, frameCapacity: 4096) else { throw AppFailure.audio }
            while reader.framePosition < reader.length {
                try reader.read(into: buffer)
                guard buffer.frameLength > 0 else { throw AppFailure.audio }
                try writer?.write(from: buffer)
            }
        }
        writer = nil
    }
    func choose(_ question: BBQuestion, option: BBOption) -> UUID? {
        do {
            guard let store else { return nil }
            guard connected, question.supported, question.options.contains(where: { $0.id == option.id }) else { return nil }
            if let existing = pending.first(where: { $0.threadID == question.threadID && $0.interactionID == question.id }) { return existing.id }
            let answer = PendingAnswer(threadID: question.threadID, interactionID: question.id, choice: option.id, deadline: Date().addingTimeInterval(10), choiceLabel: option.label, serverIdentity: identity, questionFingerprint: fingerprint(question))
            try store.savePendingAnswer(answer); nextAnswerAttempt = .distantPast; reload(); return answer.id
        } catch { self.error = error.localizedDescription; return nil }
    }
    func cancel(_ id: UUID) {
        guard pending.contains(where: { $0.id == id && $0.serverIdentity == identity }) else { return }
        do { _ = try store?.cancelPendingAnswer(id: id); reload() }
        catch { self.error = error.localizedDescription }
    }
    private func fingerprint(_ question: BBQuestion) -> String {
        let fields = [question.id, question.questionID ?? "", question.prompt] + question.options.flatMap { [$0.id, $0.label] }
        return (try? JSONEncoder().encode(fields).base64EncodedString()) ?? ""
    }
    private func commitAnswers() async {
        guard connected, !answering, Date() >= nextAnswerAttempt, let store else { return }
        answering = true; defer { answering = false }
        let requestIdentity = identity
        let requestClient = client
        for value in pending where value.status == .waiting && value.deadline <= Date() && value.serverIdentity == requestIdentity {
            guard identity == requestIdentity else { return }
            do {
                // Fetch the target even if the thread list has not refreshed since restart.
                let target = BBThread(id: value.threadID, title: nil, projectId: nil)
                let current = try await requestClient.questions(threads: [target])
                guard identity == requestIdentity else { return }
                // Cancellation during the await must win before any commit boundary.
                guard try store.loadPendingAnswers().contains(where: { $0.id == value.id && $0.status == .waiting && $0.serverIdentity == requestIdentity }) else { continue }
                guard let question = current.first(where: { $0.id == value.interactionID && $0.threadID == value.threadID }), question.supported else {
                    _ = try store.cancelPendingAnswer(id: value.id); reload(); continue
                }
                guard value.questionFingerprint == fingerprint(question), question.options.contains(where: { $0.id == value.choice }) else {
                    _ = try store.cancelPendingAnswer(id: value.id); reload()
                    error = "This question changed. Choose an answer again."; continue
                }
                var committing = try store.beginCommit(id: value.id)
                reload()
                do {
                    committing.messageId = try await requestClient.resolve(question: question, optionID: value.choice)
                    committing.status = .accepted
                    try store.savePendingAnswer(committing)
                    if identity == requestIdentity { questions.removeAll { $0.id == question.id } }
                } catch {
                    committing.error = error.localizedDescription
                    try store.savePendingAnswer(committing)
                }
                reload()
            } catch {
                // Avoid waking the radio once per second while the host is unavailable.
                nextAnswerAttempt = Date().addingTimeInterval(30)
            }
        }
    }
}
enum AppFailure: LocalizedError {
    case noSpeech, audio, reviewRequired, connectionChanged
    var errorDescription: String? {
        switch self {
        case .noSpeech: "No speech detected. The recording is saved; play it back or edit the transcript."
        case .audio: "Could not prepare the audio. The original is saved."
        case .reviewRequired: "This recovered recording needs review. The original is saved and sending is disabled."
        case .connectionChanged: "The BB connection changed. This recording remains saved for the previous connection."
        }
    }
}
