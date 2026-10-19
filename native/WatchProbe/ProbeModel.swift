import SwiftUI
import AVFAudio
import WatchKit
import Observation
import Accessibility
import OSLog

@MainActor @Observable final class ProbeModel {
    static let shared = ProbeModel()
    enum State: Equatable { case restoring, ready, starting, live, stopping, finalizing, stopped, blocked }
    var state: State = .restoring
    var levels: [Float] = []
    var issue: String?
    private(set) var ledger: CaptureLedger?
    private var engine: AVAudioEngine?
    private var attempt: UUID?
    private var generation = UUID()
    private var appending = false
    private var lastInput = Date()
    private var watchdog: Timer?
    private var transientStarted = Date()
    private var pendingQuickStart = false
    private var quickStartAt = Date.distantPast
    private var authorizedStart: UUID?
    private var active = false
    private var activationPending = false
    private var permissionPending = false
    private var deferredFinish: (enqueue: Bool, reason: String?)?
    private let trace = Logger(subsystem: "app.getbb.voiceprobe.phase0", category: "capture")
    private let worker: CaptureWorker
    private var interruption: NSObjectProtocol?
    private init() {
        let root = URL.applicationSupportDirectory.appendingPathComponent("NativePhase0/Capture", isDirectory: true)
        worker = CaptureWorker(root: root)
        worker.event = { event in DispatchQueue.main.async { ProbeModel.shared.receive(event) } }
        interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in
                let model = ProbeModel.shared
                if model.state == .live || model.state == .starting { model.finish(enqueue: false, reason: "audio-interruption") }
            }
        }
        worker.restore(request: generation)
        watchdog = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in ProbeModel.shared.checkBounds() }
        }
    }
    private func transition(_ state: State) { self.state = state; transientStarted = Date(); trace.notice("state=\(String(describing: state), privacy: .public)") }
    func scene(_ phase: ScenePhase) {
        active = phase == .active
        // Inactive/wrist-down is not a user Stop. Only pending activation is canceled
        // when the app actually enters background; established capture remains a G3 probe.
        if phase == .background && state == .starting { finish(enqueue: false) }
        if active { beginAuthorized() }
        if active && pendingQuickStart && (state == .ready || state == .stopped) {
            pendingQuickStart = false; if Date().timeIntervalSince(quickStartAt) < 8 { start() }
        }
    }
    func quickStart() {
        guard ![.blocked, .starting, .live, .stopping, .finalizing].contains(state) else { return }
        quickStartAt = Date()
        if state == .restoring || !active { pendingQuickStart = true; return }
        start()
    }
    func retry() {
        guard state == .blocked, !activationPending else { return }
        // This is queued behind all old writes. No editable state before its readback.
        stopEngine(); generation = UUID(); attempt = nil
        transition(.restoring); worker.restore(request: generation)
    }
    func start() {
        guard active, !permissionPending, state == .ready || state == .stopped else { return }
        appending = state == .stopped
        let token = UUID(); generation = token
        transition(.starting)
        permissionPending = true
        Task {
            let allowed = await AVAudioApplication.requestRecordPermission()
            permissionPending = false
            guard generation == token, state == .starting else { return }
            transientStarted = Date()
            guard allowed else { issue = "Microphone permission required"; transition(appending ? .stopped : .ready); return }
            authorizedStart = token; beginAuthorized()
        }
    }
    private func beginAuthorized() {
        guard active, state == .starting, let token = authorizedStart, token == generation else { return }
        authorizedStart = nil; transientStarted = Date(); worker.begin(request: token)
    }
    private func activate(_ owner: UUID) {
        let token = generation
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default, options: [])
            activationPending = true
            session.activate(options: []) { [weak self] ok, _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.activationPending = false
                    guard self.generation == token, self.state == .starting, self.attempt == owner else {
                        self.stopEngine()
                        if let deferred = self.deferredFinish {
                            self.deferredFinish = nil
                            self.worker.finish(self.attempt, request: self.generation, enqueue: deferred.enqueue, reason: deferred.reason)
                        }
                        return
                    }
                    guard ok else { self.finish(enqueue: false, reason: "activation-failed"); return }
                    do {
                        let engine = AVAudioEngine(), input = engine.inputNode
                        let format = input.outputFormat(forBus: 0)
                        guard format.sampleRate > 0, format.channelCount > 0, format.commonFormat == .pcmFormatFloat32 else { throw ProbeError.invalid }
                        let worker = self.worker
                        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, when in worker.receive(buffer, attempt: owner, hostTime: when.isHostTimeValid ? when.hostTime : nil) }
                        self.engine = engine
                        try engine.start()
                    } catch { self.finish(enqueue: false, reason: "activation-failed") }
                }
            }
        } catch { finish(enqueue: false, reason: "activation-failed") }
    }
    private func stopEngine() {
        if let engine { engine.stop(); engine.inputNode.removeTap(onBus: 0) }
        engine = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    func finish(enqueue: Bool, reason: String? = nil) {
        guard state == .live || state == .stopped || state == .starting else { return }
        if enqueue && state == .starting { return }
        generation = UUID(); authorizedStart = nil; stopEngine()
        transition(enqueue ? .finalizing : .stopping)
        if activationPending { deferredFinish = (enqueue, reason) }
        else { worker.finish(attempt, request: generation, enqueue: enqueue, reason: reason) }
    }
    private func receive(_ event: CaptureWorker.Event) {
        switch event {
        case .restored(let request, let ledger):
            guard request == generation, state == .restoring else { return }
            self.ledger = ledger; attempt = nil; levels = ledger.currentDraft?.preview ?? []
            if let id = ledger.currentDraft?.id, ledger.damaged.contains(id) { issue = "Saved audio needs recovery"; transition(.blocked); return }
            transition(ledger.currentDraft == nil ? .ready : .stopped)
            if pendingQuickStart && active { pendingQuickStart = false; if Date().timeIntervalSince(quickStartAt) < 8 { start() } }
        case .began(let request, let owner):
            guard request == generation, state == .starting else { worker.finish(owner.id, request: UUID(), enqueue: false); return }
            attempt = owner.id; activate(owner.id)
        case .input(let id, let level, let first, let hostTime):
            guard attempt == id, state == .starting || state == .live else { return }
            lastInput = Date()
            if first && state == .starting {
                trace.notice("first-buffer-host-time=\(hostTime ?? 0, privacy: .public); first-buffer-durable")
                transition(.live)
                WKInterfaceDevice.current().play(appending ? .retry : .start)
                AccessibilityNotification.Announcement(appending ? "Continuing recording" : "Recording").post()
            }
            if state == .live { levels.append(level); levels = Array(levels.suffix(32)) }
        case .saved(let request, let ledger):
            guard request == generation, state == .stopping || state == .finalizing else { return }
            let queued = state == .finalizing
            self.ledger = ledger; attempt = nil; levels = ledger.currentDraft?.preview ?? []
            transition(ledger.currentDraft == nil ? .ready : .stopped)
            if queued { levels = []; WKInterfaceDevice.current().play(.click) }
            else { WKInterfaceDevice.current().play(.stop) }
        case .failed(let request):
            guard request == generation || request == attempt else { return }
            stopEngine(); generation = UUID(); pendingQuickStart = false
            issue = "Saved audio preserved. Retry local recovery."
            transition(.blocked)
        }
    }
    private func checkBounds() {
        // Provisional safety bounds, not measured release G6 values.
        if state == .starting && !permissionPending && Date().timeIntervalSince(transientStarted) > 8 { finish(enqueue: false, reason: "no-input") }
        if state == .live && Date().timeIntervalSince(lastInput) > 3 { finish(enqueue: false, reason: "input-stall") }
        if [.restoring, .stopping, .finalizing].contains(state) && Date().timeIntervalSince(transientStarted) > 10 {
            stopEngine(); pendingQuickStart = false; issue = "Local writer unresolved. Retry after drain."; transition(.blocked)
        }
    }
}
