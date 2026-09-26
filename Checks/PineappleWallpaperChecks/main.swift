import Foundation
import AppKit
import PineappleWallpaperCore

struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}
func expect(_ condition: @autoclosure () throws -> Bool, _ label: String) throws {
    if try !condition() { throw CheckFailure(description: label) }
}
func expectsThrow(_ label: String, _ action: () throws -> Void) throws {
    do { try action(); throw CheckFailure(description: label) }
    catch is CheckFailure { throw CheckFailure(description: label) }
    catch { }
}
func makeClip(_ title: String = "Night", filename: String = "video.mp4") -> Clip {
    Clip(title: title, filename: filename, digest: String(repeating: "a", count: 64),
         bytes: 42, duration: 6, width: 1920, height: 1080)
}
@main struct PineappleWallpaperChecks {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("pineapple-wallpaper-checks-\(UUID().uuidString)")
        let repository = LibraryRepository(root: root)
        try repository.prepare()
        defer { try? FileManager.default.removeItem(at: root) }
        var count = 0
        func check(_ name: String, _ work: () throws -> Void) throws {
            try work(); count += 1; print("PASS \(name)")
        }
        try check("round trip selection and preferences") {
            var library = Library(); var clip = makeClip(); clip.favorite = true
            library.clips = [clip]; library.activeID = clip.id
            library.preferences.paused = true; library.preferences.scaleMode = .fit
            try repository.save(library)
            try expect(try repository.load() == library, "round trip")
        }
        try check("photos and legacy videos share a library safely") {
            let photo = Clip(title: "Portrait", filename: "portrait.png", digest: String(repeating: "b", count: 64),
                             bytes: 128, duration: 0, width: 1200, height: 1600, kind: .photo)
            var mixed = Library(); mixed.clips = [photo, makeClip()]; mixed.activeID = photo.id
            try repository.save(mixed)
            try expect(try repository.load() == mixed, "photo round trip")
            try expect(photo.isPhoto && mixed.clips[1].kind == .video, "media kinds")
            var old = Library(); old.schemaVersion = 1; old.clips = [makeClip()]
            var payload = try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as! [String: Any]
            var clips = payload["clips"] as! [[String: Any]]
            clips[0].removeValue(forKey: "kind")
            payload["clips"] = clips
            try JSONSerialization.data(withJSONObject: payload).write(to: repository.manifest)
            let recovered = try repository.load()
            try expect(recovered.schemaVersion == 1 && recovered.clips[0].kind == .video, "v1 video defaults")
            mixed.schemaVersion = 1
            try expectsThrow("v1 must reject photos") { try repository.save(mixed) }
        }
        try check("photo image decodes into wallpaper pixels") {
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 2,
                                          bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                          isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            let url = root.appendingPathComponent("photo.png")
            try bitmap.representation(using: .png, properties: [:])!.write(to: url)
            let dimensions = PhotoImageLoader.dimensions(at: url)
            try expect(dimensions?.width == 4 && dimensions?.height == 2, "photo dimensions")
            try expect(PhotoImageLoader.image(at: url)?.width == 4, "photo pixels")
        }
        try check("corrupt manifest is preserved") {
            let invalid = Data("not json".utf8)
            try invalid.write(to: repository.manifest)
            try expectsThrow("corrupt load must fail") { _ = try repository.load() }
            try expect(try Data(contentsOf: repository.manifest) == invalid, "original corrupt manifest")
        }
        try check("future schema cannot be overwritten") {
            var future = Library(); future.schemaVersion = 99
            try expectsThrow("future version") { try repository.save(future) }
        }
        try check("traversal and symlinks rejected") {
            for filename in ["../source.mp4", "/etc/passwd", "nested/video.mov", "..", "a\\b.mp4"] {
                try expectsThrow(filename) { _ = try repository.mediaURL(makeClip(filename: filename)) }
            }
            let source = root.appendingPathComponent("original.mp4")
            try Data("original".utf8).write(to: source)
            try FileManager.default.createSymbolicLink(at: repository.media.appendingPathComponent("video.mp4"), withDestinationURL: source)
            try expectsThrow("symlink") { _ = try repository.mediaURL(makeClip()) }
            try expect(try Data(contentsOf: source) == Data("original".utf8), "source untouched")
        }
        try check("remove chooses next then clears last") {
            var library = Library(); let first = makeClip(filename: "first.mp4"), second = makeClip(filename: "second.mp4")
            library.clips = [first, second]; library.activeID = first.id
            library.remove(first.id); try expect(library.activeID == second.id, "choose next")
            library.remove(second.id); try expect(library.activeID == nil && library.clips.isEmpty, "clear last")
        }
        try check("missing selection repairs") {
            var library = Library(); let video = makeClip(); library.clips = [video]; library.activeID = UUID()
            try expect(try library.validated().activeID == video.id, "repair")
        }
        try check("content hash detects same bytes across names") {
            let a = root.appendingPathComponent("a.mp4"), b = root.appendingPathComponent("b.mov")
            let data = Data(repeating: 13, count: 2_500_007)
            try data.write(to: a); try data.write(to: b)
            let first = try repository.stage(a), second = try repository.stage(b)
            try expect(first.digest == second.digest, "same hash")
            try expect(first.bytes == Int64(data.count), "exact size")
            try expect(try Data(contentsOf: first.url) == data, "copy exact")
        }
        try check("failed import cleans stage") {
            try expectsThrow("missing source") { _ = try repository.stage(root.appendingPathComponent("missing.mp4")) }
            try expect(try FileManager.default.contentsOfDirectory(atPath: repository.staging.path).count == 2, "only successful stages")
        }
        try check("search and favorite filter") {
            var library = Library(); var first = makeClip("流动的海"); first.favorite = true
            library.clips = [first, makeClip("Night Sky", filename: "night.mov")]
            try expect(library.matching("  NIGHT ", favoritesOnly: false).count == 1, "case insensitive")
            try expect(library.matching("海", favoritesOnly: true).first?.id == first.id, "favorite")
            try expect(library.matching("Night", favoritesOnly: true).isEmpty, "non favorite hidden")
        }
        try check("duplicate ids rejected") {
            var library = Library(); let video = makeClip(); library.clips = [video, video]
            try expectsThrow("duplicate id") { _ = try library.validated() }
        }
        try check("Flowall migration preserves library and originals") {
            let old = LibraryRepository(root: root.appendingPathComponent("old"))
            let new = LibraryRepository(root: root.appendingPathComponent("new"))
            try old.prepare()
            var previous = Library()
            var clip = makeClip("Saved wallpaper")
            clip.favorite = true
            previous.clips = [clip]
            previous.activeID = clip.id
            previous.preferences.scaleMode = .fit
            previous.preferences.paused = true
            let video = Data(repeating: 7, count: 42)
            try video.write(to: try old.mediaURL(clip))
            try Data("thumbnail".utf8).write(to: old.thumbnailURL(clip))
            try old.save(previous)
            try expect(try LibraryMigration.copyIfNeeded(from: old, to: new) == 1, "copied once")
            try expect(try new.load() == previous, "metadata unchanged")
            try expect(try Data(contentsOf: new.mediaURL(clip)) == video, "media copied")
            try expect(try Data(contentsOf: new.thumbnailURL(clip)) == Data("thumbnail".utf8), "thumbnail copied")
            try expect(try Data(contentsOf: old.mediaURL(clip)) == video, "original untouched")
            try expect(try LibraryMigration.copyIfNeeded(from: old, to: new) == 0, "idempotent")
        }
        try check("screen saver choice follows wallpaper and falls back") {
            let first = makeClip("First", filename: "first.mp4")
            let second = makeClip("Second", filename: "second.mp4")
            let third = makeClip("Third", filename: "third.mp4")
            var library = Library()
            library.clips = [first, second, third]
            library.activeID = second.id
            try expect(ScreenSaverConfig.candidates(in: library, selectedID: nil).map(\.id) ==
                       [second.id, first.id, third.id], "follow active")
            try expect(ScreenSaverConfig.candidates(in: library, selectedID: third.id).map(\.id) ==
                       [third.id, second.id, first.id], "explicit choice first")
            try expect(ScreenSaverConfig.candidates(in: library, selectedID: UUID()).map(\.id) ==
                       [second.id, first.id, third.id], "removed choice falls back")
        }
        try check("screen saver photo choice survives a separate library read") {
            let video = makeClip("Video", filename: "video.mp4")
            let photo = Clip(title: "Photo", filename: "photo.png", digest: String(repeating: "b", count: 64),
                             bytes: 100, duration: 0, width: 100, height: 100, kind: .photo)
            var library = Library()
            library.clips = [video, photo]
            library.activeID = video.id
            library.screenSaverID = photo.id
            library.screenSaverSelectionConfigured = true
            try repository.save(library)
            let saverRead = try repository.load()
            try expect(ScreenSaverConfig.candidates(in: saverRead, selectedID: saverRead.screenSaverID).first?.id == photo.id,
                       "photo selected across processes")
            var legacy = try JSONSerialization.jsonObject(with: Data(contentsOf: repository.manifest)) as! [String: Any]
            legacy.removeValue(forKey: "screenSaverID")
            legacy.removeValue(forKey: "screenSaverSelectionConfigured")
            try JSONSerialization.data(withJSONObject: legacy).write(to: repository.manifest)
            try expect(try repository.load().screenSaverSelectionConfigured == false, "old library decodes for migration")
        }
        print("\(count) checks passed")
    }
}
