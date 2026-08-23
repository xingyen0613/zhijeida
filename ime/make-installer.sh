#!/bin/bash
# 把輸入法打包成 .pkg 安裝檔，給不編譯原始碼的使用者下載
#
# 產物：build/Zhijeida-<版本>.pkg
#   安裝位置 ~/Library/Input Methods（使用者家目錄，不需要管理員密碼）
#
# 為什麼用 .pkg 而不是 zip 或 dmg：
#   1. ~/Library/Input Methods 是隱藏路徑，要使用者自己拖檔案進去很容易出錯。
#   2. 從網路下載的 app 會被標記 com.apple.quarantine，而輸入法是由系統啟動、
#      不是使用者雙擊，被 Gatekeeper 擋下時不會有任何提示，只會靜默失效。
#      Installer 解出來的檔案不帶這個屬性，可以避開這個坑。
set -e
cd "$(dirname "$0")"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
IDENTIFIER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" Info.plist)

echo "==> 編譯 universal binary"
./build.sh --universal

echo "==> 組 payload"
STAGE="build/pkgroot"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R build/Zhijeida.app "$STAGE/"

echo "==> pkgbuild"
pkgbuild \
    --root "$STAGE" \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --install-location "Library/Input Methods" \
    --component-plist Installer/component.plist \
    --ownership recommended \
    build/Zhijeida-component.pkg

echo "==> productbuild"
PKG="build/Zhijeida-$VERSION.pkg"
productbuild \
    --distribution Installer/distribution.xml \
    --package-path build \
    --resources Installer/Resources \
    "$PKG"

rm -rf "$STAGE" build/Zhijeida-component.pkg

echo
echo "已產生 $PKG"
ls -lh "$PKG" | awk '{print "  大小：" $5}'
echo "  架構：$(lipo -info build/Zhijeida.app/Contents/MacOS/Zhijeida | sed 's/.*are: //')"
echo
echo "這個 pkg 沒有簽章（需要 Apple Developer Program 才能簽章與公證）。"
echo "使用者第一次打開會被 Gatekeeper 擋下，要到"
echo "「系統設定 → 隱私權與安全性」按「仍要打開」。README 有寫這段。"
