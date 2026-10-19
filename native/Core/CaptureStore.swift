import Foundation
import CryptoKit

public struct Recipient: Codable, Equatable, Sendable {
    public var connection: String? // nil is staged locally, never uploadable.
    public var exactThread: String? // nil means BB; watch collects no recent/notification context.
    public init(connection: String? = nil, exactThread: String? = nil) {
        self.connection = connection; self.exactThread = exactThread
    }
}
public struct PCMPart: Codable, Equatable, Sendable {
    public let id: UUID
    public let sampleRate: Double
    public let channels: Int
    public var frames: Int
    public var incomplete: [String]
    public var sha256: String? = nil
    public var filename: String { id.uuidString + ".f32le" }
}
public struct Draft: Codable, Equatable, Sendable {
    public let id: UUID
    public let recipient: Recipient
    public var parts: [PCMPart]
    public var preview: [Float]? = nil
    public var frames: Int { parts.reduce(0) { $0 + $1.frames } }
}
public struct LocalOperation: Codable, Equatable, Sendable {
    public let id: UUID
    public let sequence: Int
    public let predecessors: [UUID]
    public let draft: Draft
    public let enqueuedAt: Date
}
public struct CaptureAttempt: Codable, Equatable, Sendable {
    public let id: UUID
    public let recipient: Recipient
    public let partID: UUID
}
public struct CaptureLedger: Codable, Sendable {
    public var version = 1
    public var current = Recipient()
    public var drafts: [Draft] = []
    public var outbox: [LocalOperation] = []
    public var attempt: CaptureAttempt?
    public var nextSequence = 1
    public var damaged: [UUID] = []
    public var currentDraft: Draft? { drafts.first { $0.recipient == current } }
}

