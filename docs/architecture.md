# Architecture

`PineappleWallpaperCore` contains the library schema, validation, content hashing, and filesystem repository. It has no UI dependency. `PineappleWallpaperApp` owns the SwiftUI interface, AppKit desktop windows, AVFoundation playback, and the import workflow. `PineappleWallpaperChecks` runs repository behavior checks without XCTest so it works with Command Line Tools alone.

`PineappleWallpaperSaver` is a separate ScreenSaverView bundle built alongside the app. The app embeds a copy under `Contents/PlugIns` for installation. Both processes read the same local library; the app writes the optional screen saver clip ID through `ScreenSaverDefaults`. The saver resolves validated media filenames through `LibraryRepository`, then displays a photo in a `CALayer` or plays a muted video in an `AVPlayerLayer`. If its selected clip is missing or fails to decode, it tries the active wallpaper and then the other clips. It does not modify the library or import files.

On import, `LibraryRepository.stage` streams the source media to a temporary file and hashes the copied bytes. The app validates videos with AVFoundation and photos with ImageIO, checks for an existing digest, moves a new copy into `Media/`, then atomically saves the manifest. If the save fails, the new copy is removed. The original file remains untouched. Schema version 1 video entries decode with `kind = video`; adding a photo upgrades the manifest to version 2.

The app resolves only validated basenames inside its own media directory and refuses symbolic links there. It never executes content found in videos, filenames, metadata, or imported files. `library.json` is data, not instruction. When loading a manifest fails, the app preserves it and disables edits.

Video playback creates one muted `AVQueuePlayer` and `AVPlayerLooper` per screen, displayed on a window immediately above the desktop layer. Photos use an ImageIO-decoded `CALayer` in the same windows, with bounded decode size and EXIF orientation applied. The preview uses the first player or photo. Changing displays rebuilds the desktop windows. The app pauses video playback on Mac sleep, and optionally when Low Power Mode is active.

The legacy migration reads the previous `VideoWallpaper/library.json` and its `Media/` files. It copies recognized files into the new library without modifying the old store. No absolute user path is compiled into the application.
