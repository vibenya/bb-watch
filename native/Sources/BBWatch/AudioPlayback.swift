import AVFoundation
import Combine
import Foundation
import NaturalLanguage

/// Plays original CAF chunks in metadata order, or reads an agent response aloud.
@MainActor
final class WatchPlayback: NSObject, ObservableObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var error: String?
    @Published private(set) var isPaused = false
    @Published private(set) var isPreparing = false
    @Published private(set) var sourceID: String?
    /// The capture owner also blocks playback while microphone startup is pending.
    var canPlay: () -> Bool = { true }
    private var player: AVAudioPlayer?
    private let speech = AVSpeechSynthesizer()
    private var remaining: [URL] = []
    private var currentUtterance: AVSpeechUtterance?
    private var speechStarted = false
    private var activationID: UUID?
    private var ownsSession = false
    private var observers: [NSObjectProtocol] = []

    override init() {
        super.init()
        speech.delegate = self
        for name in [AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                if notification.name == AVAudioSession.routeChangeNotification {
                    guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                          let reason = AVAudioSession.RouteChangeReason(rawValue: raw),
                          reason == .oldDeviceUnavailable || reason == .noSuitableRouteForCategory else { return }
                } else {
                    guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                          AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
                }
                // Handle on the observer's main queue, before a new source can replace this one.
                MainActor.assumeIsolated { self?.pause() }
            })
        }
    }

    func play(chunks: [AudioChunk], directory: URL) {
        guard canPlay() else { error = PlaybackFailure.captureActive.localizedDescription; return }
        stop()
        sourceID = directory.deletingLastPathComponent().lastPathComponent
        error = nil
        guard !chunks.isEmpty else { fail(.empty); return }
        guard chunks.allSatisfy({ !$0.filename.isEmpty && !$0.filename.contains("/") && !$0.filename.contains("\0") && $0.filename != ".." && $0.filename != "." }) else {
            fail(.invalidPath); return
        }
        remaining = chunks.map { directory.appendingPathComponent($0.filename) }
        activateAndStart()
    }

    func speak(_ text: String, sourceID: String) {
        guard canPlay() else { error = PlaybackFailure.captureActive.localizedDescription; return }
        stop(); error = nil
        self.sourceID = sourceID
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { fail(.empty); return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = NLLanguageRecognizer.dominantLanguage(for: text)
            .flatMap { AVSpeechSynthesisVoice(language: $0.rawValue) }
        currentUtterance = utterance
        activateAndStart()
    }

    func pause() {
        guard isPlaying || isPreparing else { return }
        activationID = nil; isPreparing = false
        player?.pause()
        if speech.isSpeaking { speech.pauseSpeaking(at: .immediate) }
        isPlaying = false; isPaused = sourceID != nil
    }

    func resume() {
        guard isPaused, !isPreparing else { return }
        guard canPlay() else { error = PlaybackFailure.captureActive.localizedDescription; return }
        error = nil
        activateAndStart()
    }

    func stop() {
        activationID = nil; isPreparing = false
        player?.delegate = nil
        player?.stop(); player = nil; remaining = []; sourceID = nil
        currentUtterance = nil; speechStarted = false
        speech.stopSpeaking(at: .immediate)
        isPlaying = false; isPaused = false
        // An idle playback control must never deactivate the recorder's shared session.
        if ownsSession {
            ownsSession = false
            if canPlay() {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
        }
    }

    private func activateAndStart() {
        let session = AVAudioSession.sharedInstance()
        let id = UUID()
        activationID = id; isPreparing = true
        do {
            // Foreground voice playback uses normal system routing (speaker or headphones).
            try session.setCategory(.playback, mode: .default, policy: .default)
            ownsSession = true
            // watchOS authorizes the route asynchronously; setActive alone is insufficient.
            session.activate(options: []) { [weak self] success, _ in
                Task { @MainActor in
                    guard let self, self.activationID == id else { return }
                    self.activationID = nil; self.isPreparing = false
                    guard self.canPlay() else { self.fail(.captureActive); return }
                    guard success else { self.fail(.routeUnavailable); return }
                    do {
                        if let player = self.player {
                            guard player.play() else { throw PlaybackFailure.cannotPlay }
                            self.isPlaying = true
                        } else if let utterance = self.currentUtterance {
                            if self.speechStarted {
                                guard self.speech.continueSpeaking() else { throw PlaybackFailure.cannotPlay }
                            } else {
                                self.speech.speak(utterance)
                                self.speechStarted = true
                            }
                            self.isPlaying = true
                        } else {
                            try self.playNext()
                        }
                        self.isPaused = false
                    } catch { self.fail(.cannotPlay) }
                }
            }
        } catch { fail(.routeUnavailable) }
    }

    private func playNext() throws {
        guard !remaining.isEmpty else { stop(); return }
        let next = remaining.removeFirst()
        // Opening/preparing the real file rejects missing, empty and corrupt CAFs.
        let nextPlayer = try AVAudioPlayer(contentsOf: next)
        guard nextPlayer.duration.isFinite, nextPlayer.duration > 0, nextPlayer.prepareToPlay() else {
            throw PlaybackFailure.cannotPlay
        }
        nextPlayer.delegate = self
        player = nextPlayer
        guard nextPlayer.play() else { throw PlaybackFailure.cannotPlay }
        isPlaying = true
    }

    private func fail(_ failure: PlaybackFailure) {
        let failedSource = sourceID
        stop()
        sourceID = failedSource
        error = failure.localizedDescription
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let id = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            guard let self, self.player.map(ObjectIdentifier.init) == id else { return }
            guard flag else { self.fail(.cannotPlay); return }
            // A completion already queued at Pause must not restart the next chunk.
            guard !self.isPaused else { self.player = nil; return }
            do { try self.playNext() } catch { self.fail(.cannotPlay) }
        }
    }
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let id = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            guard let self, self.player.map(ObjectIdentifier.init) == id else { return }
            self.fail(.cannotPlay)
        }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self, self.currentUtterance.map(ObjectIdentifier.init) == id else { return }
            self.stop()
        }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self, self.currentUtterance.map(ObjectIdentifier.init) == id else { return }
            self.stop()
        }
    }
}

private enum PlaybackFailure: LocalizedError {
    case empty, invalidPath, captureActive, routeUnavailable, cannotPlay
    var errorDescription: String? {
        switch self {
        case .empty: return "No audio to play. The original is saved."
        case .invalidPath: return "Invalid recording file path. The original is saved."
        case .captureActive: return "Pause recording before listening."
        case .routeUnavailable: return "Audio output unavailable. Try again. The original is saved."
        case .cannotPlay: return "Could not play the recording. A part may be missing or damaged. The original is saved."
        }
    }
}
