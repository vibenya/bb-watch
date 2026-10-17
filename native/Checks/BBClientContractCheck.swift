import Foundation

// Protocol-level fixture follows BB 0.46 contracts, independently sourced from
// server-contract and connect-client; tests actual URLSession serialization.
final class WireFixture: URLProtocol, @unchecked Sendable {
    static let lock = NSLock()
    nonisolated(unsafe) static var authCalls = 0
    nonisolated(unsafe) static var rejectProjects = 0
    nonisolated(unsafe) static var sends = 0
    nonisolated(unsafe) static var projectCalls = 0
    nonisolated(unsafe) static var projectFailures: [URLError.Code] = []
    nonisolated(unsafe) static var authenticated = false
    nonisolated(unsafe) static var rejectHistory = false
    // Minimal projections of installed BB's thread + timeline contracts.
    // Runtime status is independent of historical timeline rows.
    static let statuses = ["thr_one": "idle", "thr_completed": "idle", "thr_running": "active",
                           "thr_error": "error", "thr_system": "idle", "thr_mixed": "idle",
                           "thr_next_turn": "active", "thr_interrupted": "idle", "thr_starting": "starting"]
    static let timelines: [String: String] = [
        "thr_completed": #"{"rows":[{"id":"u1","kind":"conversation","role":"user","text":"Go"},{"id":"w1","kind":"work","turnId":"old","status":"pending","command":"Old tool"}]}"#,
        "thr_running": #"{"rows":[{"id":"t1","kind":"turn","turnId":"old","status":"completed"},{"id":"w1","kind":"work","turnId":"current","status":"completed","command":"Read file"},{"id":"w2","kind":"work","turnId":"current","status":"pending","workKind":"tool","toolName":"exec_command","presentation":{"title":"Run tests"}}]}"#,
        "thr_error": #"{"rows":[{"id":"w1","kind":"work","turnId":"old","status":"pending","command":"Run tests"}]}"#,
        "thr_system": #"{"rows":[{"id":"s1","kind":"system","title":"Context compacted"}]}"#,
        "thr_mixed": #"{"rows":[{"id":"c1","kind":"conversation","role":"user","text":"First"},{"id":"w1","kind":"work","command":"ls"},{"id":"c2","kind":"conversation","role":"assistant","text":"Second"},{"id":"x1","kind":"system","text":"Noise"},{"id":"c3","kind":"conversation","role":"assistant"},{"id":"c4","kind":"conversation","role":"user","text":"Third"}]}"#,
        "thr_next_turn": #"{"rows":[{"id":"w1","kind":"work","turnId":"old","status":"pending","command":"Old tool"},{"id":"u2","kind":"conversation","turnId":"new","role":"user","text":"Next"}]}"#,
        "thr_starting": #"{"rows":[{"id":"w1","kind":"work","turnId":"old","status":"pending","command":"Old tool"},{"id":"t1","kind":"turn","turnId":"old","status":"completed"}]}"#,
        "thr_interrupted": #"{"rows":[{"id":"t1","kind":"turn","turnId":"old","status":"interrupted"}]}"#,
    ]
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "fixture.getbb.app" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        do {
            let path = request.url!.path
            let data: Data
            if path == "/api/connect/desktop-session" {
                guard request.value(forHTTPHeaderField: "x-bb-connect-machine") == "fixture-only" else { throw CheckFailure.badCredential }
                Self.authCalls += 1
                Self.authenticated = true
                data = try JSONSerialization.data(withJSONObject: ["cookie": ["domain": "fixture.getbb.app", "expiresAt": Date().addingTimeInterval(600).timeIntervalSince1970 * 1000, "name": "fixture-session", "value": "fixture-cookie"]])
            } else {
                guard Self.authenticated, request.value(forHTTPHeaderField: "Cookie")?.contains("fixture-session=fixture-cookie") == true else { throw CheckFailure.missingAuth }
                if path == "/api/v1/projects" {
                    Self.projectCalls += 1
                    if !Self.projectFailures.isEmpty {
                        client?.urlProtocol(self, didFailWithError: URLError(Self.projectFailures.removeFirst()))
                        return
                    }
                }
                if path == "/api/v1/projects", Self.rejectProjects > 0 {
                    Self.rejectProjects -= 1
                    let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
                    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                    client?.urlProtocolDidFinishLoading(self)
                    return
                }
                switch path {
                case "/api/v1/projects": data = Data(#"[{"id":"proj_one","name":"One"}]"#.utf8)
                case "/api/v1/sidebar-bootstrap":
                    let entries: [[String: Any]] = (0..<60).map { ["id": "thr_\($0)", "title": NSNull(), "projectId": "proj_one", "hasPendingInteraction": $0 == 59] }
                    data = try JSONSerialization.data(withJSONObject: ["projects": [["threads": entries]], "personalProject": ["threads": [entries[0], ["id": "thr_personal", "title": "Personal", "projectId": "personal", "hasPendingInteraction": false]]]])
                case "/api/v1/threads/thr_history/timeline":
                    let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems ?? []
                    guard query.contains(URLQueryItem(name: "segmentLimit", value: "30")) else { throw CheckFailure.assertion }
                    let anchor = query.first { $0.name == "beforeAnchorId" }?.value
                    if Self.rejectHistory {
                        Self.rejectHistory = false
                        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
                        client?.urlProtocolDidFinishLoading(self)
                        return
                    }
                    if anchor == "stale" {
                        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
                        client?.urlProtocolDidFinishLoading(self)
                        return
                    }
                    if let anchor {
                        guard anchor == "timeline-v3:opaque+/=&?", query.contains(URLQueryItem(name: "beforeAnchorSeq", value: "42")) else { throw CheckFailure.assertion }
                        data = Data(#"{"rows":[{"id":"old","kind":"conversation","role":"user","text":"Older"},{"id":"tool","kind":"work","text":"Hidden"},{"id":"overlap","kind":"conversation","role":"assistant","text":"Complete older answer"}],"timelinePage":{"hasOlderRows":false,"olderCursor":null}}"#.utf8)
                    } else {
                        guard !query.contains(where: { $0.name == "beforeAnchorSeq" }) else { throw CheckFailure.assertion }
                        data = Data(#"{"rows":[{"id":"overlap","kind":"conversation","role":"assistant","text":"Complete older answer"},{"id":"latest","kind":"conversation","role":"user","text":"Newest"}],"timelinePage":{"hasOlderRows":true,"olderCursor":{"anchorSeq":42,"anchorId":"timeline-v3:opaque+/=&?"}}}"#.utf8)
                    }
                case "/api/v1/threads/thr_one/timeline": data = Data(#"{"rows":[{"id":"r1","kind":"conversation","role":"assistant","text":"Real response"},{"id":"r2","kind":"system","text":"Never assistant"}]}"#.utf8)
                case "/api/v1/threads/thr_one/interactions":
                    data = Data(#"[{"id":"interaction-one","payload":{"kind":"user_question","questions":[{"id":"q1","prompt":"Continue?","multiSelect":false,"allowFreeText":true,"options":[{"value":"yes","label":"Да"}]}]}},{"id":"interaction-multi","payload":{"kind":"user_question","questions":[{"id":"q1","prompt":"A?","multiSelect":false,"allowFreeText":true},{"id":"q2","prompt":"B?","multiSelect":false,"allowFreeText":true}]}}]"#.utf8)
                case "/api/v1/threads/thr_one/interactions/interaction-one/resolve":
                    data = Data(#"{"id":"interaction-one","status":"resolving"}"#.utf8)
                case "/api/v1/threads/thr_one/send":
                    Self.sends += 1
                    var bytes = request.httpBody ?? Data()
                    if let stream = request.httpBodyStream {
                        stream.open(); defer { stream.close() }
                        var buffer = [UInt8](repeating: 0, count: 4096)
                        while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; bytes.append(buffer, count: count) }
                    }
                    let body = try JSONSerialization.jsonObject(with: bytes) as? [String: Any]
                    guard body?["mode"] as? String == "queue-if-active", let input = body?["input"] as? [[String: String]], input.first?["text"] == "Persisted brief" else { throw CheckFailure.badSend }
                    if Self.sends > 1 { client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost)); return }
                    data = Data(#"{"ok":true,"delivery":"queued","queuedMessage":{"id":"queue-one"}}"#.utf8)
                default:
                    let parts = path.split(separator: "/").map(String.init)
                    if parts.count == 4, parts[2] == "threads", let status = Self.statuses[parts[3]] {
                        data = try JSONSerialization.data(withJSONObject: ["id": parts[3], "status": status, "runtime": ["displayStatus": status]])
                        break
                    }
                    guard parts.count == 5, parts[2] == "threads", parts[4] == "timeline", let json = Self.timelines[parts[3]] else { throw CheckFailure.unexpectedPath }
                    data = Data(json.utf8)
                }
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            let deliver: @Sendable () -> Void = { [self] in
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            }
            if path == "/api/connect/desktop-session" {
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.05, execute: deliver)
            } else { deliver() }
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
}
enum CheckFailure: Error { case badCredential, missingAuth, badSend, unexpectedPath, assertion }
@main struct ContractCheck {
    static func main() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WireFixture.self]
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        let client = BBClient(serverURL: URL(string: "https://fixture.getbb.app")!, credential: "fixture-only", session: URLSession(configuration: configuration))
        async let projects = client.projects()
        async let threads = client.threads()
        guard try await projects.first?.name == "One", try await threads.count == 61,
              WireFixture.authCalls == 1 else { throw CheckFailure.assertion }
        WireFixture.rejectProjects = 1
        guard try await client.projects().count == 1, WireFixture.authCalls == 2 else { throw CheckFailure.assertion }
        WireFixture.rejectProjects = 2
        do { _ = try await client.projects(); throw CheckFailure.assertion }
        catch BBClientError.http(401) { }
        guard WireFixture.authCalls == 3 else { throw CheckFailure.assertion }
        // Recover one transient read failure without replaying writes or TLS failures.
        for code: URLError.Code in [.networkConnectionLost, .timedOut] {
            let before = WireFixture.projectCalls
            WireFixture.projectFailures = [code]
            guard try await client.projects().count == 1, WireFixture.projectCalls == before + 2 else { throw CheckFailure.assertion }
        }
        for (failures, attempts) in [([URLError.Code.networkConnectionLost, .networkConnectionLost], 2), ([.secureConnectionFailed], 1), ([.cancelled], 1)] {
            let before = WireFixture.projectCalls
            WireFixture.projectFailures = failures
            do { _ = try await client.projects(); throw CheckFailure.assertion }
            catch let error as URLError { guard error.code == failures.last else { throw CheckFailure.assertion } }
            guard WireFixture.projectCalls == before + attempts else { throw CheckFailure.assertion }
        }
        let sendsBeforeCancellation = WireFixture.sends
        let cancelledSend = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await client.send(text: "Persisted brief", threadID: "thr_one")
        }
        do { _ = try await cancelledSend.value; throw CheckFailure.assertion }
        catch is CancellationError { }
        guard WireFixture.sends == sendsBeforeCancellation else { throw CheckFailure.assertion }
        let allThreads = try await client.threads()
        guard allThreads.count == 61, allThreads.first?.title == nil,
              allThreads[59].hasPendingInteraction == true,
              allThreads.last?.id == "thr_personal" else { throw CheckFailure.assertion }
        let messages = try await client.messages(threadID: "thr_one")
        guard messages.count == 1, messages.first?.text == "Real response" else { throw CheckFailure.assertion }
        let completed = try await client.timeline(threadID: "thr_completed")
        guard !completed.working, !completed.failed, completed.activity == nil else { throw CheckFailure.assertion }
        let running = try await client.timeline(threadID: "thr_running")
        guard running.working, !running.failed, running.activity == "Run tests" else { throw CheckFailure.assertion }
        let nextTurn = try await client.timeline(threadID: "thr_next_turn")
        guard nextTurn.working, nextTurn.activity == nil else { throw CheckFailure.assertion }
        let starting = try await client.timeline(threadID: "thr_starting")
        guard starting.working, starting.activity == nil else { throw CheckFailure.assertion }
        let interrupted = try await client.timeline(threadID: "thr_interrupted")
        guard !interrupted.working, !interrupted.failed else { throw CheckFailure.assertion }
        let errored = try await client.timeline(threadID: "thr_error")
        guard errored.failed, !errored.working, errored.activity == nil else { throw CheckFailure.assertion }
        let systemOnly = try await client.timeline(threadID: "thr_system")
        guard !systemOnly.working, !systemOnly.failed, systemOnly.activity == nil, systemOnly.messages.isEmpty else { throw CheckFailure.assertion }
        let mixed = try await client.timeline(threadID: "thr_mixed")
        guard mixed.messages.map(\.id) == ["c1", "c2", "c4"], mixed.messages.map(\.text) == ["First", "Second", "Third"],
              mixed.messages.map(\.role) == ["user", "assistant", "user"], !mixed.working else { throw CheckFailure.assertion }
        let latestPage = try await client.history(threadID: "thr_history")
        guard latestPage.messages.map(\.id) == ["overlap", "latest"], let cursor = latestPage.olderCursor else { throw CheckFailure.assertion }
        WireFixture.rejectHistory = true
        let olderPage = try await client.history(threadID: "thr_history", before: cursor)
        guard olderPage.messages.map(\.id) == ["old", "overlap"], olderPage.olderCursor == nil else { throw CheckFailure.assertion }
        do { _ = try await client.history(threadID: "thr_history", before: BBHistoryCursor(anchorSeq: 1, anchorId: "stale")); throw CheckFailure.assertion }
        catch BBClientError.http(400) { }
        let questions = try await client.questions(threads: [BBThread(id: "thr_one", title: nil, projectId: "proj_one")])
        guard questions.count == 2, questions[0].supported, !questions[1].supported else { throw CheckFailure.assertion }
        guard try await client.resolve(question: questions[0], optionID: "yes") == "interaction-one" else { throw CheckFailure.assertion }
        let receipt = try await client.send(text: "Persisted brief", threadID: "thr_one")
        guard receipt.delivery == "queued", receipt.threadID == "thr_one" else { throw CheckFailure.assertion }
        do { _ = try await client.send(text: "Persisted brief", threadID: "thr_one"); throw CheckFailure.assertion }
        catch BBClientError.acceptanceUnknown { }
        guard WireFixture.sends == 2 else { throw CheckFailure.assertion }
        print("PASS: concurrent auth coalesced, GET401 refreshed once, complete sidebar deduplicated, wire decode, timeline state (completed/running/error/system/mixed), uncertain send never retried")
    }
}
