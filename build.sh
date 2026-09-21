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

# .strings 转成二进制 plist（和 Xcode 的 CopyStringsFile 一致），免得依赖文本编码嗅探
for strings in Resources/*.lproj/*.strings; do
    lproj="$(basename "$(dirname "$strings")")"
    mkdir -p "$APP/Contents/Resources/$lproj"
    plutil -convert binary1 "$strings" -o "$APP/Contents/Resources/$lproj/$(basename "$strings")"
done

echo "▸ 临时签名…"
codesign --force --sign - "$APP"

echo "✅ 完成: $APP"
echo "   启动: open '$APP'"
