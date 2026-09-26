import AppKit
import AVFoundation
import Darwin
import ScreenSaver

@objc(PineappleWallpaperSaverView)
final class PineappleWallpaperSaverView: ScreenSaverView {
    private let videoLayer = AVPlayerLayer()
    private let photoLayer = CALayer()
    private let statusLabel = NSTextField(labelWithString: "请先在菠萝壁纸中添加照片或视频")
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var itemObserver: NSKeyValueObservation?
    private var candidates: [(clip: Clip, url: URL)] = []
    private var candidateIndex = 0
    private var scaleMode: ScaleMode = .fill

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        photoLayer.masksToBounds = true
        layer?.addSublayer(photoLayer)
        videoLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(videoLayer)
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: isPreview ? 11 : 20, weight: .medium)
        statusLabel.alignment = .center
        statusLabel.backgroundColor = .clear
        addSubview(statusLabel)
    }

    override func layout() {
        super.layout()
        photoLayer.frame = bounds
        videoLayer.frame = bounds
        statusLabel.frame = NSRect(x: 16, y: (bounds.height - 36) / 2,
                                   width: max(0, bounds.width - 32), height: 36)
    }

    override func startAnimation() {
        super.startAnimation()
        stopPlayback()
        // The system hosts legacy screen savers in its own container. Its
        // applicationSupportDirectory is not the wallpaper app's library.
        guard let account = getpwuid(getuid()) else {
            statusLabel.stringValue = "无法定位当前用户的菠萝壁纸图库"
            statusLabel.isHidden = false
            return
        }
        let home = URL(fileURLWithPath: String(cString: account.pointee.pw_dir), isDirectory: true)
        let root = home.appendingPathComponent("Library/Application Support/PineappleWallpaper", isDirectory: true)
        let repository = LibraryRepository(root: root)
        guard FileManager.default.fileExists(atPath: repository.manifest.path) else {
            statusLabel.stringValue = "屏保无法找到菠萝壁纸图库"
            statusLabel.isHidden = false
            return
        }
        guard let library = try? repository.load() else {
            statusLabel.stringValue = "无法读取菠萝壁纸图库"
            statusLabel.isHidden = false
            return
        }
        candidates = ScreenSaverConfig.candidates(in: library, selectedID: library.screenSaverID)
            .compactMap { clip in
                guard let url = try? repository.mediaURL(clip),
                      FileManager.default.fileExists(atPath: url.path) else { return nil }
                return (clip, url)
            }
        guard !candidates.isEmpty else {
            statusLabel.stringValue = "请先在菠萝壁纸中添加照片或视频"
            statusLabel.isHidden = false
            return
        }
        scaleMode = library.preferences.scaleMode
        playNextCandidate()
    }

    private func playNextCandidate() {
        clearPlayer()
        photoLayer.contents = nil
        guard candidateIndex < candidates.count else {
            statusLabel.stringValue = "画面无法显示，请在菠萝壁纸中选择其他文件"
            statusLabel.isHidden = false
            return
        }
        let candidate = candidates[candidateIndex]
        candidateIndex += 1
        if candidate.clip.isPhoto {
            guard let image = PhotoImageLoader.image(at: candidate.url) else {
                playNextCandidate()
                return
            }
            photoLayer.contentsGravity = scaleMode == .fill ? .resizeAspectFill : .resizeAspect
            photoLayer.contents = image
            videoLayer.isHidden = true
            statusLabel.isHidden = true
            return
        }
        videoLayer.isHidden = false
        let item = AVPlayerItem(url: candidate.url)
        let playback = AVPlayer(playerItem: item)
        playback.isMuted = true
        playback.actionAtItemEnd = .none
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak playback] _ in
            playback?.seek(to: .zero) { completed in if completed { playback?.play() } }
        }
        player = playback
        itemObserver = item.observe(\.status, options: [.new]) { [weak self, weak item] _, _ in
            DispatchQueue.main.async { [weak self, weak item] in
                guard let self, let item, self.player?.currentItem === item else { return }
                if item.status == .failed { self.playNextCandidate() }
            }
        }
        videoLayer.videoGravity = scaleMode == .fill ? .resizeAspectFill : .resizeAspect
        videoLayer.player = playback
        statusLabel.isHidden = true
        playback.play()
        if item.status == .failed { playNextCandidate() }
    }

    override func stopAnimation() {
        stopPlayback()
        super.stopAnimation()
    }

    private func stopPlayback() {
        clearPlayer()
        photoLayer.contents = nil
        candidates = []
        candidateIndex = 0
    }

    private func clearPlayer() {
        itemObserver = nil
        player?.pause()
        videoLayer.player = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        player = nil
    }
}
