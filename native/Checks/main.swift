import Foundation
import ProbeCore
import Darwin

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw NSError(domain: message, code: 1) }
}

if CommandLine.arguments.count == 4 && CommandLine.arguments[1] == "--crash-child" {
    let dir = URL(fileURLWithPath: CommandLine.arguments[2])
    let store = try CaptureStore(root: dir)
    let attempt = try store.begin()
    let pcm = [Float](repeating: 0.125, count: 480).withUnsafeBytes { Data($0) }
    try store.append(pcm, frames: 480, sampleRate: 48000, channels: 1, attempt: attempt.id)
    if CommandLine.arguments[3] == "enqueued" { try store.stop(attempt: attempt.id); try store.enqueue() }
    try DurableFile.write(Data("ready".utf8), to: dir.appendingPathComponent("child-ready"))
    while true { pause() }
}

let root = FileManager.default.temporaryDirectory.appendingPathComponent("voiceprobe-check-" + UUID().uuidString)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
let pcm = [Float](repeating: 0.125, count: 480).withUnsafeBytes { Data($0) }
let captureRoot = root.appendingPathComponent("capture")
var store: CaptureStore? = try CaptureStore(root: captureRoot)
let a = try store!.begin()
try require(store!.ledger.currentDraft == nil, "activation must not invent audio")
try store!.append(pcm, frames: 480, sampleRate: 48000, channels: 1, attempt: a.id)
let draftID = store!.ledger.currentDraft!.id
try store!.stop(attempt: a.id)
let b = try store!.begin()
try store!.append(pcm, frames: 480, sampleRate: 44100, channels: 1, attempt: b.id)
try store!.stop(attempt: b.id)
try require(store!.ledger.currentDraft!.id == draftID, "append changed thought identity")
try require(store!.ledger.currentDraft!.parts.map(\.frames) == [480, 480], "short inputs not sealed independently")
try require(store!.ledger.currentDraft!.parts.allSatisfy { $0.incomplete.isEmpty }, "intentional stop became missing speech")
try store!.append(pcm, frames: 480, sampleRate: 48000, channels: 1, attempt: a.id)
try require(store!.ledger.currentDraft!.frames == 960, "late input wrote ended attempt")
let operation = try store!.enqueue()
store = nil
store = try CaptureStore(root: captureRoot)
try require(store!.ledger.currentDraft == nil && store!.ledger.outbox.count == 1, "enqueue resurrected editable audio")
try require(store!.ledger.outbox[0].id == operation.id, "operation identity changed on relaunch")
let c = try store!.begin()
try store!.append(pcm, frames: 480, sampleRate: 48000, channels: 1, attempt: c.id)
store = nil // Simulated process-end boundary: do not call stop.
store = try CaptureStore(root: captureRoot)
try require(store!.ledger.currentDraft!.parts[0].incomplete == ["process-ended-during-capture"], "crash gap not preserved")
try require(store!.ledger.attempt == nil, "launch resurrected mic ownership")
let d = try store!.begin()
try store!.append(pcm, frames: 480, sampleRate: 48000, channels: 1, attempt: d.id)
try store!.stop(attempt: d.id)
let next = try store!.enqueue()
try require(next.sequence == 2 && next.predecessors == [operation.id], "send-order ledger lost")
// Fail the real filesystem replacement, rather than mocking a successful commit.
let ledgerURL = captureRoot.appendingPathComponent("capture.json")
let backup = captureRoot.appendingPathComponent("saved-ledger.json")
try FileManager.default.moveItem(at: ledgerURL, to: backup)
try FileManager.default.createDirectory(at: ledgerURL, withIntermediateDirectories: false)
do { _ = try store!.begin(); throw NSError(domain: "write should fail", code: 1) }
catch is ProbeError { }
try require(store!.blocked, "uncertain writer remained editable")
do { _ = try store!.begin(); throw NSError(domain: "blocked writer accepted retry", code: 1) }
catch ProbeError.blocked { }
try FileManager.default.removeItem(at: ledgerURL) // Test-owned obstruction, never app recovery.
try FileManager.default.moveItem(at: backup, to: ledgerURL)
try store!.recover()
try require(store!.ledger.outbox.count == 2 && store!.ledger.attempt == nil, "readback lost committed identity")
print("PASS capture: first frame, short stop, same-draft append, late input, atomic enqueue, relaunch, crash mark, blocked-write readback")
let transfers = try TransferLedger(root: root.appendingPathComponent("transfer"))
let endpoint = URL(string: "http://127.0.0.1:8765/fixture")!
let one = try transfers.plan(body: Data("synthetic".utf8), endpoint: endpoint, method: "PUT")
let two = try transfers.plan(body: Data("another".utf8), endpoint: endpoint, method: "POST")
let orphan = try transfers.reconcile([
    TaskSnapshot(taskID: 7, description: one.id.uuidString, endpoint: endpoint, method: "PUT"),
    TaskSnapshot(taskID: 8, description: nil, endpoint: endpoint, method: "PUT")
])
try require(orphan == [8], "unidentified OS task adopted")
try require(transfers.records[0].taskID == 7 && transfers.records[1].id == two.id && transfers.records[1].phase == "needs-reconciliation", "task creation gap duplicated/lost identity")
try transfers.observe(taskID: 7, status: 200, errorCode: nil)
try require(FileManager.default.fileExists(atPath: transfers.root.appendingPathComponent(one.filename).path), "HTTP 200 deleted source")
try require(transfers.records[0].phase == "observed", "HTTP 200 became receipt")
print("PASS transfer ledger: task adoption, orphan rejection, missing task ambiguity, HTTP observation retains source")
print("Synthetic artifacts: \(root.path)")

