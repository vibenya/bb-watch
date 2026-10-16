import Foundation

/// Bounded local diagnostics: no credentials, URLs, messages, or audio content.
actor WatchDiagnostics {
    static let shared = WatchDiagnostics()
    func record(_ event: String, error: Error? = nil) {
        do {
            let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("BBWatch")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appendingPathComponent("diagnostics.log")
            var lines = (try? String(contentsOf: file, encoding: .utf8))?.split(separator: "\n").suffix(199).map(String.init) ?? []
            let failure = error.map { " error=\(($0 as NSError).domain):\(($0 as NSError).code)" } ?? ""
            lines.append("\(Date().ISO8601Format()) \(event)\(failure)")
            try (lines.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
        } catch { /* Diagnostics must never prevent recording or delivery. */ }
    }
}
