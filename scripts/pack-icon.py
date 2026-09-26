#!/usr/bin/env python3
"""Pack PNG representations into a classic macOS .icns container."""
from pathlib import Path
import struct
import sys

iconset = Path(sys.argv[1])
output = Path(sys.argv[2])
reps = [
    (b"ic10", "icon_512x512@2x.png"),
    (b"ic09", "icon_512x512.png"),
    (b"ic08", "icon_256x256.png"),
    (b"ic07", "icon_128x128.png"),
    (b"icp6", "icon_32x32@2x.png"),
    (b"icp5", "icon_32x32.png"),
    (b"icp4", "icon_16x16.png"),
]
chunks = []
for kind, filename in reps:
    png = (iconset / filename).read_bytes()
    if not png.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError(f"Not a PNG: {filename}")
    chunks.append(kind + struct.pack(">I", len(png) + 8) + png)
body = b"".join(chunks)
output.write_bytes(b"icns" + struct.pack(">I", len(body) + 8) + body)
