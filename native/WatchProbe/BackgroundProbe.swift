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
                    let orphans = try ledger.reconcile(snapshots)
                    for task in tasks where orphans.contains(task.taskIdentifier) { task.cancel() }
                    // Adopt only the same durable planned task, including pre-resume crash.
                    for task in tasks where !orphans.contains(task.taskIdentifier) && task.state == .suspended { task.resume() }
                    reconciled = true
                } catch { failed = true }
            }
        }
    }
    /// Explicit lab action only. No endpoint is shipped; no connection to real audio.
    func uploadSyntheticFixture(to endpoint: URL) {
        serial.addOperation { [self] in
            do {
                guard reconciled, !failed, let ledger,
                      endpoint.scheme == "http", ["127.0.0.1", "localhost", "::1"].contains(endpoint.host ?? ""),
                      endpoint.user == nil, endpoint.password == nil, endpoint.query == nil else { throw ProbeError.invalid }
                let record = try ledger.plan(body: Data("voiceprobe-synthetic-fixture-v1".utf8), endpoint: endpoint, method: "PUT")
                var request = URLRequest(url: endpoint)
                request.httpMethod = record.method
                request.setValue(record.id.uuidString, forHTTPHeaderField: "X-Probe-ID")
                request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                let task = session.uploadTask(with: request, fromFile: ledger.root.appendingPathComponent(record.filename))
                task.taskDescription = record.id.uuidString
                do { try ledger.attach(record.id, taskID: task.taskIdentifier) }
                catch { task.cancel(); throw error }
                eventsFinished = false; task.resume()
            } catch { failed = true }
        }
    }
    func handle(_ task: WKURLSessionRefreshBackgroundTask) {
        serial.addOperation { [self] in
            guard task.sessionIdentifier == Self.identifier else { task.setTaskCompletedWithSnapshot(false); return }
            refreshTasks.append(task)
            if eventsFinished { completeRefresh() }
            else { reconcile() }
        }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        do { guard let ledger else { throw ProbeError.blocked }; try ledger.observe(taskID: task.taskIdentifier, status: (task.response as? HTTPURLResponse)?.statusCode, errorCode: (error as NSError?)?.code) }
        catch { failed = true }
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // No receipt parser yet. Response bytes are intentionally not interpreted or logged.
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
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
            trace.error("refresh-completed-with-unresolved-observation; retained-task-needs-reconciliation")
        } else { trace.notice("refresh-observations-durable") }
        for task in refreshTasks { task.setTaskCompletedWithSnapshot(false) }
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
