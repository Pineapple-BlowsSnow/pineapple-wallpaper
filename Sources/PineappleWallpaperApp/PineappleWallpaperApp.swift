import AppKit
import AVKit
import SwiftUI
import PineappleWallpaperCore

private enum Theme {
    static let base = Color(red: 0.045, green: 0.085, blue: 0.11)
    static let panel = Color(red: 0.07, green: 0.13, blue: 0.17)
    static let tile = Color(red: 0.11, green: 0.19, blue: 0.23)
    static let leaf = Color(red: 0.36, green: 0.81, blue: 0.62)
    static let gold = Color(red: 0.84, green: 0.71, blue: 0.43)
}

private struct BrandMark: View {
    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: "BrandMark", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "play.rectangle.fill").foregroundStyle(Theme.leaf)
            }
        }
        .frame(width: 42, height: 42)
        .accessibilityLabel("Pineapple Tech")
    }
}

private struct Preview: NSViewRepresentable {
    let player: AVQueuePlayer?
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        view.wantsLayer = true
        view.layer?.cornerRadius = 14
        view.layer?.masksToBounds = true
        return view
    }
    func updateNSView(_ view: AVPlayerView, context: Context) { view.player = player }
}

private struct MediaCard: View {
    let clip: Clip
    let image: NSImage?
    let selected: Bool
    let select: () -> Void
    let favorite: () -> Void
    let rename: () -> Void
    let remove: () -> Void
    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 0) {
                GeometryReader { geometry in
                    ZStack {
                        Rectangle().fill(LinearGradient(colors: [Theme.tile, Theme.panel], startPoint: .topLeading, endPoint: .bottomTrailing))
                        if let image {
                            Image(nsImage: image).resizable().scaledToFill()
                                .frame(width: geometry.size.width, height: 105).clipped()
                        } else {
                            Image(systemName: clip.isPhoto ? "photo.fill" : "play.rectangle.fill")
                                .font(.system(size: 30, weight: .ultraLight)).foregroundStyle(.white.opacity(0.3))
                        }
                        if selected {
                            VStack { HStack { Spacer()
                                Text(clip.isPhoto ? "当前壁纸" : "正在播放").font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 9).padding(.vertical, 5)
                                    .background(Theme.gold, in: Capsule()).foregroundStyle(Theme.base)
                            }; Spacer() }.padding(9)
                        }
                    }.frame(width: geometry.size.width, height: 105)
                }.frame(height: 105).clipped()
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 4) {
                        Text(clip.title).font(.system(size: 12, weight: .medium)).foregroundStyle(.white).lineLimit(1)
                        Spacer(minLength: 2)
                        if clip.favorite { Image(systemName: "heart.fill").font(.system(size: 10)).foregroundStyle(Theme.leaf) }
                    }
                    Text("\(clip.width) × \(clip.height) · \(clip.isPhoto ? "照片" : VideoLibrary.clock(clip.duration))")
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.49))
                }.padding(.horizontal, 10).padding(.vertical, 9)
            }
            .frame(maxWidth: .infinity)
            .background(Theme.tile, in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Theme.gold : .white.opacity(0.06), lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("设为壁纸", action: select)
            Button(clip.favorite ? "取消收藏" : "加入收藏", action: favorite)
            Button("重命名…", action: rename)
            Divider()
            Button("从图库移除", role: .destructive, action: remove)
        }
        .accessibilityLabel("\(clip.title)，\(selected ? "当前壁纸" : "点击设为壁纸")")
    }
}

private struct SettingsPanel: View {
    @ObservedObject var model: VideoLibrary
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("播放设置").font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                Text("画面适配").font(.caption).foregroundStyle(.secondary)
                Picker("画面适配", selection: Binding(get: { model.library.preferences.scaleMode }, set: { model.setScale($0) })) {
                    Text("填满屏幕").tag(ScaleMode.fill)
                    Text("完整显示").tag(ScaleMode.fit)
                }.labelsHidden().pickerStyle(.segmented)
                Text("填满可能裁切画面边缘；完整显示可能有黑边。")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Toggle("低电量模式下暂停", isOn: Binding(get: { model.library.preferences.pauseInLowPowerMode }, set: { model.setPowerPause($0) }))
                .font(.system(size: 12))
            Divider()
            Text("本地图库：\(ByteCountFormatter.string(fromByteCount: model.library.totalBytes, countStyle: .file))")
                .font(.caption).foregroundStyle(.secondary)
            Button("打开图库文件夹") { NSWorkspace.shared.activateFileViewerSelecting([model.repository.root]) }
                .font(.system(size: 12))
            Text("照片与视频只在本机使用。关闭窗口后可从菜单栏继续控制。")
                .font(.caption2).foregroundStyle(.secondary)
        }.padding(19).frame(width: 290).background(Theme.panel)
    }
}

