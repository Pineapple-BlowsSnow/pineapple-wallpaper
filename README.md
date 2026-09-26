<h1 align="center">菠萝壁纸 · Pineapple Wallpaper</h1>

<p align="center"><strong>把喜欢的画面，留在 Mac 桌面。</strong></p>

<p align="center">
  macOS 15+ &nbsp; · &nbsp; Swift 原生应用 &nbsp; · &nbsp; 本地图库 &nbsp; · &nbsp; MIT 开源代码
</p>

<p align="center">
  <a href="#三步开始">开始使用</a> ·
  <a href="#功能一览">功能</a> ·
  <a href="#构建">从源码构建</a> ·
  <a href="#屏保选图排查">屏保选图排查</a> ·
  <a href="#参与开发">参与开发</a> ·
  <a href="#english">English</a>
</p>

一张喜欢的照片，一段想反复看的风景。菠萝壁纸把它们放进同一个本地图库，让你随时切换桌面，也能为屏幕保护程序单独选择画面。

照片静态显示，视频静音循环播放。无需账号，没有广告，素材保存在自己的 Mac 上。

> **项目状态**：当前版本 0.4.2，提供源码构建方式，尚无经过 Apple 公证的公开安装包。

## 功能一览

| 你想做什么 | 菠萝壁纸如何完成 |
| --- | --- |
| 用自己的照片或视频做壁纸 | 批量导入，点击缩略图即可切换；支持 JPEG、PNG、HEIC、TIFF，以及 macOS 可解码的 MP4、MOV |
| 给屏保选另一张照片 | 选择「跟随当前壁纸」，或独立指定图库中的照片、视频 |
| 整理越来越多的素材 | 搜索、收藏、重命名、内容哈希去重 |
| 调整画面显示 | 选择填满屏幕或完整显示；支持连接的多个显示器 |
| 快速控制播放 | 菜单栏打开图库，`⌘O` 导入，`⌘P` 暂停或继续视频 |
| 减少闲置时的播放 | 睡眠时暂停，可选择在低电量模式下自动暂停 |
| 保留自己的原文件 | 导入时创建图库副本；移除只把副本移到废纸篓 |

## 三步开始

1. **构建并打开**：按下方命令生成应用，打开 `dist/PineappleWallpaper.app`。
2. **加入喜欢的画面**：点击「添加照片或视频」，再点击图库缩略图设为壁纸。
3. **设置屏保**：打开侧边栏「屏幕保护程序」，选择画面，点击「安装屏幕保护程序…」，然后在 macOS 系统设置中选中菠萝壁纸屏保。

## 桌面与屏保，各有自己的画面

桌面显示图库中当前选中的壁纸。屏保默认跟随它；在屏保面板指定另一份素材后，切换桌面不会改变该屏保选择。屏保在下次启动时读取选择，已运行的屏保需要退出后重新启动。

```text
导入照片 / 视频 → 本地图库 → 当前壁纸 → Mac 桌面
                          └→ 屏保选择 → 系统屏幕保护程序
                             跟随壁纸 / 独立选片
```

## 构建

需要 macOS 15+、Apple Swift 6+ 和 Xcode 命令行工具。项目没有外部 Swift 包依赖。

```bash
bash scripts/build-app.sh
open dist/PineappleWallpaper.app
```

构建产物在 `dist/PineappleWallpaper.app` 与 `dist/PineappleWallpaper.saver`；应用内也包含屏保插件。脚本创建应用图标并进行本机 ad-hoc 签名。源码构建版未公证；在另一台 Mac 上分发时，需要用自己的 Apple Developer 身份签名、公证。开发时也可运行：

```bash
swift build
bash scripts/check.sh
```

发布本地压缩包时，先运行 `bash scripts/build-app.sh`，再运行 `bash scripts/package-release.sh`；脚本会生成应用、独立屏保和源码三个 ZIP，不会把本机图库打包进去。

如果仅安装了 Command Line Tools 且默认 macOS SDK 与 Swift 编译器版本不匹配，可先设置 `SDKROOT` 为已安装且匹配的 SDK 路径；构建脚本会在检测到本机 macOS 15.4 SDK 时使用它。

## 使用

