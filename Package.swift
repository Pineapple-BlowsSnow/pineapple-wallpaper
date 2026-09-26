// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PineappleWallpaper",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "PineappleWallpaper", targets: ["PineappleWallpaperApp"])],
    targets: [
        .target(name: "PineappleWallpaperCore"),
        .executableTarget(name: "PineappleWallpaperApp", dependencies: ["PineappleWallpaperCore"]),
        .executableTarget(name: "PineappleWallpaperChecks", dependencies: ["PineappleWallpaperCore"], path: "Checks/PineappleWallpaperChecks")
    ],
    swiftLanguageModes: [.v5]
)
