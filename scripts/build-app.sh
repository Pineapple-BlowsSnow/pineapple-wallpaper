#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -z "${SDKROOT:-}" && -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
  export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
fi
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-${TMPDIR:-/tmp}/pineapple-wallpaper-clang-cache}"

swift build -c release --disable-sandbox --scratch-path .build
APP="dist/PineappleWallpaper.app"
SAVER="dist/PineappleWallpaper.saver"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/PlugIns" \
  "$SAVER/Contents/MacOS" .build/PineappleWallpaper.iconset
cp .build/release/PineappleWallpaper "$APP/Contents/MacOS/PineappleWallpaper"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/ScreenSaver-Info.plist "$SAVER/Contents/Info.plist"
cp Resources/Brand/PineappleTech.png "$APP/Contents/Resources/PineappleTech.png"
swiftc -emit-library -module-name PineappleWallpaperSaver \
  -module-cache-path "$CLANG_MODULE_CACHE_PATH" \
  -framework ScreenSaver -framework AVFoundation -framework AppKit \
  -Xlinker -bundle \
  Sources/PineappleWallpaperCore/*.swift Sources/PineappleWallpaperSaver/*.swift \
  -o "$SAVER/Contents/MacOS/PineappleWallpaperSaver"
codesign --force --sign - "$SAVER"
ditto "$SAVER" "$APP/Contents/PlugIns/PineappleWallpaper.saver"
# Use the approved brand exports. Small sizes have a simplified pineapple mark.
cp Resources/Brand/AppIcon/1024.png .build/PineappleWallpaper.iconset/icon_512x512@2x.png
cp Resources/Brand/AppIcon/128.png "$APP/Contents/Resources/BrandMark.png"
for spec in '16x16:16' '16x16@2x:32' '32x32:32' '32x32@2x:64' '128x128:128' '128x128@2x:256' '256x256:256' '256x256@2x:512' '512x512:512'; do
  name="${spec%%:*}"; pixels="${spec##*:}"
  cp "Resources/Brand/AppIcon/$pixels.png" ".build/PineappleWallpaper.iconset/icon_${name}.png"
done
python3 scripts/pack-icon.py .build/PineappleWallpaper.iconset "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
echo "Built $APP"