for boundary in ["capturing", "enqueued"] {
    let dir = root.appendingPathComponent("kill-" + boundary)
    let child = Process()
    child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
    child.arguments = ["--crash-child", dir.path, boundary]
    try child.run()
    let deadline = Date().addingTimeInterval(5)
    while !FileManager.default.fileExists(atPath: dir.appendingPathComponent("child-ready").path) && Date() < deadline { usleep(1000) }
    kill(child.processIdentifier, SIGKILL); child.waitUntilExit()
    try require(FileManager.default.fileExists(atPath: dir.appendingPathComponent("child-ready").path), "child did not reach crash boundary")
    let recovered = try CaptureStore(root: dir)
    if boundary == "capturing" {
        try require(recovered.ledger.currentDraft?.frames == 480 && recovered.ledger.attempt == nil, "SIGKILL lost committed prefix")
        try require(recovered.ledger.currentDraft?.parts.first?.incomplete == ["process-ended-during-capture"], "SIGKILL gap absent")
    } else {
        try require(recovered.ledger.currentDraft == nil && recovered.ledger.outbox.count == 1, "SIGKILL resurrected enqueued draft")
    }
}
print("PASS actual child SIGKILL: capture prefix + interruption mark; committed enqueue remains noneditable")

let observationRoot = root.appendingPathComponent("observation-failure")
let observationStore = try TransferLedger(root: observationRoot)
let observation = try observationStore.plan(body: Data("fixture".utf8), endpoint: endpoint, method: "PUT")
try observationStore.attach(observation.id, taskID: 42)
let observationFile = observationRoot.appendingPathComponent("transfers.json")
let observationBackup = observationRoot.appendingPathComponent("saved.json")
try FileManager.default.moveItem(at: observationFile, to: observationBackup)
try FileManager.default.createDirectory(at: observationFile, withIntermediateDirectories: false)
do { try observationStore.observe(taskID: 42, status: 200, errorCode: nil); throw NSError(domain: "observation must fail", code: 1) }
catch is ProbeError { }
try require(observationStore.hasUnpersistedObservations, "failed completion was dropped")
do { try observationStore.recoverObservations(); throw NSError(domain: "refresh must stay unresolved", code: 1) }
catch is CocoaError { }
try require(observationStore.hasUnpersistedObservations && observationStore.records[0].phase == "attached", "finish-events converted failed persistence into success")
try FileManager.default.removeItem(at: observationFile)
try FileManager.default.moveItem(at: observationBackup, to: observationFile)
try observationStore.recoverObservations()
try require(!observationStore.hasUnpersistedObservations && observationStore.records[0].httpStatus == 200, "refresh recovery lost observation")
print("PASS failed transfer observation retained across finish/readback failure, then persisted without replay")