1. 首次打开点击「添加照片或视频」，选择一个或多个受支持的文件。
2. 点击缩略图切换壁纸；右键缩略图可收藏、重命名或移除。
3. 点击左上角设置按钮选择画面适配方式、低电量模式行为。
4. 关闭窗口后壁纸继续播放，菜单栏按钮可重新打开图库或退出。
5. 点击侧边栏「屏幕保护程序」，选择「跟随当前壁纸」或单独选择照片、视频，再点「安装屏幕保护程序…」。在系统设置的「壁纸 → 屏幕保护程序 → 其他」中选用「菠萝壁纸」，并设置启动时间。系统缓存旧名称时，可能显示为 `PineappleWallpaperSaver`。也可手动将 `dist/PineappleWallpaper.saver` 放入 `~/Library/Screen Savers/`，然后在系统设置中选用。

图库目录包括 `library.json`、媒体副本、缩略图和导入暂存文件。旧版纯视频图库会继续读取；导入第一张照片后，记录格式升级为版本 2。请勿把这个目录、个人照片/视频或应用的 `dist/` 目录提交到公开仓库。确认自己有权使用和分发任何打包的素材。

## 屏保选图排查

如果系统屏保显示的不是所选照片，请依次检查：

1. 在应用的「屏幕保护程序」面板确认「下次启动屏保时播放」的名称。
2. 升级应用后，再点一次「安装屏幕保护程序…」，让系统加载配套的新插件。
3. 到系统设置确认选中了菠萝壁纸屏保；旧名称可能显示为 `PineappleWallpaperSaver`。
4. 退出当前屏保，再重新启动。媒体副本缺失或无法解码时，会尝试图库中的其他画面。

应用与屏保通过同一份 `library.json` 共享选择。旧版曾因偏好存储和系统屏保宿主的数据目录不同而读不到所选画面，当前源码已统一选择记录与图库路径。若仍有问题，请提交 macOS 版本、应用版本和复现步骤，不要上传私人素材。

## 隐私与限制

照片和视频只在本地读取和显示。项目没有网络请求或遥测代码。源文件路径不会保存在新版图库中，媒体会复制到应用数据目录，因此需要额外磁盘空间。当前多个显示器播放同一视频，各显示器从各自的播放器开始播放，切换后可能有少量不同步。屏保每次启动时读取当时的图库与选择；已运行的屏保需要退出并重新启动才会更新。不同机型与视频编码的流畅度取决于 macOS 的硬件解码能力。没有开机自启功能。

遇到损坏或未来版本的图库文件，应用会停止写入并提示错误，避免覆盖数据。建议先备份 `library.json` 和 `Media/`，再报告问题。

## 参与开发

参见 [CONTRIBUTING.md](CONTRIBUTING.md) 和 [docs/architecture.md](docs/architecture.md)。问题反馈请描述 macOS 版本、媒体格式/分辨率、复现步骤和日志，不要上传含有个人内容的照片或视频。代码以 MIT 许可证开放；Pineapple Tech 标志和字标单独保留权利，参见 [BRAND.md](BRAND.md)。用户导入的照片和视频不属于本项目的开源素材。

## 作者与许可

作者：**Pineapple-Tech 菠萝吹雪**。代码使用 [MIT License](LICENSE)；应用原有品牌图案的使用范围见 [BRAND.md](BRAND.md)。

需要分享项目时，可使用[项目介绍文案](docs/PROJECT_INTRO.md)。

## English

**Your photos and videos, on your Mac desktop.** Pineapple Wallpaper is an offline macOS wallpaper and screen saver app built with Swift, SwiftUI, AppKit and AVFoundation.

Import photos or videos into a local library, click to switch wallpapers, and choose a separate screen saver image or let it follow your desktop. Includes search, favorites, duplicate detection, menu bar controls and power-aware video playback. Multiple displays currently share the same selected media.

Requires macOS 15+ and Swift 6+. Build with `bash scripts/build-app.sh`, then open `dist/PineappleWallpaper.app`. Run `bash scripts/check.sh` for library checks. A bundled screen saver can be installed from the app. No Apple-notarized public download is currently available.

Code: MIT. Brand artwork: separate terms in [BRAND.md](BRAND.md). Author: **Pineapple-Tech 菠萝吹雪**.
