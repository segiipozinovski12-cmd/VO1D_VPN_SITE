#!/usr/bin/env python3
"""Fetch pinned upstream Windows runtimes; verify archives before unpacking."""
import hashlib
import io
import json
from pathlib import Path
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "VO1D.Vpn" / "Assets" / "runtime"
PACKAGES = [
    ("https://github.com/SagerNet/sing-box/releases/download/v1.14.2/sing-box-1.14.2-windows-amd64.zip",
     "c2d8bfff918755808781dfdeeb8581b6c91eb3a243d9a7b55483cfc0c0684d32",
     {"sing-box-1.14.2-windows-amd64/sing-box.exe": "sing-box.exe",
      "sing-box-1.14.2-windows-amd64/libcronet.dll": "libcronet.dll",
      "sing-box-1.14.2-windows-amd64/LICENSE": "sing-box-LICENSE.txt"}),
    ("https://www.wintun.net/builds/wintun-0.14.1.zip",
     "07c256185d6ee3652e09fa55c0b673e2624b565e02c4b9091c79ca7d2f24ef51",
     {"wintun/bin/amd64/wintun.dll": "wintun.dll", "wintun/LICENSE.txt": "wintun-LICENSE.txt"}),
]

def main():
    TARGET.mkdir(parents=True, exist_ok=True)
    hashes = {}
    for url, expected, members in PACKAGES:
        request = urllib.request.Request(url, headers={"User-Agent": "VO1D-Windows-Build/1.0"})
        with urllib.request.urlopen(request, timeout=120) as response:
            archive = response.read()
        actual = hashlib.sha256(archive).hexdigest()
        if actual != expected:
            raise RuntimeError(f"Upstream archive hash mismatch: {url}")
        with zipfile.ZipFile(io.BytesIO(archive)) as z:
            for source, name in members.items():
                content = z.read(source)
                (TARGET / name).write_bytes(content)
                hashes[name] = hashlib.sha256(content).hexdigest()
    (TARGET / "upstream-hashes.json").write_text(json.dumps(hashes, indent=2), encoding="utf-8")
    print("Verified sing-box 1.14.2 and Wintun 0.14.1 (Windows x64)")

if __name__ == "__main__":
    main()
