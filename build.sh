#!/bin/bash
# 编译并打包成 DeskMonitor.app
set -euo pipefail
cd "$(dirname "$0")"

echo "▸ 编译 (release)…"
swift build -c release

APP="$PWD/DeskMonitor.app"
BIN="$(swift build -c release --show-bin-path)/DeskMonitor"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/DeskMonitor"
cp Info.plist "$APP/Contents/Info.plist"

echo "▸ 临时签名…"
codesign --force --sign - "$APP"

echo "✅ 完成: $APP"
echo "   启动: open '$APP'"
