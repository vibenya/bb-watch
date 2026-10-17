import Foundation

/// Local URLSession boundary, never reaches a provider or dispatches a BB prompt.
final class TranscriptionWireFixture: URLProtocol, @unchecked Sendable {
    static let lock = NSLock()
    nonisolated(unsafe) static var calls = 0
    nonisolated(unsafe) static var bytes = 0
    nonisolated(unsafe) static var failCall: Int?
    nonisolated(unsafe) static var unauthorizedRemaining = 0
    nonisolated(unsafe) static var authCalls = 0
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "asr-fixture.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    static func reset(failCall: Int? = nil, unauthorized: Int = 0) {
        lock.lock(); defer { lock.unlock() }
        calls = 0; bytes = 0; self.failCall = failCall; unauthorizedRemaining = unauthorized; authCalls = 0
    }
    static func snapshot() -> (calls: Int, bytes: Int, authCalls: Int) {
        lock.lock(); defer { lock.unlock() }; return (calls, bytes, authCalls)
    }
    override func startLoading() {
        Self.lock.lock(); defer { Self.lock.unlock() }
        do {
            let data: Data
            var status = 200
            if request.url!.path == "/api/connect/desktop-session" {
                Self.authCalls += 1
                data = try JSONSerialization.data(withJSONObject: ["cookie": ["domain": "asr-fixture.invalid", "expiresAt": Date().addingTimeInterval(600).timeIntervalSince1970 * 1000, "name": "fixture-session", "value": "fixture-cookie"]])
            } else {
                guard request.url!.path == "/api/v1/system/voice-transcription", request.httpMethod == "POST",
                      request.value(forHTTPHeaderField: "Cookie")?.contains("fixture-session=fixture-cookie") == true else { throw Failure.invalidRequest }
                var body = request.httpBody ?? Data()
                if let stream = request.httpBodyStream {
                    stream.open(); defer { stream.close() }
                    var buffer = [UInt8](repeating: 0, count: 8192)
                    while stream.hasBytesAvailable {
                        let count = stream.read(&buffer, maxLength: buffer.count)
                        if count < 0 { throw Failure.invalidRequest }
                        if count == 0 { break }
                        body.append(buffer, count: count)
                    }
                }
                let header = String(decoding: body.prefix(240), as: UTF8.self)
                guard header.contains("filename=\"recording.wav\""), header.contains("Content-Type: audio/wav\r\n"),
                      request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=") == true,
                      body.count > 150 else { throw Failure.invalidMultipart }
                Self.calls += 1; Self.bytes = body.count
                if Self.failCall == Self.calls { status = 503 }
                if Self.unauthorizedRemaining > 0 { Self.unauthorizedRemaining -= 1; status = 401 }
                data = try JSONSerialization.data(withJSONObject: ["text": "segment-\(Self.calls)"])
            }
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    static func client() -> BBClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TranscriptionWireFixture.self]
        return BBClient(serverURL: URL(string: "https://asr-fixture.invalid")!, credential: "fixture-only", session: URLSession(configuration: config))
    }
    enum Failure: Error { case invalidRequest, invalidMultipart }
}
