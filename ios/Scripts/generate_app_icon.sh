#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IOS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$IOS_ROOT/VO1DVPN/Resources/IconSource"
DEST_DIR="$IOS_ROOT/VO1DVPN/Resources/Assets.xcassets/AppIcon.appiconset"
DEST="$DEST_DIR/AppIcon-1024.png"

mkdir -p "$DEST_DIR"

cat "$SOURCE_DIR"/AppIcon.png.b64.part* \
  | /usr/bin/base64 -D \
  > "$DEST"

if [ ! -s "$DEST" ]; then
  echo "error: VO1D AppIcon generation failed"
  exit 1
fi

echo "VO1D AppIcon generated: $DEST"
