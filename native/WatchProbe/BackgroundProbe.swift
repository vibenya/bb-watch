import Foundation
import WatchKit
import OSLog

/// URLSession owns transfer execution. No foreground Task upload or lifecycle keep-alive.
final class BackgroundProbe: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    static let identifier = "app.getbb.voiceprobe.phase0.fixture-upload.v1"
    static let shared = BackgroundProbe()
    private let serial = OperationQueue()
    private var ledger: TransferLedger?
    private var reconciled = false
    private var failed = false
    private var refreshTasks: [WKURLSessionRefreshBackgroundTask] = []
    private var eventsFinished = false
    private var pendingReconciliations = 0
    private var session: URLSession!
    private struct Event: Codable {
        let stage: String
        let at: Date
        var taskID: Int? = nil
        var requestID: UUID? = nil
        var value: Int? = nil
        var hash: String? = nil
        var domain: String? = nil
    }
    private var events: [Event] = []
    private var eventFile: URL { URL.applicationSupportDirectory.appendingPathComponent("NativePhase0/transfer-events.json") }
    private var fixtureCommandHandled = false
    private var cancelFixtureTasks: Bool {
        #if targetEnvironment(simulator)
        ProcessInfo.processInfo.arguments.contains("--fixture-cancel")
        #else
        false
        #endif
    }
    private func record(_ event: Event) {
        events.append(event)
        do { try DurableFile.save(events, to: eventFile) }
        catch { trace.error("fixture-event-write-failed") }
    }
    private let trace = Logger(subsystem: "app.getbb.voiceprobe.phase0", category: "transport")
    private override init() {
        super.init()
        serial.maxConcurrentOperationCount = 1; serial.name = "voiceprobe.transport.ledger"
        let config = URLSessionConfiguration.background(withIdentifier: Self.identifier)
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600 // Fixture observation window, not delivery promise.
        session = URLSession(configuration: config, delegate: self, delegateQueue: serial)
        serial.addOperation { [self] in
            do {
                ledger = try TransferLedger(root: URL.applicationSupportDirectory.appendingPathComponent("NativePhase0/Transfers"))
                if FileManager.default.fileExists(atPath: eventFile.path) {
                    events = try JSONDecoder().decode([Event].self, from: Data(contentsOf: eventFile))
                }
                record(Event(stage: "session-created", at: Date()))
                reconcile()
            } catch { failed = true }
        }
    }
    private func reconcile() {
        reconciled = false
        pendingReconciliations += 1
        session.getAllTasks { [self] tasks in
            serial.addOperation { [self] in
                defer { pendingReconciliations -= 1; completeRefresh() }
                do {
                    guard let ledger else { throw ProbeError.blocked }
                    let snapshots = tasks.map { TaskSnapshot(taskID: $0.taskIdentifier, description: $0.taskDescription, endpoint: $0.originalRequest?.url, method: $0.originalRequest?.httpMethod) }
                    record(Event(stage: "getAllTasks", at: Date(), value: tasks.count))
                    let orphans = try ledger.reconcile(snapshots)
                    for task in tasks where orphans.contains(task.taskIdentifier) { task.cancel() }
                    // Adopt only the same durable planned task, including pre-resume crash.
                    for task in tasks where !orphans.contains(task.taskIdentifier) {
                        if cancelFixtureTasks { task.cancel(); record(Event(stage: "fixture-cancel", at: Date(), taskID: task.taskIdentifier)) }
                        else if task.state == .suspended { task.resume(); record(Event(stage: "same-task-resumed", at: Date(), taskID: task.taskIdentifier)) }
                    }
                    reconciled = true
                    handleFixtureCommand()
                } catch { failed = true }
            }
        }
    }
    /// Explicit lab action only. No endpoint is shipped; no connection to real audio.
    func uploadSyntheticFixture(to endpoint: URL, requestID: UUID = UUID()) {
        serial.addOperation { [self] in
            do {
                guard reconciled, !failed, let ledger,
                      endpoint.scheme == "http", ["127.0.0.1", "localhost", "::1"].contains(endpoint.host ?? ""),
                      endpoint.user == nil, endpoint.password == nil, endpoint.query == nil else { throw ProbeError.invalid }
                if ledger.records.contains(where: { $0.id == requestID }) {
                    record(Event(stage: "existing-invocation-no-new-task", at: Date(), requestID: requestID)); return
                }
                let record = try ledger.plan(body: Data("voiceprobe-synthetic-fixture-v1".utf8), endpoint: endpoint, method: "PUT", requestID: requestID)
                var request = URLRequest(url: endpoint)
                request.httpMethod = record.method
                request.setValue(record.id.uuidString, forHTTPHeaderField: "X-Probe-ID")
                request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                let task = session.uploadTask(with: request, fromFile: ledger.root.appendingPathComponent(record.filename))
                task.taskDescription = record.id.uuidString
                do { try ledger.attach(record.id, taskID: task.taskIdentifier) }
                catch { task.cancel(); throw error }
                self.record(Event(stage: "task-created-attached", at: Date(), taskID: task.taskIdentifier, requestID: record.id, value: Data("voiceprobe-synthetic-fixture-v1".utf8).count, hash: record.sha256))
                eventsFinished = false; task.resume()
                self.record(Event(stage: "task-resumed", at: Date(), taskID: task.taskIdentifier, requestID: record.id))
            } catch { failed = true }
        }
    }
    private func handleFixtureCommand() {
        #if targetEnvironment(simulator)
        guard !fixtureCommandHandled else { return }
        fixtureCommandHandled = true
        let args = ProcessInfo.processInfo.arguments
        guard !cancelFixtureTasks, let i = args.firstIndex(of: "--fixture-upload"), i + 2 < args.count,
              let url = URL(string: args[i + 1]), let request = UUID(uuidString: args[i + 2]) else { return }
        uploadSyntheticFixture(to: url, requestID: request)
        #endif
    }
    func handle(_ task: WKURLSessionRefreshBackgroundTask) {
        serial.addOperation { [self] in
            guard task.sessionIdentifier == Self.identifier else { task.setTaskCompletedWithSnapshot(false); return }
            record(Event(stage: "watchkit-refresh-delivered", at: Date()))
            refreshTasks.append(task)
            if eventsFinished { completeRefresh() }
            else { reconcile() }
        }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        record(Event(stage: "delegate-complete", at: Date(), taskID: task.taskIdentifier, value: (task.response as? HTTPURLResponse)?.statusCode, domain: (error as NSError?)?.domain))
        if let error { record(Event(stage: "delegate-error", at: Date(), taskID: task.taskIdentifier, value: (error as NSError).code, domain: (error as NSError).domain)) }
        do { guard let ledger else { throw ProbeError.blocked }; try ledger.observe(taskID: task.taskIdentifier, status: (task.response as? HTTPURLResponse)?.statusCode, errorCode: (error as NSError?)?.code); record(Event(stage: "observation-durable", at: Date(), taskID: task.taskIdentifier)) }
        catch { failed = true }
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        record(Event(stage: "delegate-response-bytes", at: Date(), taskID: dataTask.taskIdentifier, value: data.count, hash: TransferLedger.hash(data)))
        // No receipt parser yet. Response bytes are intentionally not interpreted or logged.
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        record(Event(stage: "delegate-finished-events", at: Date()))
        eventsFinished = true; completeRefresh()
    }
    private func completeRefresh() {
        guard eventsFinished, pendingReconciliations == 0, !refreshTasks.isEmpty else { return }
        // One drained readback/retry before releasing the OS budget. The durable task
        // plan remains uncertain if observation persistence still fails; never replay.
        if let ledger, ledger.hasUnpersistedObservations {
            do { try ledger.recoverObservations() }
            catch { failed = true }
        }
        if ledger == nil || ledger?.hasUnpersistedObservations == true {
            record(Event(stage: "refresh-unresolved", at: Date()))
            trace.error("refresh-completed-with-unresolved-observation; retained-task-needs-reconciliation")
        } else { trace.notice("refresh-observations-durable") }
        for task in refreshTasks { task.setTaskCompletedWithSnapshot(false) }
        record(Event(stage: "watchkit-refresh-completed", at: Date(), value: refreshTasks.count))
        refreshTasks.removeAll(); eventsFinished = false
    }
}
final class ProbeApplicationDelegate: NSObject, WKApplicationDelegate {
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            if let transfer = task as? WKURLSessionRefreshBackgroundTask { BackgroundProbe.shared.handle(transfer) }
            else { task.setTaskCompletedWithSnapshot(false) }
        }
    }
}
