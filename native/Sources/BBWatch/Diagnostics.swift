import Foundation

/// Local correlation only: never use server/thread/device IDs for these identifiers.
struct DiagnosticOperation: Sendable {
    let id = UUID()
    let started = ContinuousClock.now
}

enum DiagnosticEvent: String, Sendable {
    case appStarted = "app.started", networkAvailable = "network.available", networkUnavailable = "network.unavailable"
    case sceneActive = "scene.active", sceneInactive = "scene.inactive", sceneBackground = "scene.background"
    case timelineStarted = "timeline.started", timelineReceived = "timeline.received", timelineFailed = "timeline.failed"
    case stageApplied = "stage.applied", stageDiscarded = "stage.discarded"
    case refreshStarted = "refresh.started", refreshFinished = "refresh.finished", refreshFailed = "refresh.failed"
    case threadsApplied = "threads.applied", projectsFailed = "projects.failed", questionsFailed = "questions.failed"
    case deliveryStarted = "delivery.started", deliveryFailed = "delivery.failed"
    case sendStarted = "send.started", sendAccepted = "send.accepted"
    case assemblyStarted = "assembly.started", assemblyFinished = "assembly.finished"
    case transcriptionStarted = "transcription.started", transcriptionFinished = "transcription.finished", transcriptionCached = "transcription.cached"
}

/// Bounded local diagnostics. Typed fields prevent accidental content/URL logging.
actor WatchDiagnostics {
    static let shared = WatchDiagnostics(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("BBWatch"))
    private let directory: URL
    init(directory: URL) { self.directory = directory }

    func record(_ event: DiagnosticEvent, operation: DiagnosticOperation? = nil, selection: UUID? = nil,
                foreground: Bool? = nil, group: Int? = nil, count: Int? = nil, bytes: Int? = nil, audioMilliseconds: Int? = nil, error: Error? = nil) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let file = directory.appendingPathComponent("diagnostics.log")
            var fields = [Date().ISO8601Format(.init(includingFractionalSeconds: true)), event.rawValue]
            if let operation {
                let elapsed = operation.started.duration(to: .now).components
                let milliseconds = Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15
                fields += ["op=\(operation.id.uuidString)", "elapsed_ms=\(Int(milliseconds))"]
            }
            if let selection { fields.append("selection=\(selection.uuidString)") }
            if let foreground { fields.append("foreground=\(foreground ? 1 : 0)") }
            if let group { fields.append("group=\(group)") }
            if let count { fields.append("count=\(count)") }
            if let bytes { fields.append("bytes=\(bytes)") }
            if let audioMilliseconds { fields.append("audio_ms=\(audioMilliseconds)") }
            if let error {
                let failure = error as NSError
                // Custom NSError domains and descriptions may contain private content.
                let category = failure.domain == NSURLErrorDomain ? "network" : failure.domain == NSCocoaErrorDomain ? "storage" : "other"
                fields.append("error=\(category):\(failure.code)")
            }
            // Preserve existing incident evidence until it naturally ages out of the bounded log.
            var lines = (try? String(contentsOf: file, encoding: .utf8))?.split(separator: "\n").suffix(199).map(String.init) ?? []
            lines.append("v2 " + fields.joined(separator: " "))
            try (lines.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
        } catch { /* Diagnostics must never prevent recording or delivery. */ }
    }
}