private struct ScreenSaverPanel: View {
    @ObservedObject var model: VideoLibrary
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                BrandMark()
                VStack(alignment: .leading, spacing: 3) {
                    Text("屏幕保护程序").font(.system(size: 21, weight: .semibold))
                    Text("使用同一图库中的照片或视频；视频静音循环播放。")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            Divider()
            Picker("屏保画面", selection: Binding(get: { model.screenSaverID }, set: { model.setScreenSaverClip($0) })) {
                Text("跟随当前壁纸").tag(nil as UUID?)
                ForEach(model.library.clips) { clip in
                    Text(clip.title).tag(Optional(clip.id))
                }
            }
            .disabled(model.library.clips.isEmpty)
            Text(model.library.clips.isEmpty ? "先添加照片或视频，屏保即可使用同一图库。" :
                 "下次启动屏保时播放：\(model.screenSaverClip?.title ?? model.active?.title ?? "暂无画面")")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("安装屏幕保护程序…") { model.installScreenSaver() }
                    .buttonStyle(.borderedProminent).tint(Theme.leaf)
                Button("完成") { dismiss() }.buttonStyle(.bordered)
            }
            Text("安装后，在系统设置 → 墙纸 → 屏幕保护程序 → 其他中选择「菠萝壁纸」（旧缓存可能显示 PineappleWallpaperSaver）。")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            if !model.message.isEmpty { Text(model.message).font(.caption).foregroundStyle(.orange) }
        }
        .padding(28)
        .frame(width: 510)
        .background(Theme.panel)
    }
}

