#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
output_dir=${1:-..}
mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd)

codesign --verify --deep --strict dist/PineappleWallpaper.app
codesign --verify --deep --strict dist/PineappleWallpaper.saver
COPYFILE_DISABLE=1 ditto -c -k --keepParent --norsrc --noextattr \
  dist/PineappleWallpaper.app "$output_dir/PineappleWallpaper-macOS-$version.zip"
COPYFILE_DISABLE=1 ditto -c -k --keepParent --norsrc --noextattr \
  dist/PineappleWallpaper.saver "$output_dir/PineappleWallpaper-saver-$version.zip"

python3 - "$output_dir/PineappleWallpaper-source-$version.zip" <<'PY'
import pathlib
import subprocess
import sys
import zipfile

archive = pathlib.Path(sys.argv[1])
names = subprocess.check_output(
    ['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard']
).split(b'\0')
paths = sorted({pathlib.Path(name.decode()) for name in names if name})
personal_media_extensions = {'.mp4', '.mov', '.m4v', '.webm', '.jpg', '.jpeg', '.png', '.heic', '.tif', '.tiff'}
count = 0
with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED) as output:
    for path in paths:
        if path.suffix.lower() in personal_media_extensions and path.as_posix() != 'Resources/Brand/PineappleTech.jpg':
            continue
        if path.is_file() and not any(part in {'.git', '.build', 'dist', 'Media'} for part in path.parts):
            output.write(path, path.as_posix())
            count += 1
print(f'Packaged {count} source files into {archive}')
PY

printf 'Packaged version %s in %s\n' "$version" "$output_dir"
