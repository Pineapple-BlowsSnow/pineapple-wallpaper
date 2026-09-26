import AppKit
import AVFoundation
import Combine
import PineappleWallpaperCore
import ScreenSaver
import UniformTypeIdentifiers

private struct LegacyLibrary: Decodable {
    struct Entry: Decodable { let id: UUID; let name: String; let filename: String }
    let videos: [Entry]
    let selectedID: UUID?
}

@MainActor
final class VideoLibrary: ObservableObject {
    @Published private(set) var library = Library()
    @Published private(set) var busy = false
    @Published var message = ""
    @Published var search = ""
    @Published var favoritesOnly = false
    @Published private(set) var screenSaverID: UUID?
    @Published private(set) var thumbnails: [UUID: NSImage] = [:]
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var playerState = ""
    @Published private(set) var lowPowerActive = ProcessInfo.processInfo.isLowPowerModeEnabled

    let repository: LibraryRepository
    let engine = WallpaperEngine()
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private(set) var loadError: String?
    var active: Clip? { library.active }
    var canPause: Bool { active?.isPhoto == false }
    var visible: [Clip] { library.matching(search, favoritesOnly: favoritesOnly) }
    var screenSaverClip: Clip? { screenSaverID.flatMap { id in library.clips.first { $0.id == id } } }
    var effectivePause: Bool { canPause && (library.preferences.paused || (library.preferences.pauseInLowPowerMode && lowPowerActive)) }
    var player: AVQueuePlayer? { engine.previewPlayer }
    var previewPhoto: NSImage? { engine.previewImage }
    var durationText: String {
        guard let active, !active.isPhoto else { return "00:00" }
        return Self.clock(active.duration)
    }
    var elapsedText: String { Self.clock(elapsed) }
    static func clock(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--" }
        let value = Int(seconds)
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
    init(root: URL? = nil) {
        let home = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        repository = LibraryRepository(root: root ?? home.appendingPathComponent("PineappleWallpaper", isDirectory: true))
        if let value = ScreenSaverDefaults(forModuleWithName: ScreenSaverConfig.moduleIdentifier)?
            .string(forKey: ScreenSaverConfig.selectedClipKey) {
            screenSaverID = UUID(uuidString: value)
        }
        do {
            try repository.prepare()
            library = try repository.load()
        } catch {
            loadError = error.localizedDescription
            message = "读取壁纸库失败：\(error.localizedDescription)"
        }
        if loadError == nil {
            apply()
            loadThumbnails()
            if !FileManager.default.fileExists(atPath: repository.manifest.path) { Task { await migratePreviousLibrary() } }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.engine.refreshScreens() }
        })
        observers.append(center.addObserver(forName: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.powerChanged() }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.engine.setPaused(true) }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.apply() }
        })
    }
    deinit { timer?.invalidate(); for observer in observers { NotificationCenter.default.removeObserver(observer) } }
    private func powerChanged() {
        lowPowerActive = ProcessInfo.processInfo.isLowPowerModeEnabled
        engine.setPaused(effectivePause)
    }
    private func tick() {
        if active?.isPhoto == true { elapsed = 0; playerState = "照片壁纸"; return }
        guard let player = engine.previewPlayer else { elapsed = 0; playerState = ""; return }
        let seconds = player.currentTime().seconds
        elapsed = seconds.isFinite ? seconds : 0
        if let error = player.currentItem?.error { playerState = error.localizedDescription }
        else if effectivePause { playerState = lowPowerActive && library.preferences.pauseInLowPowerMode && !library.preferences.paused ? "低电量模式已暂停" : "已暂停" }
        else { playerState = player.timeControlStatus == .playing ? "正在播放" : "正在加载" }
    }
    private func apply() {
        let url = active.flatMap { try? repository.mediaURL($0) }
        let present = url.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
        engine.apply(url: present, kind: active?.kind, scaleMode: library.preferences.scaleMode, paused: effectivePause)
        if active != nil && present == nil { message = "图库副本丢失。可从列表移除后重新添加。" }
    }
    private func update(_ change: (inout Library) -> Void) {
        guard loadError == nil else { return }
        var next = library; change(&next)
        do {
            try repository.save(next)
            library = next
            apply()
        } catch { message = "保存失败：\(error.localizedDescription)" }
    }
    func select(_ clip: Clip) {
        guard clip.id != library.activeID else { return }
        update { $0.activeID = clip.id; $0.preferences.paused = false }
    }
    func togglePause() {
        guard active?.isPhoto == false else { return }
        update { $0.preferences.paused.toggle() }
    }
    func setScale(_ mode: ScaleMode) { update { $0.preferences.scaleMode = mode } }
    func setPowerPause(_ value: Bool) { update { $0.preferences.pauseInLowPowerMode = value } }
    func setScreenSaverClip(_ id: UUID?) {
        guard id == nil || library.clips.contains(where: { $0.id == id }) else { return }
        guard let defaults = ScreenSaverDefaults(forModuleWithName: ScreenSaverConfig.moduleIdentifier) else {
            message = "无法保存屏幕保护程序的选择。"
            return
        }
        if let id { defaults.set(id.uuidString, forKey: ScreenSaverConfig.selectedClipKey) }
        else { defaults.removeObject(forKey: ScreenSaverConfig.selectedClipKey) }
        guard defaults.synchronize() else { message = "无法保存屏幕保护程序的选择。"; return }
        screenSaverID = id
    }
    func installScreenSaver() {
        guard let saver = Bundle.main.builtInPlugInsURL?.appendingPathComponent("PineappleWallpaper.saver"),
              FileManager.default.fileExists(atPath: saver.path) else {
            message = "安装包中缺少屏幕保护程序，请重新构建应用。"
            return
        }
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    let manager = FileManager.default
                    let folder = manager.homeDirectoryForCurrentUser
                        .appendingPathComponent("Library/Screen Savers", isDirectory: true)
                    try manager.createDirectory(at: folder, withIntermediateDirectories: true)
                    let destination = folder.appendingPathComponent("PineappleWallpaper.saver", isDirectory: true)
                    let staged = folder.appendingPathComponent(".PineappleWallpaper-\(UUID().uuidString).saver", isDirectory: true)
                    try manager.copyItem(at: saver, to: staged)
                    defer { try? manager.removeItem(at: staged) }
                    if manager.fileExists(atPath: destination.path) {
                        _ = try manager.replaceItemAt(destination, withItemAt: staged)
                    } else {
                        try manager.moveItem(at: staged, to: destination)
                    }
                }.value
                message = "屏幕保护程序已安装。请在系统设置 → 墙纸 → 屏幕保护程序 → 其他中选择菠萝壁纸。"
            } catch { message = "屏幕保护程序安装失败：\(error.localizedDescription)" }
        }
    }
    func toggleFavorite(_ clip: Clip) {
        update { library in
            guard let i = library.clips.firstIndex(where: { $0.id == clip.id }) else { return }
            library.clips[i].favorite.toggle()
        }
    }
    func rename(_ clip: Clip, to raw: String) {
        let title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { message = LibraryError.invalidName.localizedDescription; return }
        update { library in
            guard let i = library.clips.firstIndex(where: { $0.id == clip.id }) else { return }
            library.clips[i].title = title
        }
    }
    func remove(_ clip: Clip) {
        guard !busy else { return }
        let old = library
        update { $0.remove(clip.id) }
        if screenSaverID == clip.id { setScreenSaverClip(nil) }
        guard old != library else { return }
        if let url = try? repository.mediaURL(clip), FileManager.default.fileExists(atPath: url.path) {
            do { try FileManager.default.trashItem(at: url, resultingItemURL: nil) }
            catch { message = "已从列表移除；副本未能移到废纸篓：\(error.localizedDescription)" }
        }
        try? FileManager.default.removeItem(at: repository.thumbnailURL(clip))
        thumbnails.removeValue(forKey: clip.id)
        if message.isEmpty { message = "已移除。图库副本已移到废纸篓，原文件不受影响。" }
    }
    func addMedia() {
        guard !busy, loadError == nil else { return }
        let panel = NSOpenPanel()
        panel.title = "添加照片或视频壁纸"
        panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie, .jpeg, .png, .heic, .tiff]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.message = "照片和视频会复制到本机的菠萝壁纸图库。"
        if panel.runModal() == .OK { Task { await importURLs(panel.urls) } }
    }
    private func importURLs(_ urls: [URL]) async {
        guard !busy, loadError == nil else { return }
        busy = true
        var count = 0; var failures: [String] = []
        for url in urls {
            message = "正在导入 \(url.lastPathComponent)…"
            let accessed = url.startAccessingSecurityScopedResource()
            do {
                let result = try await importOne(url: url, title: url.deletingPathExtension().lastPathComponent)
                if result { count += 1 }
            } catch { failures.append("\(url.lastPathComponent)：\(error.localizedDescription)") }
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        busy = false
        message = failures.isEmpty ? (count > 0 ? "已导入 \(count) 个项目。" : "文件已在库中，已切换到现有副本。") : failures.joined(separator: "\n")
    }
    private func importOne(url: URL, title: String) async throws -> Bool {
        let repository = self.repository
        let staged = try await Task.detached(priority: .userInitiated) { try repository.stage(url) }.value
        var shouldDeleteStage = true
        defer { if shouldDeleteStage { try? FileManager.default.removeItem(at: staged.url) } }
        guard staged.bytes > 0 else { throw LibraryError.noVideo }
        let kind: MediaKind = UTType(filenameExtension: staged.url.pathExtension)?.conforms(to: .image) == true ? .photo : .video
        let width: Int, height: Int
        let duration: Double
        if kind == .photo {
            guard let dimensions = PhotoImageLoader.dimensions(at: staged.url),
                  PhotoImageLoader.image(at: staged.url, maxPixelSize: 640) != nil else { throw LibraryError.noPhoto }
            width = dimensions.width; height = dimensions.height; duration = 0
        } else {
            let asset = AVURLAsset(url: staged.url)
            let playable = try await asset.load(.isPlayable)
            duration = try await asset.load(.duration).seconds
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard playable, duration.isFinite, duration > 0, let track = tracks.first else { throw LibraryError.noVideo }
            let dimensions = try await track.load(.naturalSize)
            guard dimensions.width > 0, dimensions.height > 0 else { throw LibraryError.noVideo }
            width = Int(dimensions.width); height = Int(dimensions.height)
        }
        if let existing = library.clips.first(where: { $0.digest == staged.digest && repository.contains($0) }) {
            select(existing); return false
        }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let clip = Clip(title: name.isEmpty ? "未命名画面" : name,
                        filename: "\(UUID().uuidString).\(staged.url.pathExtension)",
                        digest: staged.digest, bytes: staged.bytes, duration: duration,
                        width: width, height: height, kind: kind)
        let target = repository.media.appendingPathComponent(clip.filename)
        try FileManager.default.moveItem(at: staged.url, to: target)
        shouldDeleteStage = false
        do {
            var next = library
            if kind == .photo { next.schemaVersion = 2 }
            next.clips.insert(clip, at: 0); next.activeID = clip.id; next.preferences.paused = false
            try repository.save(next)
            library = next; apply()
            await makeThumbnail(clip)
            return true
        } catch {
            try? FileManager.default.removeItem(at: target)
            throw error
        }
    }
    private func loadThumbnails() {
        for clip in library.clips {
            if let image = NSImage(contentsOf: repository.thumbnailURL(clip)) { thumbnails[clip.id] = image }
            else if repository.contains(clip) { Task { await makeThumbnail(clip) } }
        }
    }
    private func makeThumbnail(_ clip: Clip) async {
        guard let url = try? repository.mediaURL(clip) else { return }
        let thumb = repository.thumbnailURL(clip)
        let imageData: Data? = await Task.detached(priority: .utility) {
            let frame: CGImage
            if clip.isPhoto {
                guard let image = PhotoImageLoader.image(at: url, maxPixelSize: 640) else { return nil }
                frame = image
            } else {
                let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 640, height: 360)
                guard let result = try? await generator.image(at: CMTime(seconds: min(1, clip.duration / 2), preferredTimescale: 600)) else { return nil }
                frame = result.image
            }
            let rep = NSBitmapImageRep(cgImage: frame)
            let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.78])
            if let data { try? data.write(to: thumb, options: .atomic) }
            return data
        }.value
        if let imageData, let image = NSImage(data: imageData) { thumbnails[clip.id] = image }
    }
    private func migratePreviousLibrary() async {
        let home = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let previous = LibraryRepository(root: home.appendingPathComponent("Flowall", isDirectory: true))
        if FileManager.default.fileExists(atPath: previous.manifest.path) {
            busy = true; message = "正在迁移流景视频库…"
            do {
                let destination = repository
                let count = try await Task.detached(priority: .userInitiated) {
                    try LibraryMigration.copyIfNeeded(from: previous, to: destination)
                }.value
                library = try repository.load()
                apply()
                loadThumbnails()
                message = "已迁移 \(count) 个视频，原视频库仍保留。"
            } catch {
                message = "迁移流景视频库失败：\(error.localizedDescription)"
            }
            busy = false
            return
        }
        await migrateLegacyLibrary()
    }
    private func migrateLegacyLibrary() async {
        let home = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let old = home.appendingPathComponent("VideoWallpaper", isDirectory: true)
        let manifest = old.appendingPathComponent("library.json")
        guard FileManager.default.fileExists(atPath: manifest.path),
              let data = try? Data(contentsOf: manifest),
              let legacy = try? JSONDecoder().decode(LegacyLibrary.self, from: data) else { return }
        busy = true; message = "正在迁移旧版视频库…"
        let media = old.appendingPathComponent("Media", isDirectory: true)
        var count = 0
        var migratedSelection: UUID?
        for entry in legacy.videos.reversed() {
            guard Library.safeFilename(entry.filename) else { continue }
            let url = media.appendingPathComponent(entry.filename)
            guard FileManager.default.fileExists(atPath: url.path),
                  (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else { continue }
            do {
                if try await importOne(url: url, title: entry.name) { count += 1 }
                if entry.id == legacy.selectedID { migratedSelection = library.activeID }
            }
            catch { message = "迁移 \(entry.name) 失败：\(error.localizedDescription)" }
        }
        if let migratedSelection { update { $0.activeID = migratedSelection } }
        busy = false
        if count > 0 { message = "已迁移 \(count) 个视频。旧版文件仍保留。" }
    }
}
