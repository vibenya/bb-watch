import AVFoundation
import Foundation

/// Exercises the real watch player with synthetic CAFs. This does not prove hardware audibility.
@main
@MainActor
struct AudioPlaybackCheck {
    enum Failure: Error { case failed(String) }

    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw Failure.failed(message) }
    }
    static func wait(_ message: String, timeout: TimeInterval = 4, until condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline { throw Failure.failed(message) }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
    static func settle() async throws { try await Task.sleep(for: .milliseconds(100)) }

    static func tone(_ name: String, seconds: Double, directory: URL) throws -> AudioChunk {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
        let frames = AVAudioFrameCount(seconds * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: max(frames, 1))!
        buffer.frameLength = frames
        for frame in 0..<Int(frames) {
            buffer.floatChannelData![0][frame] = Float(sin(Double(frame) * 2 * .pi * 440 / format.sampleRate) * 0.005)
        }
        let file = try AVAudioFile(forWriting: directory.appendingPathComponent(name), settings: format.settings)
        try file.write(from: buffer)
        return AudioChunk(filename: name, duration: seconds)
    }

    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bb-playback-\(UUID().uuidString)")
        let store = try DurableStore(directory: root)
        let id = UUID()
        let directory = try store.chunksDirectory(for: id)
        defer { try? FileManager.default.removeItem(at: root) }
        let playback = WatchPlayback()
        defer { playback.stop() }
        let first = try tone("z-first.caf", seconds: 0.45, directory: directory)
        let second = try tone("a-second.caf", seconds: 0.2, directory: directory)
        let long = try tone("long.caf", seconds: 1.2, directory: directory)
        let zeroFrames = try tone("zero-frames.caf", seconds: 0, directory: directory)
        let corrupt = AudioChunk(filename: "a-corrupt.caf", duration: 1)
        try Data("Not an audio file".utf8).write(to: directory.appendingPathComponent(corrupt.filename))
        let empty = AudioChunk(filename: "empty.caf", duration: 1)
        try Data().write(to: directory.appendingPathComponent(empty.filename))
        let originals = try Dictionary(uniqueKeysWithValues: FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).map { ($0, try Data(contentsOf: $0)) })

        playback.play(chunks: [], directory: directory)
        try require(playback.error != nil, "Empty recordings must report an error instead of silently completing")
        try require(playback.sourceID == id.uuidString && !playback.isPlaying && !playback.isPaused, "Error must identify the failed recording and remain stopped")
        playback.play(chunks: [AudioChunk(filename: "../outside.caf", duration: 1)], directory: directory)
        try require(playback.error != nil && !playback.isPreparing, "Invalid paths must be rejected before activating playback")
        print("PASS: empty/path failures are visible and scoped to the recording")

        for chunk in [empty, zeroFrames, corrupt, AudioChunk(filename: "missing.caf", duration: 1)] {
            playback.play(chunks: [chunk], directory: directory)
            try await wait("Unreadable part was not rejected") { playback.error != nil }
            try require(!playback.isPlaying && !playback.isPaused && !playback.isPreparing, "Unreadable part left active playback")
            try require(playback.sourceID == id.uuidString, "Failure lost its recording identity")
            try require(!playback.error!.contains(root.path), "Player error exposed a local recording path")
        }
        print("PASS: empty, zero-frame, corrupt and missing CAFs fail without exposing paths")

        let orderedStart = Date()
        playback.play(chunks: [first, corrupt], directory: directory)
        try await wait("First ordered part did not start") { playback.isPlaying || playback.error != nil }
        try require(playback.isPlaying && playback.error == nil, "A later corrupt part prevented the earlier part from playing")
        try await wait("Later corrupt part was skipped") { playback.error != nil }
        try require(Date().timeIntervalSince(orderedStart) >= 0.4, "Playback reordered metadata by filename or skipped the first part")
        print("PASS: metadata order is honored before a later-part failure")

        playback.play(chunks: [first, second], directory: directory)
        try await wait("Multi-part audio did not start") { playback.isPlaying || playback.error != nil }
        try require(playback.isPlaying, "Multi-part audio failed to start")
        let started = Date()
        try await wait("Multi-part audio did not finish") { playback.sourceID == nil || playback.error != nil }
        try require(playback.error == nil && !playback.isPlaying && !playback.isPaused, "End of queue was not clean")
        try require(Date().timeIntervalSince(started) >= 0.55, "Multi-part playback skipped a part")
        print("PASS: real two-part player completion clears active state")

        playback.play(chunks: [long, second], directory: directory)
        try await wait("Pause fixture did not start") { playback.isPlaying || playback.error != nil }
        try require(playback.isPlaying, "Pause fixture failed")
        try await Task.sleep(for: .milliseconds(400))
        playback.pause()
        try require(playback.isPaused && !playback.isPlaying && playback.sourceID == id.uuidString, "Pause lost its source or state")
        try await Task.sleep(for: .milliseconds(1500))
        try require(playback.isPaused && !playback.isPlaying, "Paused playback advanced or completed")
        let resumed = Date()
        playback.resume()
        try await wait("Resume did not finish") { playback.sourceID == nil || playback.error != nil }
        let resumedDuration = Date().timeIntervalSince(resumed)
        try require(playback.error == nil && resumedDuration > 0.85 && resumedDuration < 1.3, "Resume skipped remaining audio or restarted the original: \(resumedDuration)")
        print("PASS: pause holds across duration; resume continues current part and queue")

        playback.play(chunks: [long], directory: directory)
        playback.pause() // Pause while route authorization is still queued.
        try await settle()
        try require(playback.isPaused && !playback.isPlaying && !playback.isPreparing, "Late activation escaped Pause")
        playback.resume()
        try await wait("Pending-activation resume did not start") { playback.isPlaying || playback.error != nil }
        try require(playback.isPlaying, "Pending-activation resume failed")
        let unrelated = try AVAudioPlayer(contentsOf: directory.appendingPathComponent(first.filename))
        playback.audioPlayerDidFinishPlaying(unrelated, successfully: false)
        playback.audioPlayerDecodeErrorDidOccur(unrelated, error: Failure.failed("synthetic"))
        playback.speechSynthesizer(AVSpeechSynthesizer(), didFinish: AVSpeechUtterance(string: "synthetic"))
        try await settle()
        try require(playback.isPlaying && playback.error == nil, "Stale/unrelated delegate changed current playback")
        print("PASS: pending activation respects Pause; unrelated delegates cannot stop a current source")

        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        try require(playback.isPaused && !playback.isPlaying, "Interruption did not pause synchronously")
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue])
        try await settle()
        try require(playback.isPaused, "Interruption end resumed without user intent")
        for reason in [AVAudioSession.RouteChangeReason.oldDeviceUnavailable, .noSuitableRouteForCategory] {
            playback.resume()
            try await wait("Route fixture did not resume") { playback.isPlaying || playback.error != nil }
            try require(playback.isPlaying, "Route fixture failed")
            NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification, object: nil,
                userInfo: [AVAudioSessionRouteChangeReasonKey: reason.rawValue])
            try require(playback.isPaused && !playback.isPlaying, "Losing the output route did not pause")
        }
        playback.stop()
        playback.play(chunks: [long], directory: directory)
        playback.stop()
        try await settle()
        try require(playback.sourceID == nil && !playback.isPlaying && !playback.isPreparing, "Late activation escaped Stop")
        print("PASS: interruptions/output loss pause without auto-resume; Stop invalidates activation")

        playback.speak("Playback check.", sourceID: "response-id")
        try require(playback.sourceID == "response-id", "Speech uses text instead of the view's stable message ID")
        playback.stop() // No synthesized speech is needed to verify the identity contract.
        try AVAudioSession.sharedInstance().setCategory(.record)
        playback.canPlay = { false }
        playback.play(chunks: [first], directory: directory)
        playback.speak("Playback check.", sourceID: "another-response")
        playback.resume()
        try require(playback.error != nil && !playback.isPreparing && !playback.isPlaying, "Capture gate allowed playback")
        try require(AVAudioSession.sharedInstance().category == .record, "Playback reconfigured the capture session")
        playback.stop()
        playback.canPlay = { true }
        print("PASS: speech identity matches controls; live/pending capture blocks session changes")

        for (url, original) in originals {
            let current = try Data(contentsOf: url)
            try require(current == original, "Playback changed an original part")
        }
        print("PASS: every synthetic original remains byte-for-byte unchanged")
        print("Playback check passed. Hardware speaker/headphone audibility is not covered.")
    }
}
