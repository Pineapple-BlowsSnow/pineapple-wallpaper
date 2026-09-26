import Foundation

public enum ScreenSaverConfig {
    public static let moduleIdentifier = "tech.pineapple.wallpaper.saver"
    public static let selectedClipKey = "selectedClipID"

    /// A missing explicit choice follows the current wallpaper. Missing media falls back to another clip.
    public static func candidates(in library: Library, selectedID: UUID?) -> [Clip] {
        var seen = Set<UUID>()
        let preferred = [selectedID, library.activeID].compactMap { $0 }
        let ordered = preferred.compactMap { id in library.clips.first { $0.id == id } } + library.clips
        return ordered.filter { seen.insert($0.id).inserted }
    }
}
