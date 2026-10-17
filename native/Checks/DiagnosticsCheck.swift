import Foundation

@main
struct DiagnosticsCheck {
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let diagnostics = WatchDiagnostics(directory: directory)
        let operation = DiagnosticOperation()
        let secret = "private-transcript-https://token:password@example.invalid"
        let failure = NSError(domain: secret, code: 71, userInfo: [NSLocalizedDescriptionKey: secret])
        await diagnostics.record(.timelineStarted, operation: operation, foreground: true)
        await diagnostics.record(.timelineFailed, operation: operation, foreground: false, error: failure)
        let file = directory.appendingPathComponent("diagnostics.log")
        let first = try String(contentsOf: file, encoding: .utf8)
        let timestamp = first.split(separator: "\n")[0].split(separator: " ")[1]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        precondition(formatter.date(from: String(timestamp)) != nil, "Milestone needs full date, timezone and fractional time")
        precondition(!first.contains(secret), "NSError content leaked into diagnostics")
        precondition(first.components(separatedBy: operation.id.uuidString).count == 3, "Request correlation missing")
        precondition(first.contains("foreground=1") && first.contains("foreground=0") && first.contains("elapsed_ms="), "Timing/lifecycle context missing")
        for index in 0..<205 {
            await diagnostics.record(.transcriptionStarted, operation: operation, group: index, bytes: 1024)
        }
        let retained = try String(contentsOf: file, encoding: .utf8)
        precondition(retained.split(separator: "\n").count == 200, "Diagnostics grew beyond bounded retention")
        precondition(!retained.contains("timeline.started") && retained.contains("group=204 "), "Newest milestones not retained")
        precondition(retained.utf8.count < 100_000, "Typed records unexpectedly large")
        print("Diagnostics privacy, correlation and bounded retention passed")
    }
}
