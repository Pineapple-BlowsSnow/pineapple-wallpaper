import Foundation

/// Copies a previous library without changing its media, selection, or preferences.
public enum LibraryMigration {
    @discardableResult
    public static func copyIfNeeded(from source: LibraryRepository, to destination: LibraryRepository) throws -> Int {
        guard FileManager.default.fileExists(atPath: source.manifest.path),
              !FileManager.default.fileExists(atPath: destination.manifest.path) else { return 0 }
        let library = try source.load()
        try destination.prepare()
        for clip in library.clips {
            let original = try source.mediaURL(clip)
            guard FileManager.default.fileExists(atPath: original.path) else { throw LibraryError.invalidManifest }
            let target = try destination.mediaURL(clip)
            if FileManager.default.fileExists(atPath: target.path) {
                let size = try target.resourceValues(forKeys: [.fileSizeKey]).fileSize
                guard Int64(size ?? -1) == clip.bytes else { throw LibraryError.invalidManifest }
            } else {
                let temporary = destination.staging.appendingPathComponent(UUID().uuidString)
                do {
                    try FileManager.default.copyItem(at: original, to: temporary)
                    try FileManager.default.moveItem(at: temporary, to: target)
                } catch {
                    try? FileManager.default.removeItem(at: temporary)
                    throw error
                }
            }
            let oldThumbnail = source.thumbnailURL(clip)
            let newThumbnail = destination.thumbnailURL(clip)
            if FileManager.default.fileExists(atPath: oldThumbnail.path),
               !FileManager.default.fileExists(atPath: newThumbnail.path),
               (try oldThumbnail.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink != true {
                try? FileManager.default.copyItem(at: oldThumbnail, to: newThumbnail)
            }
        }
        try destination.save(library)
        return library.clips.count
    }
}