private struct LibraryWindow: View {
    @ObservedObject var model: VideoLibrary
    @State private var showSettings = false
    @State private var showScreenSaver = false
    @State private var renaming: Clip?
    @State private var newTitle = ""
    @State private var removing: Clip?
    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 306)
            Rectangle().fill(.white.opacity(0.08)).frame(width: 1)
            detail
        }
        .background(Theme.base)
        .frame(minWidth: 920, minHeight: 650)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showScreenSaver) { ScreenSaverPanel(model: model) }
        .alert("重命名画面", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("画面名称", text: $newTitle)
            Button("取消", role: .cancel) { renaming = nil }
            Button("保存") { if let clip = renaming { model.rename(clip, to: newTitle) }; renaming = nil }
        } message: { Text("只修改图库显示名称。") }
        .confirmationDialog("从图库移除？", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
            Button("移除并把副本移到废纸篓", role: .destructive) {
                if let clip = removing { model.remove(clip) }; removing = nil
            }
            Button("取消", role: .cancel) { removing = nil }
        } message: { Text("原始文件不会删除；图库中的副本可以从废纸篓恢复。") }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                BrandMark()
                VStack(alignment: .leading, spacing: 1) {
                    Text("菠萝壁纸").font(.system(size: 19, weight: .bold))
                    Text("PINEAPPLE TECH").font(.system(size: 9, weight: .medium, design: .rounded)).tracking(1.2).foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Button { showSettings.toggle() } label: { Image(systemName: "slider.horizontal.3").font(.system(size: 15)) }
                    .buttonStyle(.plain).foregroundStyle(.white.opacity(0.7))
                    .popover(isPresented: $showSettings, arrowEdge: .trailing) { SettingsPanel(model: model) }
                    .accessibilityLabel("播放设置")
            }.padding(.bottom, 29)
            Text("我的壁纸库").font(.system(size: 21, weight: .semibold))
            Text("把喜欢的画面留在桌面。")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.5)).padding(.top, 5)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.4))
                TextField("搜索照片或视频", text: $model.search).textFieldStyle(.plain).font(.system(size: 12))
                if !model.search.isEmpty {
                    Button { model.search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }.padding(10).background(Theme.tile, in: RoundedRectangle(cornerRadius: 9)).padding(.top, 21)
            HStack {
                Text("\(model.library.clips.count) 个画面").font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
                Spacer()
                Button { model.favoritesOnly.toggle() } label: {
                    Label("收藏", systemImage: model.favoritesOnly ? "heart.fill" : "heart")
                        .font(.system(size: 11)).foregroundStyle(model.favoritesOnly ? Theme.leaf : .white.opacity(0.6))
                }.buttonStyle(.plain)
            }.padding(.top, 19).padding(.bottom, 11)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 11), GridItem(.flexible(), spacing: 11)], spacing: 11) {
                    ForEach(model.visible) { clip in
                        MediaCard(clip: clip, image: model.thumbnails[clip.id], selected: clip.id == model.library.activeID,
                                  select: { model.select(clip) }, favorite: { model.toggleFavorite(clip) },
                                  rename: { newTitle = clip.title; renaming = clip }, remove: { removing = clip })
                    }
                }
                if model.visible.isEmpty {
                    VStack(spacing: 11) {
                        Image(systemName: model.library.clips.isEmpty ? "rectangle.stack.badge.plus" : "magnifyingglass")
                            .font(.system(size: 32, weight: .ultraLight)).foregroundStyle(Theme.leaf)
                        Text(model.library.clips.isEmpty ? "图库还是空的" : "没有找到画面").font(.system(size: 13, weight: .medium))
                        Text(model.library.clips.isEmpty ? "添加照片或视频开始。" : "换个关键词试试。")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                    }.frame(maxWidth: .infinity).padding(.top, 70)
                }
            }.scrollIndicators(.hidden)
            Spacer(minLength: 12)
            Button(action: model.addMedia) {
                HStack { Image(systemName: "plus"); Text(model.busy ? "正在导入…" : "添加照片或视频"); Spacer(); Text("⌘O").opacity(0.5) }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(12).frame(maxWidth: .infinity)
                    .background(Theme.leaf, in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(Theme.base)
            }.buttonStyle(.plain).disabled(model.busy || model.loadError != nil)
            Button { showScreenSaver = true } label: {
                HStack { Image(systemName: "display"); Text("屏幕保护程序"); Spacer(); Image(systemName: "chevron.right") }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.gold)
                    .padding(.vertical, 11)
            }.buttonStyle(.plain)
        }.padding(22).background(Theme.panel)
    }
    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("当前桌面").font(.system(size: 11, weight: .semibold)).tracking(1.4).foregroundStyle(Theme.leaf)
                    Text(model.active?.title ?? "等待第一张照片或视频").font(.system(size: 26, weight: .bold)).lineLimit(1)
                }
                Spacer()
                Label(model.playerState.isEmpty ? "就绪" : model.playerState,
                      systemImage: model.effectivePause ? "pause.circle.fill" : "circle.fill")
                    .font(.system(size: 11)).foregroundStyle(model.effectivePause ? .orange : Theme.gold)
                    .padding(.horizontal, 11).padding(.vertical, 7).background(Theme.tile, in: Capsule())
            }.padding(.bottom, 23)
            ZStack {
                RoundedRectangle(cornerRadius: 17)
                    .fill(LinearGradient(colors: [Theme.tile, Theme.base], startPoint: .topLeading, endPoint: .bottomTrailing))
                if let photo = model.previewPhoto {
                    Image(nsImage: photo).resizable()
                        .aspectRatio(contentMode: model.library.preferences.scaleMode == .fill ? .fill : .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else if model.player != nil { Preview(player: model.player).clipShape(RoundedRectangle(cornerRadius: 16)) }
                else {
                    VStack(spacing: 13) {
                        Image(systemName: "play.rectangle.fill").font(.system(size: 54, weight: .ultraLight)).foregroundStyle(Theme.leaf.opacity(0.65))
                        Text("你的桌面，就是一块画布").font(.system(size: 17, weight: .medium))
                        Text("选择左侧画面，或添加照片和视频。")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.08)))
            .padding(.bottom, 21)
            if model.canPause { HStack {
                Text(model.elapsedText).monospacedDigit()
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.1))
                        Capsule().fill(Theme.leaf)
                            .frame(width: max(0, proxy.size.width * min(1, model.active.map { model.elapsed / $0.duration } ?? 0)))
                    }
                }.frame(height: 4)
                Text(model.durationText).monospacedDigit()
            }.font(.system(size: 11)).foregroundStyle(.white.opacity(0.45)).padding(.bottom, 21) }
            HStack(spacing: 12) {
                if model.canPause { Button { model.togglePause() } label: {
                    Label(model.library.preferences.paused ? "继续播放" : "暂停播放",
                          systemImage: model.library.preferences.paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 13, weight: .medium)).frame(minWidth: 100).padding(.vertical, 10)
                }.buttonStyle(.borderedProminent).tint(Theme.leaf) }
                if let active = model.active {
                    Button { model.toggleFavorite(active) } label: {
                        Label(active.favorite ? "已收藏" : "收藏", systemImage: active.favorite ? "heart.fill" : "heart")
                    }.buttonStyle(.bordered)
                    Button { newTitle = active.title; renaming = active } label: { Image(systemName: "pencil") }
                        .buttonStyle(.bordered).help("重命名")
                    Spacer()
                    Button { removing = active } label: { Image(systemName: "trash") }
                        .buttonStyle(.bordered).help("从图库移除")
                }
            }
            Spacer(minLength: 15)
            HStack(spacing: 12) {
                Image(systemName: "lock.shield").font(.system(size: 16)).foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 3) {
                    Text("只在这台 Mac 播放").font(.system(size: 12, weight: .medium))
                    Text("照片和视频不会上传；视频播放时静音循环。")
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.49))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14).background(Theme.panel, in: RoundedRectangle(cornerRadius: 11))
            if !model.message.isEmpty {
                Text(model.message).font(.system(size: 11))
                    .foregroundStyle(model.loadError == nil ? .white.opacity(0.5) : .orange)
                    .lineLimit(2).padding(.top, 10)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private final class PineappleWallpaperLifecycle: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        for delay in [0.3, 0.8, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self.showLibrary() }
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showLibrary()
        return true
    }
    private func showLibrary() {
        guard let window = NSApp.windows.first(where: { $0.title.contains("菠萝壁纸") }) else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct PineappleWallpaperApp: App {
    @NSApplicationDelegateAdaptor(PineappleWallpaperLifecycle.self) private var lifecycle
    @StateObject private var model = VideoLibrary()
    @Environment(\.openWindow) private var openWindow
    var body: some Scene {
        Window("菠萝壁纸 · Pineapple Wallpaper", id: "library") { LibraryWindow(model: model) }
            .defaultSize(width: 1050, height: 690)
            .defaultLaunchBehavior(.presented)
            .commands {
                CommandGroup(replacing: .newItem) { Button("添加照片或视频…") { model.addMedia() }.keyboardShortcut("o") }
                CommandMenu("播放") {
                    Button(model.library.preferences.paused ? "继续播放" : "暂停播放") { model.togglePause() }
                        .keyboardShortcut("p").disabled(!model.canPause)
                }
            }
        MenuBarExtra("菠萝壁纸", systemImage: "play.rectangle.fill") {
            Button("打开壁纸库") { openWindow(id: "library") }
            Button("添加照片或视频…") { model.addMedia() }
            Divider()
            if model.library.clips.isEmpty { Text("尚无画面") }
            ForEach(model.library.clips.prefix(8)) { clip in
                Button { model.select(clip) } label: {
                    Label(clip.title, systemImage: clip.id == model.library.activeID ? "checkmark" : (clip.isPhoto ? "photo" : "play"))
                }
            }
            Divider()
            Button(model.library.preferences.paused ? "继续播放" : "暂停播放") { model.togglePause() }
                .disabled(!model.canPause)
            Button("退出菠萝壁纸") { NSApplication.shared.terminate(nil) }
        }.menuBarExtraStyle(.menu)
    }
}
