import Foundation

struct OfflineCache: Codable {
    var identity: String
    var updatedAt: Date
    var projects: [BBProject]
    var threads: [BBThread]
    var questions: [BBQuestion]
    var messages: [String: [BBMessage]] = [:]
}
