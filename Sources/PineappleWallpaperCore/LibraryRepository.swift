import Foundation
import CryptoKit

/// Only this layer writes the manifest. Callers commit the file before publishing UI state.
public struct LibraryRepository: Sendable {
    public let root: URL
    public var media: URL { root.appendingPathComponent("Media", isDirectory: true) }
    public var thumbnails: URL { root.appendingPathComponent("Thumbnails", isDirectory: true) }
    public var staging: URL { root.appendingPathComponent("Staging", isDirectory: true) }
    public var manifest: URL { root.appendingPathComponent("library.json") }
    public init(root: URL) { self.root = root }
    public func prepare() throws {
        for dir in [root, media, thumbnails, staging] {
            if FileManager.default.fileExists(atPath: dir.path) {
                let values = try dir.resourceValues(forKeys: [.isSymbolicLinkKey])
                guard values.isSymbolicLink != true else { throw LibraryError.symlink }
            }
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
    public func load() throws -> Library {
        guard FileManager.default.fileExists(atPath: manifest.path) else { return Library() }
        do { return try JSONDecoder().decode(Library.self, from: Data(contentsOf: manifest)).validated() }
        catch let error as LibraryError { throw error }
        catch { throw LibraryError.invalidManifest }
    }
    public func save(_ library: Library) throws {
        let valid = try library.validated()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(valid).write(to: manifest, options: .atomic)
    }
    public func mediaURL(_ clip: Clip) throws -> URL {
        guard Library.safeFilename(clip.filename) else { throw LibraryError.invalidManifest }
        let url = media.appendingPathComponent(clip.filename)
        if FileManager.default.fileExists(atPath: url.path) {
            let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { throw LibraryError.symlink }
        }
        return url
    }
    public func contains(_ clip: Clip) -> Bool {
        guard let url = try? mediaURL(clip) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
    public func thumbnailURL(_ clip: Clip) -> URL { thumbnails.appendingPathComponent(clip.thumbnailFilename) }

    /// Bounded memory copy plus SHA-256 of the exact imported bytes. No source paths are persisted.
    public func stage(_ source: URL) throws -> StagedFile {
        let suffix = source.pathExtension.lowercased()
        let extensionPart = suffix.isEmpty ? "mp4" : suffix
        let url = staging.appendingPathComponent(UUID().uuidString).appendingPathExtension(extensionPart)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        do {
            let reader = try FileHandle(forReadingFrom: source)
            defer { try? reader.close() }
            let writer = try FileHandle(forWritingTo: url)
            defer { try? writer.close() }
            var hash = SHA256(); var bytes: Int64 = 0
            while let data = try reader.read(upToCount: 1_048_576), !data.isEmpty {
                try Task.checkCancellation()
                try writer.write(contentsOf: data)
                hash.update(data: data); bytes += Int64(data.count)
            }
            try writer.synchronize()
            return StagedFile(url: url, digest: hash.finalize().map { String(format: "%02x", $0) }.joined(), bytes: bytes)
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }
}

public struct StagedFile: Sendable {
    public let url: URL
    public let digest: String
    public let bytes: Int64
}
