import Foundation

struct BBProject: Codable, Identifiable, Sendable { let id: String; let name: String }
struct BBThread: Codable, Identifiable, Sendable {
    let id: String
    let title: String?
    let projectId: String?
    let hasPendingInteraction: Bool?
    let titleFallback: String?
    let parentThreadId: String?
    let lifecycleOwnerThreadId: String?
    let visibility: String?
    let archivedAt: Double?
    let pinnedAt: Double?
    let pinSortKey: String?
    let updatedAt: Double?
    let latestAttentionAt: Double?
    let environmentBranchName: String?
    init(id: String, title: String?, projectId: String?, hasPendingInteraction: Bool? = nil,
         titleFallback: String? = nil, parentThreadId: String? = nil, lifecycleOwnerThreadId: String? = nil,
         visibility: String? = nil, archivedAt: Double? = nil, pinnedAt: Double? = nil,
         pinSortKey: String? = nil, updatedAt: Double? = nil, latestAttentionAt: Double? = nil,
         environmentBranchName: String? = nil) {
        self.id = id; self.title = title; self.projectId = projectId; self.hasPendingInteraction = hasPendingInteraction
        self.titleFallback = titleFallback; self.parentThreadId = parentThreadId; self.lifecycleOwnerThreadId = lifecycleOwnerThreadId
        self.visibility = visibility; self.archivedAt = archivedAt; self.pinnedAt = pinnedAt; self.pinSortKey = pinSortKey
        self.updatedAt = updatedAt; self.latestAttentionAt = latestAttentionAt; self.environmentBranchName = environmentBranchName
    }
}
struct BBMessage: Codable, Identifiable, Sendable { let id: String; let role: String; let text: String }
struct BBOption: Codable, Identifiable, Sendable { let id: String; let label: String }
struct BBQuestion: Codable, Identifiable, Sendable {
    let id: String
    let threadID: String
    let title: String
    let prompt: String
    let options: [BBOption]
    let supported: Bool
    let questionID: String?
}
struct BBSendReceipt: Codable, Sendable { let delivery: String; let acceptedAt: Date; let threadID: String }
struct BBPairing: Sendable { let serverURL: String; let credential: String; let machineId: String }
enum BBClientError: LocalizedError {
    case invalidServer, invalidResponse, http(Int), acceptanceUnknown, unsupportedQuestion
    var errorDescription: String? {
        switch self {
        case .invalidServer: "A secure BB address is required."
        case .invalidResponse: "BB returned an unrecognized response."
        case .http(let status): "BB request failed (HTTP \(status))."
        case .acceptanceUnknown: "BB may have accepted this message. Automatic retry is paused to prevent a duplicate."
        case .unsupportedQuestion: "This question type isn't supported here."
        }
    }
}

/// Direct BB 0.46 adapter. A transport failure during a mutation is never retried.
private final class BBNoRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

