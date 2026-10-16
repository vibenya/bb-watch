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
    @Published private(set) var sourceID: String?
    private var player: AVAudioPlayer?
    private let speech = AVSpeechSynthesizer()
    private var remaining: [URL] = []
    private var currentUtterance: AVSpeechUtterance?
    private var observers: [NSObjectProtocol] = []

    override init() {
        super.init()
        speech.delegate = self
        for name in [AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                if notification.name == AVAudioSession.routeChangeNotification {
                    guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                          AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
                } else {
                    guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                          AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
                }
                Task { @MainActor in self?.pause() }
            })
        }
    }

    func play(chunks: [AudioChunk], directory: URL) {
        stop()
        sourceID = directory.deletingLastPathComponent().lastPathComponent
        error = nil
        guard chunks.allSatisfy({ !$0.filename.isEmpty && !$0.filename.contains("/") && $0.filename != ".." && $0.filename != "." }) else {
            error = "Invalid recording file path."; return
        }
        remaining = chunks.map { directory.appendingPathComponent($0.filename) }
        do { try activate(); try playNext() }
        catch { fail(error) }
    }

    func speak(_ text: String) {
        stop(); error = nil
        sourceID = text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            try activate()
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = NLLanguageRecognizer.dominantLanguage(for: text)
                .flatMap { AVSpeechSynthesisVoice(language: $0.rawValue) }
            currentUtterance = utterance
            speech.speak(utterance)
            isPlaying = true
        } catch { fail(error) }
    }

    func pause() {
        player?.pause()
        if speech.isSpeaking { speech.pauseSpeaking(at: .immediate) }
        isPlaying = false; isPaused = player != nil || currentUtterance != nil
    }

    func resume() {
        guard isPaused else { return }
        do {
            try activate()
            if let player { isPlaying = player.play() }
            else if currentUtterance != nil { isPlaying = speech.continueSpeaking() }
            isPaused = !isPlaying
        } catch { fail(error) }
    }

    func stop() {
        player?.stop(); player = nil; remaining = []; sourceID = nil
        currentUtterance = nil
        speech.stopSpeaking(at: .immediate)
        isPlaying = false; isPaused = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func activate() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    private func playNext() throws {
        guard !remaining.isEmpty else { stop(); return }
        let next = remaining.removeFirst()
        let nextPlayer = try AVAudioPlayer(contentsOf: next)
        nextPlayer.delegate = self
        player = nextPlayer
        guard nextPlayer.play() else { throw PlaybackFailure.cannotPlay }
        isPlaying = true
    }

    private func fail(_ failure: Error) { stop(); error = failure.localizedDescription }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.player === player else { return }
            guard flag else { self.fail(PlaybackFailure.cannotPlay); return }
            do { try self.playNext() } catch { self.fail(error) }
        }
    }
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.player === player else { return }
            self.fail(error ?? PlaybackFailure.cannotPlay)
        }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.currentUtterance === utterance else { return }
            self.stop()
        }
    }
}

private enum PlaybackFailure: LocalizedError {
    case cannotPlay
    var errorDescription: String? { "Could not play the recording. The original is saved." }
}
