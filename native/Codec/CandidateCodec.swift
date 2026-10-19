import Foundation
import AVFoundation
#if canImport(AudioToolbox)
import AudioToolbox
#endif
import CryptoKit
#if canImport(ProbeCore)
import ProbeCore
#endif

public enum PCMSampleFormat: String, Codable, Sendable { case float32, int16 }
public struct SourcePCM: Codable, Sendable {
    public let sampleFormat: PCMSampleFormat
    public let endian: String
    public let interleaved: Bool
    public let sampleRate: Double
    public let channels: Int
    public let frames: Int
    public var sampleWidth: Int { sampleFormat == .float32 ? 4 : 2 }
    public init(sampleFormat: PCMSampleFormat, interleaved: Bool, sampleRate: Double, channels: Int, frames: Int) {
        self.sampleFormat = sampleFormat; self.endian = "little"; self.interleaved = interleaved
        self.sampleRate = sampleRate; self.channels = channels; self.frames = frames
    }
}
public struct PacketTimeline: Codable, Sendable {
    public let validFrames: Int64
    public let primingFrames: Int32
    public let remainderFrames: Int32
    public let packets: UInt64?
    public let framesPerPacket: UInt32
}
public struct CodecMeasurement: Codable, Sendable {
    public let source: SourcePCM
    public let sourceBytes: Int
    public let sourceSHA256: String
    public let encodedFile: String
    public let encodedBytes: Int
    public let encodedSHA256: String
    public let encodedFormatID: UInt32
    public let encodedRate: Double
    public let encodedChannels: UInt32
    public let decodedFile: String
    public let decodedFrames: Int64
    public let decoderReportedFrames: Int64
    public let decodedRate: Double
    public let decodedChannels: UInt32
    public let decodedSampleFormat: String
    public let decodedSHA256: String
    public let packetTimeline: PacketTimeline?
    public let manualTrimFrames: Int
    public let sourceUnchanged: Bool
}
public struct CodecFailure: Error, CustomStringConvertible {
    public let stage: String
    public let domain: String
    public let code: Int
    public var description: String { "\(stage): \(domain) \(code)" }
}
public enum NativeCandidate {
    public static func hash(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var digest = SHA256()
        while let data = try handle.read(upToCount: 65536), !data.isEmpty { digest.update(data: data) }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
    public static func convert(sourceURL: URL, source: SourcePCM, outputDirectory: URL) throws -> CodecMeasurement {
        guard source.frames > 0, [1, 2].contains(source.channels), source.sampleRate.isFinite,
              source.sampleRate > 0, source.sampleRate <= 192000,
              source.frames <= Int.max / (source.channels * source.sampleWidth) else { throw CodecFailure(stage: "validate-source", domain: "ProbeCodec.UnsupportedPCM", code: 1) }
        var stage = "validate-source"
        do {
            let expectedBytes = source.frames * source.channels * source.sampleWidth
            let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
            guard (attributes[.size] as? NSNumber)?.intValue == expectedBytes else { throw ProbeError.invalid }
            let originalHash = try hash(sourceURL)
            stage = "create-candidate-directory"
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            let stem = UUID().uuidString
            let encoded = outputDirectory.appendingPathComponent(stem + ".m4a")
            let decoded = outputDirectory.appendingPathComponent(stem + ".decoded.f32le")
            let format = AVAudioFormat(standardFormatWithSampleRate: source.sampleRate, channels: AVAudioChannelCount(source.channels))!
            let input = try FileHandle(forReadingFrom: sourceURL)
            defer { try? input.close() }
            // kAudioFormatMPEG4AAC is AAC-LC; HE/HEv2 have different format identifiers.
            stage = "open-AAC-writer"
            var writer: AVAudioFile? = try AVAudioFile(forWriting: encoded, settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: source.sampleRate,
                AVNumberOfChannelsKey: source.channels,
                AVEncoderBitRateKey: source.channels == 1 ? 64000 : 96000
            ], commonFormat: .pcmFormatFloat32, interleaved: false)
            defer { writer = nil } // Failed partial candidates remain quarantined; source is read-only.
            var position = 0
            while position < source.frames {
                let count = min(4096, source.frames - position)
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count))!
                buffer.frameLength = AVAudioFrameCount(count)
                stage = "read-source-PCM"
                if source.interleaved {
                    try input.seek(toOffset: UInt64(position * source.channels * source.sampleWidth))
                    let raw = try input.read(upToCount: count * source.channels * source.sampleWidth) ?? Data()
                    guard raw.count == count * source.channels * source.sampleWidth else { throw ProbeError.invalid }
                    for frame in 0..<count {
                        for channel in 0..<source.channels {
                            buffer.floatChannelData![channel][frame] = try sample(raw, index: frame * source.channels + channel, format: source.sampleFormat)
                        }
                    }
                } else {
                    for channel in 0..<source.channels {
                        try input.seek(toOffset: UInt64((channel * source.frames + position) * source.sampleWidth))
                        let raw = try input.read(upToCount: count * source.sampleWidth) ?? Data()
                        guard raw.count == count * source.sampleWidth else { throw ProbeError.invalid }
                        for frame in 0..<count { buffer.floatChannelData![channel][frame] = try sample(raw, index: frame, format: source.sampleFormat) }
                    }
                }
                stage = "write-AAC-buffer"
                try writer!.write(from: buffer); position += count
            }
            stage = "seal-AAC"
            writer = nil // Close/seal the M4A before any read or declaration of a candidate.
            let sync = try FileHandle(forWritingTo: encoded); try sync.synchronize(); try sync.close()
            stage = "open-candidate-decoder"
            let reader = try AVAudioFile(forReading: encoded, commonFormat: .pcmFormatFloat32, interleaved: false)
            let encodedASBD = reader.fileFormat.streamDescription.pointee
            guard encodedASBD.mFormatID == kAudioFormatMPEG4AAC else { throw ProbeError.invalid }
            let decodedFormat = reader.processingFormat
            let buffer = AVAudioPCMBuffer(pcmFormat: decodedFormat, frameCapacity: 4096)!
            try DurableFile.write(Data(), to: decoded)
            let destination = try FileHandle(forWritingTo: decoded)
            defer { try? destination.close() }
            var decodedFrames: Int64 = 0
            while reader.framePosition < reader.length {
                stage = "read-decoded-buffer"
                let requested = AVAudioFrameCount(min(4096, reader.length - reader.framePosition))
                try reader.read(into: buffer, frameCount: requested)
                let count = Int(buffer.frameLength)
                guard count > 0 else { throw ProbeError.invalid }
                let channels = Int(decodedFormat.channelCount)
                var interleaved = [Float](repeating: 0, count: count * channels)
                for frame in 0..<count {
                    for channel in 0..<channels { interleaved[frame * channels + channel] = buffer.floatChannelData![channel][frame] }
                }
                try interleaved.withUnsafeBytes { try destination.write(contentsOf: Data($0)) }
                decodedFrames += Int64(count)
            }
            try destination.synchronize(); try destination.close()
            stage = "verify-and-report"
            guard try hash(sourceURL) == originalHash else { throw ProbeError.invalid }
            let encodedBytes = (try FileManager.default.attributesOfItem(atPath: encoded.path)[.size] as! NSNumber).intValue
            let result = CodecMeasurement(source: source, sourceBytes: expectedBytes, sourceSHA256: originalHash,
                encodedFile: encoded.lastPathComponent, encodedBytes: encodedBytes, encodedSHA256: try hash(encoded),
                encodedFormatID: encodedASBD.mFormatID, encodedRate: encodedASBD.mSampleRate, encodedChannels: encodedASBD.mChannelsPerFrame,
                decodedFile: decoded.lastPathComponent, decodedFrames: decodedFrames, decoderReportedFrames: reader.length, decodedRate: decodedFormat.sampleRate,
                decodedChannels: decodedFormat.channelCount, decodedSampleFormat: "float32-little-endian-frame-interleaved",
                decodedSHA256: try hash(decoded), packetTimeline: packetTimeline(encoded), manualTrimFrames: 0, sourceUnchanged: true)
            // Only this durable report names a fully closed, decoded candidate. Never an audio receipt.
            try DurableFile.save(result, to: outputDirectory.appendingPathComponent(stem + ".measurement.json"))
            return result
        } catch {
            let failure = error as NSError
            throw CodecFailure(stage: stage, domain: failure.domain, code: failure.code)
        }
    }
    private static func sample(_ data: Data, index: Int, format: PCMSampleFormat) throws -> Float {
        let value: Float = data.withUnsafeBytes { bytes in
            switch format {
            case .float32: Float(bitPattern: UInt32(littleEndian: bytes.loadUnaligned(fromByteOffset: index * 4, as: UInt32.self)))
            case .int16: Float(Int16(littleEndian: bytes.loadUnaligned(fromByteOffset: index * 2, as: Int16.self))) / 32768
            }
        }
        guard value.isFinite else { throw ProbeError.invalid }
        return value
    }
    private static func packetTimeline(_ url: URL) -> PacketTimeline? {
        #if canImport(AudioToolbox)
        var file: AudioFileID?
        guard AudioFileOpenURL(url as CFURL, .readPermission, 0, &file) == noErr, let file else { return nil }
        defer { AudioFileClose(file) }
        var table = AudioFilePacketTableInfo(), size = UInt32(MemoryLayout<AudioFilePacketTableInfo>.size)
        guard AudioFileGetProperty(file, kAudioFilePropertyPacketTableInfo, &size, &table) == noErr else { return nil }
        var packets: UInt64 = 0; size = UInt32(MemoryLayout<UInt64>.size)
        let hasPackets = AudioFileGetProperty(file, kAudioFilePropertyAudioDataPacketCount, &size, &packets) == noErr
        var format = AudioStreamBasicDescription(); size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        guard AudioFileGetProperty(file, kAudioFilePropertyDataFormat, &size, &format) == noErr else { return nil }
        return PacketTimeline(validFrames: table.mNumberValidFrames, primingFrames: table.mPrimingFrames,
            remainderFrames: table.mRemainderFrames, packets: hasPackets ? packets : nil, framesPerPacket: format.mFramesPerPacket)
        #else
        return nil // watchOS does not expose AudioToolbox packet-table APIs; never copy host values.
        #endif
    }
}
