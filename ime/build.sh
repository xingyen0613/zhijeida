#!/bin/bash
# 用 Command Line Tools 編譯並組出 IMK 輸入法 bundle（不需要 Xcode）
set -e
cd "$(dirname "$0")"

APP="build/SmartBopomofo.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O \
    -target arm64-apple-macos12.0 \
    -framework Cocoa -framework InputMethodKit \
    -o "$APP/Contents/MacOS/SmartBopomofo" \
    Sources/*.swift

cp Info.plist "$APP/Contents/Info.plist"
cp Resources/*.tiff "$APP/Contents/Resources/"

# 傳統 app bundle 需要 PkgInfo（Xcode 會自動產生，手工組要自己補）
printf 'APPLSBPM' > "$APP/Contents/PkgInfo"

mkdir -p "$APP/Contents/Resources/en.lproj"
cat > "$APP/Contents/Resources/en.lproj/InfoPlist.strings" <<'STRINGS'
"CFBundleName" = "SmartBopomofo";
STRINGS
codesign --force --sign - "$APP"

echo "已產生 $APP"
