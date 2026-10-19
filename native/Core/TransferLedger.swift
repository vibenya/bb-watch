import Foundation
import CryptoKit

public struct TransferRecord: Codable, Sendable {
    public let id: UUID
    public let endpoint: URL
    public let method: String
    public let filename: String
    public let sha256: String
    public var taskID: Int?
    public var phase: String
    public var httpStatus: Int?
    public var errorCode: Int?
}
public struct TaskSnapshot: Sendable {
    public let taskID: Int
    public let description: String?
    public let endpoint: URL?
    public let method: String?
    public init(taskID: Int, description: String?, endpoint: URL?, method: String?) {
        self.taskID = taskID; self.description = description; self.endpoint = endpoint; self.method = method
    }
}
/// A fixture task ledger, deliberately separate from the audio outbox and receipt ownership.
public final class TransferLedger {
    public let root: URL
    private let lock: StoreLock
    public private(set) var records: [TransferRecord]
    public private(set) var blocked = false
    private struct Observation { let taskID: Int; let status: Int?; let errorCode: Int? }
    private var pendingObservations: [Observation] = []
    public var hasUnpersistedObservations: Bool { !pendingObservations.isEmpty }
    private var file: URL { root.appendingPathComponent("transfers.json") }
    public init(root: URL) throws {
        self.root = root
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        lock = try StoreLock(root: root)
        let file = root.appendingPathComponent("transfers.json")
        if FileManager.default.fileExists(atPath: file.path) {
            records = try JSONDecoder().decode([TransferRecord].self, from: Data(contentsOf: file))
            guard Set(records.map(\.id)).count == records.count else { throw ProbeError.invalid }
        } else {
            guard try FileManager.default.contentsOfDirectory(atPath: root.path).allSatisfy({ $0 == "writer.lock" }) else { throw ProbeError.blocked }
            records = []; try DurableFile.save(records, to: file)
        }
    }
    private func commit(_ next: [TransferRecord]) throws {
        guard !blocked else { throw ProbeError.blocked }
        do { try DurableFile.save(next, to: file); records = next }
        catch { blocked = true; throw error }
    }
    public static func hash(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
    public func plan(body: Data, endpoint: URL, method: String) throws -> TransferRecord {
        guard !blocked, ["POST", "PUT"].contains(method), body.count <= 1024 * 1024 else { throw ProbeError.invalid }
        let id = UUID(), name = UUID().uuidString + ".body"
        try DurableFile.write(body, to: root.appendingPathComponent(name))
        let record = TransferRecord(id: id, endpoint: endpoint, method: method, filename: name, sha256: Self.hash(body), phase: "planned")
        try commit(records + [record]); return record
    }
    public func attach(_ id: UUID, taskID: Int) throws {
        guard let i = records.firstIndex(where: { $0.id == id }), records[i].taskID == nil else { throw ProbeError.invalid }
        var next = records; next[i].taskID = taskID; next[i].phase = "attached"
        try commit(next)
    }
    /// Missing tasks are unknown, never permission to resubmit. Orphans are held/canceled.
    public func reconcile(_ tasks: [TaskSnapshot]) throws -> [Int] {
        var next = records, orphans: [Int] = [], seen: Set<UUID> = []
        for task in tasks {
            guard let text = task.description, let id = UUID(uuidString: text),
                  let i = next.firstIndex(where: { $0.id == id }),
                  !seen.contains(id), next[i].endpoint == task.endpoint, next[i].method == task.method,
                  next[i].taskID == nil || next[i].taskID == task.taskID,
                  next[i].phase != "observed" else { orphans.append(task.taskID); continue }
            let body = try Data(contentsOf: root.appendingPathComponent(next[i].filename))
            guard Self.hash(body) == next[i].sha256 else { blocked = true; throw ProbeError.invalid }
            seen.insert(id); next[i].taskID = task.taskID; next[i].phase = "attached"
        }
        for i in next.indices where !seen.contains(next[i].id) && next[i].phase != "observed" { next[i].phase = "needs-reconciliation" }
        try commit(next); return orphans
    }
    public func observe(taskID: Int, status: Int?, errorCode: Int?) throws {
        pendingObservations.append(Observation(taskID: taskID, status: status, errorCode: errorCode))
        try flushObservations()
    }
    private func flushObservations() throws {
        while let observation = pendingObservations.first {
            guard let i = records.firstIndex(where: { $0.taskID == observation.taskID }) else { throw ProbeError.invalid }
            var next = records
            next[i].phase = "observed"; next[i].httpStatus = observation.status; next[i].errorCode = observation.errorCode
            try commit(next) // HTTP success is an observation, never a complete-audio receipt.
            pendingObservations.removeFirst()
        }
    }
    /// Called only on the same serial owner after failed observation writes have drained.
    public func recoverObservations() throws {
        blocked = true
        let disk = try JSONDecoder().decode([TransferRecord].self, from: Data(contentsOf: file))
        guard Set(disk.map(\.id)).count == disk.count else { throw ProbeError.invalid }
        records = disk; blocked = false
        try flushObservations()
    }
}
