import Foundation
#if canImport(ProbeCore)
import ProbeCore
#endif

public struct CodecFixtureCase: Codable, Sendable {
    public let name: String
    public let outcome: String
    public let measurement: CodecMeasurement?
    public let correlation: Double?
    public let signalLagFrames: Int?
    public let sourceRetained: Bool
    public let errorStage: String?
    public let errorDomain: String?
    public let errorCode: Int?
}
public struct CodecFixtureReport: Encodable, Sendable {
    public let version = 1
    public let cases: [CodecFixtureCase]
    public let chronologicalBoundaryPassed: Bool?
    public let boundaryLeft700to1200EnergyRatio: Double?
    public let boundaryRight1200to700EnergyRatio: Double?
    public let speechQuality = "not-run; synthetic signal only"
}

/// The same offline lab driver runs on host and simulator. No microphone/session/network.
public enum CodecFixtures {
    public static func run(root: URL) throws -> CodecFixtureReport {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let definitions: [(String, Double, Int, Int, PCMSampleFormat, Bool, Double)] = [
            ("short-mono", 48000, 1, 480, .float32, true, 700),
            ("append-left", 48000, 1, 6000, .float32, true, 700),
            ("append-right", 48000, 1, 6000, .float32, true, 1200),
            ("route-stereo-int16-planar", 44100, 2, 11025, .int16, false, 900),
            ("route-stereo-float-planar", 32000, 2, 8000, .float32, false, 600),
            ("route-stereo-int16-interleaved", 48000, 2, 12000, .int16, true, 1100)
        ]
        var cases: [CodecFixtureCase] = [], decodedByName: [String: [Float]] = [:]
        for (name, rate, channels, frames, format, interleaved, frequency) in definitions {
            let descriptor = SourcePCM(sampleFormat: format, interleaved: interleaved, sampleRate: rate, channels: channels, frames: frames)
            let folder = root.appendingPathComponent(name); try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let original = folder.appendingPathComponent("original.pcm")
            // Multi-tone envelope makes chronological and channel swaps visible independently of byte layout.
            var reference: [Float] = []
            for frame in 0..<frames {
                for channel in 0..<channels {
                    let t = Double(frame) / rate
                    let value = Float(0.28 * sin(2 * .pi * (frequency + Double(channel) * 257) * t) + 0.06 * sin(2 * .pi * 173 * t))
                    reference.append(format == .int16 ? Float(Int16(value * 32768)) / 32768 : value)
                }
            }
            var ordered: [Float] = []
            if interleaved { ordered = reference }
            else { for channel in 0..<channels { for frame in 0..<frames { ordered.append(reference[frame * channels + channel]) } } }
            let bytes: Data
            if format == .float32 { bytes = ordered.withUnsafeBytes { Data($0) } }
            else { bytes = ordered.map { Int16($0 * 32768) }.withUnsafeBytes { Data($0) } }
            try DurableFile.write(bytes, to: original)
            let expectedHash = TransferLedger.hash(bytes)
            do {
                let measurement = try NativeCandidate.convert(sourceURL: original, source: descriptor, outputDirectory: folder)
                let decoded = try readFloat32(folder.appendingPathComponent(measurement.decodedFile))
                let correlation = similarity(reference, decoded, channels: channels, lag: 0)
                let bestLag = (-32...32).max { similarity(reference, decoded, channels: channels, lag: $0) < similarity(reference, decoded, channels: channels, lag: $1) }!
                let retained = try NativeCandidate.hash(original) == expectedHash
                let passed = retained && measurement.decodedFrames == frames && measurement.decodedRate == rate && measurement.decodedChannels == channels && correlation > 0.9
                decodedByName[name] = decoded
                cases.append(CodecFixtureCase(name: name, outcome: passed ? "measured-candidate" : "integrity-check-held", measurement: measurement,
                    correlation: correlation, signalLagFrames: bestLag, sourceRetained: retained, errorStage: nil, errorDomain: nil, errorCode: nil))
            } catch {
                let failure = error as? CodecFailure
                cases.append(CodecFixtureCase(name: name, outcome: "encoder-or-decoder-held", measurement: nil, correlation: nil, signalLagFrames: nil,
                    sourceRetained: (try? NativeCandidate.hash(original)) == expectedHash, errorStage: failure?.stage,
                    errorDomain: failure?.domain ?? (error as NSError).domain, errorCode: failure?.code ?? (error as NSError).code))
            }
        }
        // Real failure boundaries: unsupported source/encoder rate, non-finite PCM, and filesystem obstruction.
        for mode in ["unsupported-channels", "unsupported-encoder-rate", "nonfinite-source", "destination-obstructed"] {
            let folder = root.appendingPathComponent(mode); try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let original = folder.appendingPathComponent("original.pcm")
            let channels = mode == "unsupported-channels" ? 3 : 1
            let rate = mode == "unsupported-encoder-rate" ? 12345.0 : 48000.0
            var values = [Float](repeating: 0.125, count: 480 * channels)
            if mode == "nonfinite-source" { values[0] = .nan }
            let bytes = values.withUnsafeBytes { Data($0) }; try DurableFile.write(bytes, to: original)
            let output = folder.appendingPathComponent("output")
            if mode == "destination-obstructed" { try DurableFile.write(Data("obstruction".utf8), to: output) }
            var failure: CodecFailure?
            do { _ = try NativeCandidate.convert(sourceURL: original, source: SourcePCM(sampleFormat: .float32, interleaved: true, sampleRate: rate, channels: channels, frames: 480), outputDirectory: output) }
            catch { failure = error as? CodecFailure }
            let expectedStage = mode == "unsupported-channels" ? "validate-source" : mode == "unsupported-encoder-rate" ? "write-AAC-buffer" : mode == "nonfinite-source" ? "read-source-PCM" : "create-candidate-directory"
            let noMeasurement = ((try? FileManager.default.contentsOfDirectory(atPath: output.path)) ?? []).allSatisfy { !$0.hasSuffix(".measurement.json") }
            let rejected = failure?.stage == expectedStage && noMeasurement
            let retained = try Data(contentsOf: original) == bytes
            cases.append(CodecFixtureCase(name: mode, outcome: rejected && retained ? "expected-hold-source-retained" : "failure-contract-broken",
                measurement: nil, correlation: nil, signalLagFrames: nil, sourceRetained: retained, errorStage: failure?.stage, errorDomain: failure?.domain, errorCode: failure?.code))
        }
        var leftRatio: Double?, rightRatio: Double?, boundary: Bool?
        if let left = decodedByName["append-left"], let right = decodedByName["append-right"], left.count >= 1200, right.count >= 1200 {
            let l = Array(left.suffix(1200)), r = Array(right.prefix(1200))
            leftRatio = energy(l, frequency: 700, rate: 48000) / max(energy(l, frequency: 1200, rate: 48000), 1e-12)
            rightRatio = energy(r, frequency: 1200, rate: 48000) / max(energy(r, frequency: 700, rate: 48000), 1e-12)
            boundary = leftRatio! > 4 && rightRatio! > 4
        }
        let report = CodecFixtureReport(cases: cases, chronologicalBoundaryPassed: boundary,
            boundaryLeft700to1200EnergyRatio: leftRatio, boundaryRight1200to700EnergyRatio: rightRatio)
        try DurableFile.save(report, to: root.appendingPathComponent("codec-report.json"))
        return report
    }
    private static func readFloat32(_ url: URL) throws -> [Float] {
        let data = try Data(contentsOf: url)
        return data.withUnsafeBytes { raw in stride(from: 0, to: raw.count, by: 4).map { Float(bitPattern: UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: $0, as: UInt32.self))) } }
    }
    private static func similarity(_ source: [Float], _ decoded: [Float], channels: Int, lag: Int) -> Double {
        var dot = 0.0, a2 = 0.0, b2 = 0.0
        let frames = min(source.count, decoded.count) / channels
        for frame in max(0, -lag)..<max(max(0, -lag), min(frames, frames - lag)) {
            for channel in 0..<channels {
                let a = Double(source[frame * channels + channel]), b = Double(decoded[(frame + lag) * channels + channel])
                dot += a * b; a2 += a * a; b2 += b * b
            }
        }
        return a2 > 0 && b2 > 0 ? dot / sqrt(a2 * b2) : 0
    }
    private static func energy(_ data: [Float], frequency: Double, rate: Double) -> Double {
        var real = 0.0, imaginary = 0.0
        for (index, value) in data.enumerated() {
            let phase = 2 * Double.pi * frequency * Double(index) / rate
            real += Double(value) * cos(phase); imaginary += Double(value) * sin(phase)
        }
        return real * real + imaginary * imaginary
    }
}
