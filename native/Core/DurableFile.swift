import Foundation
import Darwin

public enum ProbeError: Error { case blocked, busy, invalid, noAudio, io(Int32), lowSpace }

public enum DurableFile {
    public static func write(_ data: Data, to url: URL) throws {
        let temp = url.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".tmp")
        let fd = open(temp.path, O_CREAT | O_EXCL | O_WRONLY, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw ProbeError.io(errno) }
        defer { close(fd) } // Preserve even failed temporary files for recovery.
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let n = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                if n < 0 && errno == EINTR { continue }
                guard n > 0 else { throw ProbeError.io(errno) }
                offset += n
            }
        }
        guard fsync(fd) == 0 else { throw ProbeError.io(errno) }
        guard rename(temp.path, url.path) == 0 else { throw ProbeError.io(errno) }
        let dir = open(url.deletingLastPathComponent().path, O_RDONLY)
        guard dir >= 0 else { throw ProbeError.io(errno) }
        defer { close(dir) }
        guard fsync(dir) == 0 else { throw ProbeError.io(errno) }
    }
    public static func save<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try write(encoder.encode(value), to: url)
    }
}

/// Exclusive local writer for this probe store; never opens another application's data.
final class StoreLock {
    private let fd: Int32
    init(root: URL) throws {
        fd = open(root.appendingPathComponent("writer.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw ProbeError.io(errno) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { close(fd); throw ProbeError.busy }
    }
    deinit { flock(fd, LOCK_UN); close(fd) }
}