actor BBClient {
    let serverURL: URL
    private let credential: String
    private let session: URLSession
    private var sessionExpires = Date.distantPast
    private var sessionCookie: HTTPCookie?
    private var authentication: Task<Void, Error>?
    private let decoder = JSONDecoder()
    init(serverURL: URL, credential: String, session: URLSession? = nil) {
        self.serverURL = serverURL; self.credential = credential
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 120
        self.session = session ?? URLSession(configuration: config, delegate: BBNoRedirect(), delegateQueue: nil)
    }
    static func redeem(code: String, apex: URL = URL(string: "https://getbb.app")!) async throws -> BBPairing {
        guard apex.scheme == "https", let apexHost = apex.host else { throw BBClientError.invalidServer }
        var request = URLRequest(url: apex.appendingPathComponent("api/connect/redeem-machine"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["code": code, "deviceName": "Apple Watch"])
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        request.timeoutInterval = 20
        let pairingSession = URLSession(configuration: configuration, delegate: BBNoRedirect(), delegateQueue: nil)
        defer { pairingSession.invalidateAndCancel() }
        let (data, response) = try await pairingSession.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw BBClientError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else { throw BBClientError.http(response.statusCode) }
        struct Pair: Decodable { let credential: String; let serverUrl: String?; let machineId: String }
        let pair = try JSONDecoder().decode(Pair.self, from: data)
        guard let value = pair.serverUrl, let url = URL(string: value), url.scheme == "https", let host = url.host,
              host.hasSuffix("." + apexHost), host.split(separator: ".").count == apexHost.split(separator: ".").count + 1,
              url.user == nil, url.password == nil, !pair.credential.isEmpty else { throw BBClientError.invalidServer }
        return BBPairing(serverURL: url.absoluteString, credential: pair.credential, machineId: pair.machineId)
    }
    private func authenticate() async throws {
        guard serverURL.scheme == "https", serverURL.host != nil, serverURL.user == nil, serverURL.password == nil else { throw BBClientError.invalidServer }
        if sessionExpires.timeIntervalSinceNow > 60 { return }
        if let authentication { return try await authentication.value }
        let task = Task { try await self.openSession() }
        authentication = task
        defer { authentication = nil }
        try await task.value
    }
    private func openSession() async throws {
        var request = URLRequest(url: serverURL.appendingPathComponent("api/connect/desktop-session"))
        request.timeoutInterval = 20
        request.httpMethod = "POST"
        request.setValue(credential, forHTTPHeaderField: "x-bb-connect-machine")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw BBClientError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else { throw BBClientError.http(response.statusCode) }
        struct Session: Decodable { struct Cookie: Decodable { let domain: String; let expiresAt: Double; let name: String; let value: String }; let cookie: Cookie }
        let cookie = try decoder.decode(Session.self, from: data).cookie
        let bare = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard let host = serverURL.host, host == bare || host.hasSuffix("." + bare) else { throw BBClientError.invalidResponse }
        let expiry = Date(timeIntervalSince1970: cookie.expiresAt / 1000)
        guard expiry > Date(), let value = HTTPCookie(properties: [.domain: cookie.domain, .path: "/", .name: cookie.name, .value: cookie.value, .secure: "TRUE", .expires: expiry, HTTPCookiePropertyKey("HttpOnly"): "TRUE"]) else { throw BBClientError.invalidResponse }
        sessionCookie = value
        sessionExpires = expiry
    }
    private func request(_ path: String, body: Data? = nil, contentType: String = "application/json", mutation: Bool = false, refreshed: Bool = false) async throws -> Data {
        try await authenticate()
        var request = URLRequest(url: serverURL.appendingPathComponent("api/v1/" + path))
        request.timeoutInterval = path == "system/voice-transcription" ? 90 : 20
        let sentCookie = sessionCookie
        if let cookie = sentCookie {
            for (name, value) in HTTPCookie.requestHeaderFields(with: [cookie]) { request.setValue(value, forHTTPHeaderField: name) }
        }
        if let body { request.httpMethod = "POST"; request.httpBody = body; request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        let result: (Data, URLResponse)
        do { result = try await session.data(for: request) }
        catch { if mutation { throw BBClientError.acceptanceUnknown }; throw error }
        guard let response = result.1 as? HTTPURLResponse else { throw mutation ? BBClientError.acceptanceUnknown : BBClientError.invalidResponse }
        if response.statusCode == 401 || response.statusCode == 403 {
            // A late response from an older session must not invalidate its replacement.
            if sessionCookie === sentCookie { sessionExpires = .distantPast }
            if response.statusCode == 401 && body == nil && !mutation && !refreshed {
                return try await self.request(path, refreshed: true)
            }
        }
        guard (200..<300).contains(response.statusCode) else {
            if mutation && response.statusCode >= 500 { throw BBClientError.acceptanceUnknown }
            throw BBClientError.http(response.statusCode)
        }
        return result.0
    }
    private func json(_ value: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: value) }
    func projects() async throws -> [BBProject] { try decoder.decode([BBProject].self, from: await request("projects")) }
    func threads() async throws -> [BBThread] {
        struct Project: Decodable { let threads: [BBThread] }
        struct Sidebar: Decodable { let projects: [Project]; let personalProject: Project }
        let sidebar = try decoder.decode(Sidebar.self, from: await request("sidebar-bootstrap"))
        var seen = Set<String>()
        return (sidebar.projects + [sidebar.personalProject]).flatMap(\.threads).filter { seen.insert($0.id).inserted }
    }
    func messages(threadID: String) async throws -> [BBMessage] {
        struct Row: Decodable { let id: String; let kind: String; let role: String?; let text: String? }
        struct Page: Decodable { let rows: [Row] }
        let page = try decoder.decode(Page.self, from: await request("threads/\(threadID)/timeline"))
        return page.rows.compactMap { row in
            guard row.kind == "conversation", let role = row.role, let text = row.text else { return nil }
            return BBMessage(id: row.id, role: role, text: text)
        }
    }
    func questions(threads: [BBThread]) async throws -> [BBQuestion] {
        var result: [BBQuestion] = []
        // Bound radio/server load while avoiding one round trip per thread in series.
        for start in stride(from: 0, to: threads.count, by: 4) {
            let batch = Array(threads[start..<min(start + 4, threads.count)])
            let rows = try await withThrowingTaskGroup(of: (Int, [BBQuestion]).self) { group in
                for (index, thread) in batch.enumerated() {
                    group.addTask { (index, try await self.questions(thread: thread)) }
                }
                var rows: [(Int, [BBQuestion])] = []
                for try await row in group { rows.append(row) }
                return rows.sorted { $0.0 < $1.0 }.flatMap { $0.1 }
            }
            result.append(contentsOf: rows)
        }
        return result
    }
    private func questions(thread: BBThread) async throws -> [BBQuestion] {
        struct Item: Decodable {
            struct Payload: Decodable {
                struct Question: Decodable {
                    struct Option: Decodable { let value: String; let label: String }
                    let id: String; let prompt: String; let multiSelect: Bool; let options: [Option]?; let allowFreeText: Bool
                }
                let kind: String; let questions: [Question]?
            }
            let id: String; let payload: Payload
        }
        var result: [BBQuestion] = []
        do {
            let items = try decoder.decode([Item].self, from: await request("threads/\(thread.id)/interactions"))
            for item in items {
                let questions = item.payload.questions ?? []
                let single = questions.count == 1 ? questions.first : nil
                result.append(BBQuestion(id: item.id, threadID: thread.id, title: thread.title ?? "BB", prompt: questions.map(\.prompt).joined(separator: "\n\n"), options: single?.options?.map { BBOption(id: $0.value, label: $0.label) } ?? [], supported: item.payload.kind == "user_question" && single != nil && single?.multiSelect == false, questionID: single?.id))
            }
        }
        return result
    }
    func transcribe(file: URL) async throws -> String {
        let boundary = UUID().uuidString
        var body = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"recording.wav\"\r\nContent-Type: audio/wav\r\n\r\n".utf8)
        body.append(try Data(contentsOf: file)); body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        struct Transcript: Decodable { let text: String }
        return try decoder.decode(Transcript.self, from: await request("system/voice-transcription", body: body, contentType: "multipart/form-data; boundary=\(boundary)")).text
    }
    func send(text: String, threadID: String) async throws -> BBSendReceipt {
        let body = try json(["input": [["type": "text", "text": text]], "mode": "queue-if-active"])
        let data = try await request("threads/\(threadID)/send", body: body, mutation: true)
        struct Receipt: Decodable { let ok: Bool; let delivery: String }
        guard let receipt = try? decoder.decode(Receipt.self, from: data), receipt.ok, ["sent", "queued"].contains(receipt.delivery) else { throw BBClientError.acceptanceUnknown }
        return BBSendReceipt(delivery: receipt.delivery, acceptedAt: Date(), threadID: threadID)
    }
    /// BB creates and dispatches the initial prompt in one operation. Never send it twice.
    func createThread(projectID: String, text: String) async throws -> BBThread {
        let body = try json(["projectId": projectID, "origin": "sdk", "environment": ["type": "project-default"], "input": [["type": "text", "text": text]]])
        let data = try await request("threads", body: body, mutation: true)
        guard let thread = try? decoder.decode(BBThread.self, from: data) else { throw BBClientError.acceptanceUnknown }
        return thread
    }
    func resolve(question: BBQuestion, optionID: String) async throws -> String {
        guard question.supported, let questionID = question.questionID, question.options.contains(where: { $0.id == optionID }) else { throw BBClientError.unsupportedQuestion }
        let body = try json(["kind": "user_answer", "answers": [questionID: ["selected": [optionID]]]])
        let data = try await request("threads/\(question.threadID)/interactions/\(question.id)/resolve", body: body, mutation: true)
        struct Resolution: Decodable { let id: String; let status: String }
        guard let receipt = try? decoder.decode(Resolution.self, from: data), receipt.id == question.id, ["resolving", "resolved"].contains(receipt.status) else { throw BBClientError.acceptanceUnknown }
        return receipt.id
    }
}
