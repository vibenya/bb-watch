import Foundation

public enum RecordingState: String, Codable, Sendable { case draft, queued, transcribing, checkingDelivery, accepted, failed }
public enum RecordingDestination: Codable, Equatable, Sendable { case thread(id: String), project(id: String) }
public struct AudioChunk: Codable, Equatable, Sendable {
    public var filename: String
    public var duration: TimeInterval
    public init(filename: String, duration: TimeInterval) { self.filename = filename; self.duration = duration }
}
public struct RecordingDraft: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var duration: TimeInterval
    public var enqueuedAt: Date?
    public var state: RecordingState
    public var destination: RecordingDestination?
    public var chunks: [AudioChunk]
    public var serverIdentity: String?
    public var recoveryIssue: String?
    public var previousTranscript: String?
    public var transcript: String?
    public var error: String?
    public var messageId: String?
    public var acceptanceReceipt: String?
    public var creatingRequestID: UUID?
    public var providerID: String?
    public var modelID: String?
    public var modelName: String?
    public init(id: UUID = UUID(), createdAt: Date = Date(), duration: TimeInterval = 0, enqueuedAt: Date? = nil, state: RecordingState = .draft, destination: RecordingDestination? = nil, chunks: [AudioChunk] = [], serverIdentity: String? = nil, recoveryIssue: String? = nil, previousTranscript: String? = nil, transcript: String? = nil, error: String? = nil, messageId: String? = nil, acceptanceReceipt: String? = nil, creatingRequestID: UUID? = nil, providerID: String? = nil, modelID: String? = nil, modelName: String? = nil) {
        self.id = id; self.createdAt = createdAt; self.duration = duration; self.enqueuedAt = enqueuedAt; self.state = state; self.destination = destination; self.chunks = chunks; self.serverIdentity = serverIdentity; self.recoveryIssue = recoveryIssue; self.previousTranscript = previousTranscript; self.transcript = transcript; self.error = error; self.messageId = messageId; self.acceptanceReceipt = acceptanceReceipt
        self.creatingRequestID = creatingRequestID
        self.providerID = providerID; self.modelID = modelID; self.modelName = modelName
    }
}
/// Re-evaluated after every await: a create receipt can unblock follow-ups, while
/// attempted IDs prevent a transient offline queue from spinning in one pass.
enum RecordingQueue {
    static func next(in drafts: [RecordingDraft], identity: String, excluding: Set<UUID>) -> RecordingDraft? {
        drafts.filter {
            $0.state == .queued && $0.serverIdentity == identity && $0.recoveryIssue == nil &&
            $0.creatingRequestID == nil && $0.destination != nil && !excluding.contains($0.id)
        }.sorted { ($0.enqueuedAt ?? .distantPast) < ($1.enqueuedAt ?? .distantPast) }.first { !isBlocked($0, by: drafts) }
    }
    static func isBlocked(_ candidate: RecordingDraft, by drafts: [RecordingDraft]) -> Bool {
        if candidate.creatingRequestID != nil { return true }
        // Two explicit New intents in one project are different recipients.
        guard case .thread = candidate.destination else { return false }
        return drafts.contains { other in
            other.id != candidate.id && other.serverIdentity == candidate.serverIdentity &&
            other.destination == candidate.destination &&
            (other.enqueuedAt ?? .distantFuture) < (candidate.enqueuedAt ?? .distantPast) &&
            [.queued, .transcribing, .checkingDelivery, .failed].contains(other.state)
        }
    }
}
public enum PendingAnswerStatus: String, Codable, Sendable { case waiting, committing, accepted, failed }
public struct PendingAnswer: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var serverIdentity: String?
    public var questionFingerprint: String?
    public var threadID: String
    public var interactionID: String
    public var choice: String
    public var choiceLabel: String?
    public var deadline: Date
    public var status: PendingAnswerStatus
    public var messageId: String?
    public var error: String?
    public init(id: UUID = UUID(), threadID: String, interactionID: String, choice: String, deadline: Date, choiceLabel: String? = nil, status: PendingAnswerStatus = .waiting, serverIdentity: String? = nil, questionFingerprint: String? = nil, messageId: String? = nil, error: String? = nil) {
        self.id = id; self.serverIdentity = serverIdentity; self.questionFingerprint = questionFingerprint; self.threadID = threadID; self.interactionID = interactionID; self.choice = choice; self.choiceLabel = choiceLabel; self.deadline = deadline; self.status = status; self.messageId = messageId; self.error = error
    }
}
public enum DurableStoreError: Error { case invalidTransition, deadlineNotReached, missingAnswer, invalidReceipt, invalidChunkPath }

