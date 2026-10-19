import Foundation
import AVFAudio

/// Only this queue owns CaptureStore; bounded mailbox prevents unbounded audio copies.
final class CaptureWorker: @unchecked Sendable {
    enum Event: Sendable { case restored(UUID, CaptureLedger), began(UUID, CaptureAttempt), input(UUID, Float, Bool, UInt64?), saved(UUID, CaptureLedger), failed(UUID) }
    let queue = DispatchQueue(label: "voiceprobe.capture.writer", qos: .userInitiated)
    private var store: CaptureStore?
    private let root: URL
    private let mailbox = NSLock()
    private var pending = 0
    var event: (@Sendable (Event) -> Void)?
    init(root: URL) { self.root = root }
    func restore(request: UUID) {
        queue.async { [self] in
            do {
                if let store { try store.recover(interruptionReason: "input-or-write-failure") } else { store = try CaptureStore(root: root) }
                event?(.restored(request, store!.ledger))
            } catch { event?(.failed(request)) }
        }
    }
    func begin(request: UUID) {
        queue.async { [self] in
            do {
                guard let store else { throw ProbeError.blocked }
                try spaceCheck(); event?(.began(request, try store.begin()))
            } catch { event?(.failed(request)) }
        }
    }
    private func spaceCheck() throws {
        let attrs = try FileManager.default.attributesOfFileSystem(forPath: root.path)
        // Probe safety threshold only; G6 must measure the release reserve.
        guard (attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0 > 32 * 1024 * 1024 else { throw ProbeError.lowSpace }
    }
    func receive(_ buffer: AVAudioPCMBuffer, attempt: UUID, hostTime: UInt64?) {
        guard buffer.frameLength > 0, buffer.frameLength <= 65536,
              let samples = buffer.floatChannelData else { return }
        let channels = Int(buffer.format.channelCount), frames = Int(buffer.frameLength)
        guard channels > 0, channels <= 8 else { event?(.failed(attempt)); return }
        mailbox.lock()
        if pending >= 8 { mailbox.unlock(); event?(.failed(attempt)); return }
        pending += 1; mailbox.unlock()
        var values = [Float](repeating: 0, count: frames * channels)
        var peak: Float = 0
        for frame in 0..<frames {
            for channel in 0..<channels {
                let v = buffer.format.isInterleaved ? samples[0][frame * channels + channel] : samples[channel][frame]
                values[frame * channels + channel] = v; peak = max(peak, abs(v))
            }
        }
        let bytes = values.withUnsafeBytes { Data($0) }, rate = buffer.format.sampleRate, level = peak
        queue.async { [self] in
            defer { mailbox.lock(); pending -= 1; mailbox.unlock() }
            do {
                guard let store else { throw ProbeError.blocked }
                try spaceCheck()
                let first = try store.append(bytes, frames: frames, sampleRate: rate, channels: channels, attempt: attempt)
                event?(.input(attempt, level, first, hostTime))
            } catch { event?(.failed(attempt)) }
        }
    }
    func finish(_ attempt: UUID?, request: UUID, enqueue: Bool, reason: String? = nil) {
        queue.async { [self] in
            do {
                guard let store else { throw ProbeError.blocked }
                if let owner = attempt ?? store.ledger.attempt?.id { try store.stop(attempt: owner, reason: reason) }
                if enqueue { try store.enqueue() }
                event?(.saved(request, store.ledger))
            } catch { event?(.failed(request)) }
        }
    }
}
