# 菠萝壁纸 Pineapple Wallpaper
> 完整源码现以 [ZIP 压缩包](PineappleWallpaper-source-0.4.0-reviewed.zip) 提供，内含 29 个文件。下载并解压后，在解压目录运行下方构建命令；网页中的源码目录尚未全部展开。


**让喜欢的画面，留在你的 Mac 桌面。** 菠萝壁纸是一款由 Pineapple Tech 发起的开源 macOS 壁纸与屏幕保护程序。把自己的照片和视频加入本地图库，就能一键切换桌面画面，也能让屏保跟随当前壁纸或单独选片。它不需要账号，不上传素材，也没有广告和第三方依赖。

**作者：Pineapple-Tech 菠萝吹雪。** 项目使用作者提供的 [Pineapple Tech 标志](Resources/Brand/PineappleTech.jpg)。

支持 JPEG、PNG、HEIC、TIFF 照片，以及 macOS 可播放的 MP4、MOV 视频。照片静态显示，视频静音循环播放。

> 当前阶段：可运行的开源初版，适合在自己的 Mac 上构建与使用。尚未发布经过 Apple 公证的安装包。

适合想用自己的影像装点桌面、又希望文件始终留在本机的 Mac 用户。项目介绍文案见 [docs/PROJECT_INTRO.md](docs/PROJECT_INTRO.md)。

## 功能

- 壁纸库：照片和视频可批量导入，并支持缩略图、搜索、收藏、重命名、内容哈希去重。
- 桌面显示：照片静态显示、视频静音循环；支持所有连接的显示器，画面可填满或完整显示。
- 屏保：使用同一图库，跟随当前壁纸或单独选片；照片静态显示，视频静音循环。
- 快速控制：菜单栏切换，窗口内可暂停/继续视频，`⌘O` 添加照片或视频，`⌘P` 暂停/继续视频。
- 节能：低电量模式下可自动暂停，Mac 进入睡眠时暂停。
- 本地保存：照片和视频复制到 `~/Library/Application Support/PineappleWallpaper/Media/`；移除时只把图库副本移到废纸篓，原文件不动。
- 旧版迁移：首次启动优先复制 `~/Library/Application Support/Flowall/` 的图库，保留视频、当前选择、收藏和播放设置；没有该图库时，再读取更早的 `VideoWallpaper` 图库。原文件均保留。

## 构建

需要 macOS 15+、Apple Swift 6+ 和 Xcode 命令行工具。项目没有外部 Swift 包依赖。

```bash
./scripts/build-app.sh
open dist/PineappleWallpaper.app
```

构建产物在 `dist/PineappleWallpaper.app` 与 `dist/PineappleWallpaper.saver`；应用内也包含屏保插件。脚本创建应用图标并进行本机 ad-hoc 签名。源码构建版未公证；在另一台 Mac 上分发时，需要用自己的 Apple Developer 身份签名、公证。开发时也可运行：

```bash
swift build
./scripts/check.sh
```

发布本地压缩包时，先运行 `./scripts/build-app.sh`，再运行 `./scripts/package-release.sh`；脚本会生成应用、独立屏保和源码三个 ZIP，不会把本机图库打包进去。

如果仅安装了 Command Line Tools 且默认 macOS SDK 与 Swift 编译器版本不匹配，可先设置 `SDKROOT` 为已安装且匹配的 SDK 路径；构建脚本会在检测到本机 macOS 15.4 SDK 时使用它。

## 使用

1. 首次打开点击「添加照片或视频」，选择一个或多个受支持的文件。
2. 点击缩略图切换壁纸；右键缩略图可收藏、重命名或移除。
3. 点击左上角设置按钮选择画面适配方式、低电量模式行为。
4. 关闭窗口后壁纸继续播放，菜单栏按钮可重新打开图库或退出。
5. 点击侧边栏「屏幕保护程序」，选择「跟随当前壁纸」或单独选择照片、视频，再点「安装屏幕保护程序…」。在系统设置的「壁纸 → 屏幕保护程序 → 其他」中选用「菠萝壁纸」，并设置启动时间。系统缓存旧名称时，可能显示为 `PineappleWallpaperSaver`。也可手动将 `dist/PineappleWallpaper.saver` 放入 `~/Library/Screen Savers/`，然后在系统设置中选用。

图库目录包括 `library.json`、媒体副本、缩略图和导入暂存文件。旧版纯视频图库会继续读取；导入第一张照片后，记录格式升级为版本 2。请勿把这个目录、个人照片/视频或应用的 `dist/` 目录提交到公开仓库。确认自己有权使用和分发任何打包的素材。

## 隐私与限制

照片和视频只在本地读取和显示。项目没有网络请求或遥测代码。源文件路径不会保存在新版图库中，媒体会复制到应用数据目录，因此需要额外磁盘空间。当前多个显示器播放同一视频，各显示器从各自的播放器开始播放，切换后可能有少量不同步。屏保每次启动时读取当时的图库与选择；已运行的屏保需要退出并重新启动才会更新。不同机型与视频编码的流畅度取决于 macOS 的硬件解码能力。没有开机自启功能。

遇到损坏或未来版本的图库文件，应用会停止写入并提示错误，避免覆盖数据。建议先备份 `library.json` 和 `Media/`，再报告问题。

## 参与开发

参见 [CONTRIBUTING.md](CONTRIBUTING.md) 和 [docs/architecture.md](docs/architecture.md)。问题反馈请描述 macOS 版本、媒体格式/分辨率、复现步骤和日志，不要上传含有个人内容的照片或视频。代码以 MIT 许可证开放；Pineapple Tech 标志和字标单独保留权利，参见 [BRAND.md](BRAND.md)。用户导入的照片和视频不属于本项目的开源素材。

---

**English:** Pineapple Wallpaper is an offline macOS photo and video wallpaper and screen saver app with a local library, menu bar controls, search, favorites, duplicate detection, and power aware video playback. Import JPEG, PNG, HEIC, TIFF, MP4, or MOV files. Build with `./scripts/build-app.sh` on macOS 15+; open `dist/PineappleWallpaper.app` and install the included `PineappleWallpaper.saver` from its screen saver panel. Run `./scripts/check.sh` for the bundled checks. Personal media is never included in the source repository. See the Chinese sections above for complete usage and limitations.
