#!/bin/bash
# 用 Command Line Tools 編譯並組出 IMK 輸入法 bundle（不需要 Xcode）
#   ./build.sh              只編譯本機架構，開發用，較快
#   ./build.sh --universal  編譯 arm64 + x86_64 合併，發布用
set -e
cd "$(dirname "$0")"

UNIVERSAL=0
[ "$1" = "--universal" ] && UNIVERSAL=1

APP="build/Zhijeida.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

SWIFT_FLAGS=(-O -framework Cocoa -framework InputMethodKit)

if [ "$UNIVERSAL" = 1 ]; then
    # swiftc 一次只吃一個 -target，所以兩個架構分別編再用 lipo 合併
    for arch in arm64 x86_64; do
        echo "編譯 $arch ..."
        swiftc "${SWIFT_FLAGS[@]}" \
            -target "$arch-apple-macos12.0" \
            -o "build/Zhijeida-$arch" \
            Sources/*.swift
    done
    lipo -create -output "$APP/Contents/MacOS/Zhijeida" \
        build/Zhijeida-arm64 build/Zhijeida-x86_64
    rm build/Zhijeida-arm64 build/Zhijeida-x86_64
else
    swiftc "${SWIFT_FLAGS[@]}" \
        -target "$(uname -m)-apple-macos12.0" \
        -o "$APP/Contents/MacOS/Zhijeida" \
        Sources/*.swift
fi

cp Info.plist "$APP/Contents/Info.plist"
cp Resources/*.tiff "$APP/Contents/Resources/"
cp Data/bpmf.tsv Data/lm.tsv "$APP/Contents/Resources/"
# 詞庫是 McBopomofo 的衍生資料，散布時必須隨附授權全文
cp Data/LICENSE-McBopomofo.txt "$APP/Contents/Resources/"

# 傳統 app bundle 需要 PkgInfo（Xcode 會自動產生，手工組要自己補）
printf 'APPLZJDA' > "$APP/Contents/PkgInfo"

mkdir -p "$APP/Contents/Resources/en.lproj"
cat > "$APP/Contents/Resources/en.lproj/InfoPlist.strings" <<'STRINGS'
"CFBundleName" = "Zhijeida";
STRINGS
codesign --force --sign - "$APP"

echo "已產生 $APP"
lipo -info "$APP/Contents/MacOS/Zhijeida"
