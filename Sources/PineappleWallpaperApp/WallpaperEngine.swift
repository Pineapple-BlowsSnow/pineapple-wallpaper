import AppKit
import AVFoundation
import PineappleWallpaperCore

final class VideoCanvas: NSView {
    let playerLayer = AVPlayerLayer()
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.addSublayer(playerLayer)
    }
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }
    override func layout() { super.layout(); playerLayer.frame = bounds }
}

final class PhotoCanvas: NSView {
    private let photoLayer = CALayer()
    init(frame: NSRect, image: CGImage, scaleMode: ScaleMode) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        photoLayer.contents = image
        photoLayer.contentsGravity = scaleMode == .fill ? .resizeAspectFill : .resizeAspect
        photoLayer.masksToBounds = true
        layer?.addSublayer(photoLayer)
    }
    required init?(coder: NSCoder) { fatalError("Use init(frame:image:scaleMode:)") }
    override func layout() { super.layout(); photoLayer.frame = bounds }
}

@MainActor
final class WallpaperEngine {
    private var windows: [NSWindow] = []
    private var players: [AVQueuePlayer] = []
    private var loopers: [AVPlayerLooper] = []
    private(set) var activeURL: URL?
    private(set) var activeKind: MediaKind?
    private(set) var paused = false
    private(set) var scaleMode: ScaleMode = .fill
    private(set) var previewImage: NSImage?
    var previewPlayer: AVQueuePlayer? { players.first }

    func apply(url: URL?, kind: MediaKind?, scaleMode: ScaleMode, paused: Bool) {
        if activeURL == url, activeKind == kind, self.scaleMode == scaleMode {
            setPaused(paused); return
        }
        clear()
        self.activeURL = url; self.activeKind = kind; self.scaleMode = scaleMode; self.paused = paused
        guard let url, let kind else { return }
        let photo = kind == .photo ? PhotoImageLoader.image(at: url) : nil
        if kind == .photo {
            guard let photo else { return }
            previewImage = NSImage(cgImage: photo, size: NSSize(width: photo.width, height: photo.height))
        }
        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                                  backing: .buffered, defer: false)
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.ignoresMouseEvents = true
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            let frame = NSRect(origin: .zero, size: screen.frame.size)
            if let photo {
                window.contentView = PhotoCanvas(frame: frame, image: photo, scaleMode: scaleMode)
            } else {
                let canvas = VideoCanvas(frame: frame)
                let player = AVQueuePlayer()
                player.isMuted = true
                player.actionAtItemEnd = .none
                let looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
                canvas.playerLayer.videoGravity = scaleMode == .fill ? .resizeAspectFill : .resizeAspect
                canvas.playerLayer.player = player
                window.contentView = canvas
                if !paused { player.play() }
                players.append(player); loopers.append(looper)
            }
            window.orderFrontRegardless()
            windows.append(window)
        }
    }
    func refreshScreens() {
        let url = activeURL, kind = activeKind, mode = scaleMode, pause = paused
        clear(); apply(url: url, kind: kind, scaleMode: mode, paused: pause)
    }
    func setPaused(_ value: Bool) {
        paused = value
        for player in players { value ? player.pause() : player.play() }
    }
    func clear() {
        for player in players { player.pause() }
        for window in windows { window.orderOut(nil) }
        windows.removeAll(); loopers.removeAll(); players.removeAll()
        activeURL = nil
        activeKind = nil
        previewImage = nil
    }
}
