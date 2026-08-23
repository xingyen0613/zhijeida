#!/bin/bash
# 取得 McBopomofo 的注音資料
#   BPMFBase.txt / phrase.occ / exclusion.txt — MIT License
#     Copyright (c) 2011-2026 Mengjuei Hsieh et al.
#   BPMFMappings.txt — 源自 libtabe 的 tsi.src，BSD License
# 授權全文見 Data/LICENSE-McBopomofo.txt
set -e
cd "$(dirname "$0")"
mkdir -p Data

# 固定在特定 commit 而非 master，理由有二：
#   1. 建置可重現 —— 不同時間、不同人取得的詞庫完全一致，
#      否則上游更新詞庫會讓選字結果改變、回歸測試無故失敗。
#   2. 鎖定在一個已知狀態，上游日後若遭竄改也影響不到這裡。
# 要更新詞庫時把 SHA 換掉，並重跑 ./run-tests.sh 確認選字結果沒有意外變動。
MCBOPOMOFO_COMMIT="73d0379eca621377fb46416ceb4a7dc9bb576d47"   # 2026-08-08

BASE="https://raw.githubusercontent.com/openvanilla/McBopomofo/$MCBOPOMOFO_COMMIT"

for f in BPMFBase.txt BPMFMappings.txt phrase.occ exclusion.txt; do
    echo "取得 $f ..."
    curl -sfL "$BASE/Source/Data/$f" -o "Data/$f"
done
curl -sfL "$BASE/LICENSE.txt" -o Data/LICENSE-McBopomofo.txt

wc -l Data/BPMFBase.txt Data/BPMFMappings.txt Data/phrase.occ Data/exclusion.txt
