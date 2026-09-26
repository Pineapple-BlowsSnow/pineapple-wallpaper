import Foundation

public enum ScaleMode: String, Codable, CaseIterable, Sendable {
    case fill, fit
}

public enum MediaKind: String, Codable, Sendable {
    case video, photo
}

public struct Preferences: Codable, Equatable, Sendable {
    public var scaleMode: ScaleMode = .fill
    public var pauseInLowPowerMode = true
    public var paused = false
    public init() {}
}

public struct Clip: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public let filename: String
    public let digest: String
    public let bytes: Int64
    public let duration: Double
    public let width: Int
    public let height: Int
    public let addedAt: Date
    public var favorite: Bool
    public let kind: MediaKind

    public init(id: UUID = UUID(), title: String, filename: String, digest: String,
                bytes: Int64, duration: Double, width: Int, height: Int,
                addedAt: Date = Date(), favorite: Bool = false, kind: MediaKind = .video) {
        self.id = id; self.title = title; self.filename = filename; self.digest = digest
        self.bytes = bytes; self.duration = duration; self.width = width; self.height = height
        self.addedAt = addedAt; self.favorite = favorite; self.kind = kind
    }
    private enum CodingKeys: String, CodingKey {
        case id, title, filename, digest, bytes, duration, width, height, addedAt, favorite, kind
    }
    public init(from decoder: Decoder) throws {
        let data = try decoder.container(keyedBy: CodingKeys.self)
        id = try data.decode(UUID.self, forKey: .id)
        title = try data.decode(String.self, forKey: .title)
        filename = try data.decode(String.self, forKey: .filename)
        digest = try data.decode(String.self, forKey: .digest)
        bytes = try data.decode(Int64.self, forKey: .bytes)
        duration = try data.decode(Double.self, forKey: .duration)
        width = try data.decode(Int.self, forKey: .width)
        height = try data.decode(Int.self, forKey: .height)
        addedAt = try data.decode(Date.self, forKey: .addedAt)
        favorite = try data.decode(Bool.self, forKey: .favorite)
        kind = try data.decodeIfPresent(MediaKind.self, forKey: .kind) ?? .video
    }
    public var isPhoto: Bool { kind == .photo }
    public var thumbnailFilename: String { "\(id.uuidString).jpg" }
}

public struct Library: Codable, Equatable, Sendable {
    public var schemaVersion: Int = 2
    public var clips: [Clip] = []
    public var activeID: UUID?
    public var preferences = Preferences()
    public init() {}
    public var active: Clip? { clips.first { $0.id == activeID } }
    public var totalBytes: Int64 { clips.reduce(0) { $0 + $1.bytes } }

    public mutating func remove(_ id: UUID) {
        clips.removeAll { $0.id == id }
        if activeID == id { activeID = clips.first?.id }
    }
    public func matching(_ query: String, favoritesOnly: Bool) -> [Clip] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return clips.filter { (!favoritesOnly || $0.favorite) && (text.isEmpty || $0.title.localizedCaseInsensitiveContains(text)) }
    }
    public func validated() throws -> Library {
        guard schemaVersion == 1 || schemaVersion == 2 else { throw LibraryError.unsupportedVersion(schemaVersion) }
        guard schemaVersion == 2 || clips.allSatisfy({ $0.kind == .video }) else { throw LibraryError.invalidManifest }
        guard Set(clips.map(\.id)).count == clips.count,
              Set(clips.map(\.filename)).count == clips.count else { throw LibraryError.invalidManifest }
        for clip in clips {
            guard Self.safeFilename(clip.filename), !clip.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  clip.bytes >= 0, clip.duration.isFinite,
                  (clip.kind == .photo ? clip.duration == 0 : clip.duration > 0),
                  clip.width > 0, clip.height > 0,
                  clip.digest.count == 64, clip.digest.allSatisfy({ $0.isHexDigit }) else { throw LibraryError.invalidManifest }
        }
        var repaired = self
        if let id = activeID, !clips.contains(where: { $0.id == id }) { repaired.activeID = clips.first?.id }
        return repaired
    }
    public static func safeFilename(_ filename: String) -> Bool {
        !filename.isEmpty && filename != "." && filename != ".." &&
        !filename.contains("/") && !filename.contains("\\") && !filename.contains("\0")
    }
}

public enum LibraryError: LocalizedError {
    case unsupportedVersion(Int), invalidManifest, symlink, noVideo, noPhoto, invalidName
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version): return "此图库由更新版本创建（版本 \(version)），请先更新菠萝壁纸。"
        case .invalidManifest: return "图库记录损坏。原文件已保留，请打开数据目录备份 library.json 后检查。"
        case .symlink: return "图库中存在不安全的文件链接，操作已停止。"
        case .noVideo: return "没有可播放的视频轨道。请选择 macOS 支持的 MP4 或 MOV 文件。"
        case .noPhoto: return "无法读取照片。请选择有效的 JPEG、PNG、HEIC 或 TIFF 图片。"
        case .invalidName: return "名称不能为空。"
        }
    }
}