/// Confined to the capture worker queue. Any uncertain filesystem result blocks mutations
/// until that writer drains and recover() reads the authoritative ledger.
public final class CaptureStore {
    public let root: URL
    private let lock: StoreLock
    public private(set) var ledger: CaptureLedger
    public private(set) var blocked = false
    private var ledgerURL: URL { root.appendingPathComponent("capture.json") }
    public init(root: URL) throws {
        self.root = root
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        lock = try StoreLock(root: root)
        let url = root.appendingPathComponent("capture.json")
        if FileManager.default.fileExists(atPath: url.path) {
            ledger = try JSONDecoder().decode(CaptureLedger.self, from: Data(contentsOf: url))
        } else {
            // Never create an empty ledger over pre-existing source/temporary commit evidence.
            let names = try FileManager.default.contentsOfDirectory(atPath: root.path)
            guard names.allSatisfy({ $0 == "writer.lock" }) else { throw ProbeError.blocked }
            ledger = CaptureLedger()
            try DurableFile.save(ledger, to: url)
        }
        try recover()
    }
    private func commit(_ next: CaptureLedger) throws {
        guard !blocked else { throw ProbeError.blocked }
        do { try DurableFile.save(next, to: ledgerURL); ledger = next }
        catch { blocked = true; throw error }
    }
    public func recover(interruptionReason: String = "process-ended-during-capture") throws {
        blocked = true
        var disk = try JSONDecoder().decode(CaptureLedger.self, from: Data(contentsOf: ledgerURL))
        guard disk.version == 1, disk.nextSequence > 0,
              Set(disk.drafts.map(\.id)).count == disk.drafts.count,
              Set(disk.outbox.map(\.id)).count == disk.outbox.count,
              Set(disk.drafts.map(\.id)).isDisjoint(with: disk.outbox.map { $0.draft.id })
        else { throw ProbeError.invalid }
        for draft in disk.drafts + disk.outbox.map(\.draft) {
            for part in draft.parts {
                let attrs = try? FileManager.default.attributesOfItem(atPath: root.appendingPathComponent(part.filename).path)
                let bytes = (attrs?[.size] as? NSNumber)?.intValue ?? -1
                let valid = part.frames > 0 && part.channels > 0 && part.channels <= 8 && part.frames <= Int.max / (part.channels * 4) && part.sampleRate.isFinite && part.sampleRate > 0
                let contentOK = valid && bytes >= part.frames * part.channels * 4
                let hashOK = contentOK && (part.sha256 == nil || (try? Self.hash(part, root: root)) == part.sha256)
                if !contentOK || !hashOK {
                    if !disk.damaged.contains(draft.id) { disk.damaged.append(draft.id) }
                }
            }
        }
        if let attempt = disk.attempt,
           let d = disk.drafts.firstIndex(where: { $0.recipient == attempt.recipient }),
           let p = disk.drafts[d].parts.firstIndex(where: { $0.id == attempt.partID }) {
            disk.drafts[d].parts[p].incomplete.append(interruptionReason)
            if !disk.damaged.contains(disk.drafts[d].id) { disk.drafts[d].parts[p].sha256 = try Self.hash(disk.drafts[d].parts[p], root: root) }
        }
        disk.attempt = nil
        // Extra file bytes remain preserved but are never invented as committed speech.
        try DurableFile.save(disk, to: ledgerURL)
        ledger = disk; blocked = false
    }
    private static func hash(_ part: PCMPart, root: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: root.appendingPathComponent(part.filename))
        defer { try? handle.close() }
        var remaining = part.frames * part.channels * 4, hash = SHA256()
        while remaining > 0 {
            let data = try handle.read(upToCount: min(remaining, 65536)) ?? Data()
            guard !data.isEmpty else { throw ProbeError.invalid }
            hash.update(data: data); remaining -= data.count
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    public func begin() throws -> CaptureAttempt {
        guard !blocked else { throw ProbeError.blocked }
        guard ledger.attempt == nil else { throw ProbeError.busy }
        guard !ledger.damaged.contains(where: { $0 == ledger.currentDraft?.id }) else { throw ProbeError.invalid }
        let attempt = CaptureAttempt(id: UUID(), recipient: ledger.current, partID: UUID())
        var next = ledger; next.attempt = attempt; try commit(next)
        return attempt
    }
    /// Empty input cannot create a draft. Format is original float PCM, no resampling.
    @discardableResult public func append(_ bytes: Data, frames: Int, sampleRate: Double, channels: Int, attempt: UUID) throws -> Bool {
        guard !blocked else { throw ProbeError.blocked }
        guard let owner = ledger.attempt, owner.id == attempt else { return false }
        guard frames > 0, channels > 0, channels <= 8, sampleRate.isFinite, sampleRate > 0,
              frames <= 65536, bytes.count == frames * channels * 4 else { throw ProbeError.invalid }
        var next = ledger
        if !next.drafts.contains(where: { $0.recipient == owner.recipient }) {
            next.drafts.append(Draft(id: UUID(), recipient: owner.recipient, parts: []))
        }
        let d = next.drafts.firstIndex { $0.recipient == owner.recipient }!
        let first = !next.drafts[d].parts.contains { $0.id == owner.partID }
        if first {
            next.drafts[d].parts.append(PCMPart(id: owner.partID, sampleRate: sampleRate, channels: channels, frames: 0, incomplete: []))
        }
        let p = next.drafts[d].parts.count - 1
        let part = next.drafts[d].parts[p]
        guard part.sampleRate == sampleRate, part.channels == channels, part.frames <= Int.max / (channels * 4) - frames else { throw ProbeError.invalid }
        let file = root.appendingPathComponent(part.filename)
        do {
            if first { try DurableFile.write(Data(), to: file) }
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            try handle.seek(toOffset: UInt64(part.frames * channels * 4))
            try handle.write(contentsOf: bytes); try handle.synchronize()
            next.drafts[d].parts[p].frames += frames
            let peak = bytes.withUnsafeBytes { raw in raw.bindMemory(to: Float.self).reduce(Float(0)) { max($0, $1.isFinite ? abs($1) : 0) } }
            next.drafts[d].preview = Array(((next.drafts[d].preview ?? []) + [peak]).suffix(32))
            try commit(next)
        } catch { blocked = true; throw error }
        return first
    }
    public func stop(attempt: UUID, reason: String? = nil) throws {
        guard let owner = ledger.attempt, owner.id == attempt else { return }
        var next = ledger
        if let reason, let d = next.drafts.firstIndex(where: { $0.recipient == owner.recipient }),
           let p = next.drafts[d].parts.firstIndex(where: { $0.id == owner.partID }) {
            next.drafts[d].parts[p].incomplete.append(reason)
        }
        if let d = next.drafts.firstIndex(where: { $0.recipient == owner.recipient }),
           let p = next.drafts[d].parts.firstIndex(where: { $0.id == owner.partID }) {
            next.drafts[d].parts[p].sha256 = try Self.hash(next.drafts[d].parts[p], root: root)
        }
        next.attempt = nil; try commit(next)
    }
    public func select(_ recipient: Recipient) throws {
        guard ledger.attempt == nil else { throw ProbeError.busy }
        var next = ledger; next.current = recipient; try commit(next)
    }
    @discardableResult public func enqueue() throws -> LocalOperation {
        guard !blocked else { throw ProbeError.blocked }
        guard ledger.attempt == nil else { throw ProbeError.busy }
        guard let draft = ledger.currentDraft, draft.frames > 0 else { throw ProbeError.noAudio }
        guard !ledger.damaged.contains(draft.id) else { throw ProbeError.invalid }
        let prior = ledger.outbox.filter { $0.draft.recipient.connection == draft.recipient.connection }.map(\.id)
        let item = LocalOperation(id: draft.id, sequence: ledger.nextSequence, predecessors: prior, draft: draft, enqueuedAt: Date())
        var next = ledger
        next.drafts.removeAll { $0.id == draft.id }; next.outbox.append(item); next.nextSequence += 1
        try commit(next) // One rename: never a draft and an editable copy of an item.
        return item
    }
}