/// A single-owner filesystem store. Original audio is removed only by explicit deletion.
public final class DurableStore {
    public let directory: URL
    public private(set) var recoveryWarnings: [String] = []
    private let fm = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    public init(directory: URL) throws {
        self.directory = directory
        try fm.createDirectory(at: directory.appendingPathComponent("drafts"), withIntermediateDirectories: true)
        try fm.createDirectory(at: directory.appendingPathComponent("answers"), withIntermediateDirectories: true)
    }
    private func draftDirectory(_ id: UUID) -> URL { directory.appendingPathComponent("drafts").appendingPathComponent(id.uuidString) }
    private func answerURL(_ id: UUID) -> URL { directory.appendingPathComponent("answers").appendingPathComponent(id.uuidString + ".json") }
    public func chunksDirectory(for id: UUID) throws -> URL {
        let url = draftDirectory(id).appendingPathComponent("chunks")
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    public func saveDraft(_ draft: RecordingDraft) throws {
        guard draft.state != .accepted || draft.messageId?.isEmpty == false || draft.acceptanceReceipt?.isEmpty == false else { throw DurableStoreError.invalidReceipt }
        guard draft.chunks.allSatisfy({ !$0.filename.isEmpty && $0.filename == URL(fileURLWithPath: $0.filename).lastPathComponent && !$0.filename.contains("/") && $0.filename != "." && $0.filename != ".." }) else { throw DurableStoreError.invalidChunkPath }
        let url = draftDirectory(draft.id).appendingPathComponent("metadata.json")
        // A corrupt record must remain available for recovery, never silently replaced.
        if fm.fileExists(atPath: url.path) {
            let previous = try decoder.decode(RecordingDraft.self, from: Data(contentsOf: url))
            guard previous.id == draft.id, previous.state != .accepted || draft.state == .accepted else { throw DurableStoreError.invalidTransition }
        }
        _ = try chunksDirectory(for: draft.id)
        try encoder.encode(draft).write(to: url, options: .atomic)
    }
    /// Explicit repair only after the caller has decoded every original audio part.
    /// Metadata bytes are backed up before replacement; no audio is removed.
    public func repairDraft(_ validated: RecordingDraft) throws {
        guard validated.state == .draft, validated.enqueuedAt == nil,
              validated.messageId == nil, validated.acceptanceReceipt == nil,
              !validated.chunks.isEmpty, validated.duration.isFinite, validated.duration > 0,
              abs(validated.duration - validated.chunks.reduce(0) { $0 + $1.duration }) < 0.001 else { throw DurableStoreError.invalidTransition }
        guard validated.chunks.allSatisfy({ !$0.filename.isEmpty && !$0.filename.contains("/") && $0.filename != "." && $0.filename != ".." && $0.duration.isFinite && $0.duration > 0 }) else { throw DurableStoreError.invalidChunkPath }
        guard let original = try loadDrafts().first(where: { $0.id == validated.id }), original.recoveryIssue != nil,
              original.state != .accepted, original.state != .checkingDelivery,
              original.messageId == nil, original.acceptanceReceipt == nil,
              original.serverIdentity == validated.serverIdentity else { throw DurableStoreError.invalidTransition }
        let originalNames = original.chunks.map(\.filename)
        let repairedNames = validated.chunks.map(\.filename)
        guard Set(repairedNames).count == repairedNames.count,
              Set(originalNames) == Set(repairedNames), originalNames.count == repairedNames.count else { throw DurableStoreError.invalidTransition }
        let folder = draftDirectory(validated.id)
        for chunk in validated.chunks {
            let url = folder.appendingPathComponent("chunks").appendingPathComponent(chunk.filename)
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else { throw DurableStoreError.invalidChunkPath }
        }
        let metadata = folder.appendingPathComponent("metadata.json")
        if fm.fileExists(atPath: metadata.path) {
            let bytes = try Data(contentsOf: metadata)
            if let prior = try? decoder.decode(RecordingDraft.self, from: bytes) {
                guard prior.state != .accepted, prior.state != .checkingDelivery,
                      prior.messageId == nil, prior.acceptanceReceipt == nil else { throw DurableStoreError.invalidTransition }
            }
            let backup = folder.appendingPathComponent("metadata.original-\(UUID().uuidString).json")
            try bytes.write(to: backup, options: .atomic)
        }
        var repaired = validated
        repaired.error = nil; repaired.recoveryIssue = nil
        try encoder.encode(repaired).write(to: metadata, options: .atomic)
    }
    public func loadDrafts() throws -> [RecordingDraft] {
        recoveryWarnings = []
        var drafts: [RecordingDraft] = []
        for folder in try fm.contentsOfDirectory(at: directory.appendingPathComponent("drafts"), includingPropertiesForKeys: nil) {
            guard let id = UUID(uuidString: folder.lastPathComponent) else { continue }
            let metadata = folder.appendingPathComponent("metadata.json")
            var draft: RecordingDraft
            if fm.fileExists(atPath: metadata.path) {
                do {
                    draft = try decoder.decode(RecordingDraft.self, from: Data(contentsOf: metadata))
                    guard draft.id == id else { throw DurableStoreError.invalidTransition }
                }
                catch {
                    recoveryWarnings.append("Corrupt metadata preserved for recording \(id.uuidString).")
                    draft = RecordingDraft(id: id, recoveryIssue: "Metadata damaged; recovered audio requires review.", error: "Metadata damaged; recovered audio requires review.")
                }
            }
            else { draft = RecordingDraft(id: id, recoveryIssue: "Recovered audio; duration and ordering require review.", error: "Recovered audio; duration and ordering require review.") }
            let chunks = folder.appendingPathComponent("chunks")
            if fm.fileExists(atPath: chunks.path) {
                let files = try fm.contentsOfDirectory(at: chunks, includingPropertiesForKeys: [.isRegularFileKey]).filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }.sorted { $0.lastPathComponent < $1.lastPathComponent }
                let known = Set(draft.chunks.map(\.filename))
                let orphaned = files.filter { !known.contains($0.lastPathComponent) }
                if !orphaned.isEmpty {
                    draft.chunks += orphaned.map { AudioChunk(filename: $0.lastPathComponent, duration: 0) }
                    if draft.state != .accepted && draft.state != .checkingDelivery { draft.state = .draft }
                    draft.error = "Recovered audio; duration and ordering require review."
                    draft.recoveryIssue = draft.error
                }
            }
            if draft.state != .accepted && draft.chunks.contains(where: { !fm.fileExists(atPath: chunks.appendingPathComponent($0.filename).path) }) {
                draft.recoveryIssue = "Missing audio chunk; review required."
                draft.error = draft.recoveryIssue
                if draft.state != .checkingDelivery { draft.state = .draft }
            }
            drafts.append(draft)
        }
        return drafts.sorted { $0.createdAt < $1.createdAt }
    }
    /// Resolve a local New conversation only from its confirmed create receipt.
    /// An unknown/failed create, or another account's receipt, never unlocks a send.
    public func resolveCreationDependencies() throws -> [RecordingDraft] {
        var drafts = try loadDrafts()
        let byID = Dictionary(uniqueKeysWithValues: drafts.map { ($0.id, $0) })
        for index in drafts.indices {
            guard let parentID = drafts[index].creatingRequestID,
                  let parent = byID[parentID], parent.state == .accepted,
                  parent.serverIdentity != nil, parent.serverIdentity == drafts[index].serverIdentity,
                  case .thread = parent.destination,
                  [.draft, .queued, .failed].contains(drafts[index].state) else { continue }
            drafts[index].destination = parent.destination
            drafts[index].creatingRequestID = nil
            try saveDraft(drafts[index])
        }
        return drafts
    }
    public func deleteDraft(id: UUID) throws {
        let url = draftDirectory(id)
        if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
    }
    public func loadPendingAnswers() throws -> [PendingAnswer] {
        try fm.contentsOfDirectory(at: directory.appendingPathComponent("answers"), includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }.map { try decoder.decode(PendingAnswer.self, from: Data(contentsOf: $0)) }.sorted { $0.deadline < $1.deadline }
    }
    public func savePendingAnswer(_ answer: PendingAnswer) throws {
        guard answer.status != .accepted || answer.messageId?.isEmpty == false else { throw DurableStoreError.invalidReceipt }
        let existing = try loadPendingAnswers()
        if let previous = existing.first(where: { $0.id == answer.id }) {
            guard previous.serverIdentity == answer.serverIdentity, previous.questionFingerprint == answer.questionFingerprint, previous.threadID == answer.threadID, previous.interactionID == answer.interactionID, previous.choice == answer.choice, previous.choiceLabel == answer.choiceLabel, previous.deadline == answer.deadline else { throw DurableStoreError.invalidTransition }
            if previous.status != .waiting && answer.status == .waiting { throw DurableStoreError.invalidTransition }
            if previous.status == .accepted && answer != previous { throw DurableStoreError.invalidTransition }
        } else if existing.contains(where: { $0.serverIdentity == answer.serverIdentity && $0.threadID == answer.threadID && $0.interactionID == answer.interactionID }) { throw DurableStoreError.invalidTransition }
        try encoder.encode(answer).write(to: answerURL(answer.id), options: .atomic)
    }
    @discardableResult public func cancelPendingAnswer(id: UUID) throws -> Bool {
        guard let answer = try loadPendingAnswers().first(where: { $0.id == id }), answer.status == .waiting else { return false }
        try fm.removeItem(at: answerURL(id)); return true
    }
    /// Call before network commit. A recovered committing record requires server reconciliation.
    public func beginCommit(id: UUID, now: Date = Date()) throws -> PendingAnswer {
        guard var answer = try loadPendingAnswers().first(where: { $0.id == id }) else { throw DurableStoreError.missingAnswer }
        guard answer.status == .waiting else { throw DurableStoreError.invalidTransition }
        guard now >= answer.deadline else { throw DurableStoreError.deadlineNotReached }
        answer.status = .committing
        try savePendingAnswer(answer)
        return answer
    }
}
