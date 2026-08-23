#!/bin/bash
# 取得 McBopomofo 的注音資料
#   BPMFBase.txt / phrase.occ / exclusion.txt — MIT License
#     Copyright (c) 2011-2026 Mengjuei Hsieh et al.
#   BPMFMappings.txt — 源自 libtabe 的 tsi.src，BSD License
# 授權全文見 Data/LICENSE-McBopomofo.txt
set -e
cd "$(dirname "$0")"
mkdir -p Data

BASE="https://raw.githubusercontent.com/openvanilla/McBopomofo/master"

for f in BPMFBase.txt BPMFMappings.txt phrase.occ exclusion.txt; do
    echo "取得 $f ..."
    curl -sfL "$BASE/Source/Data/$f" -o "Data/$f"
done
curl -sfL "$BASE/LICENSE.txt" -o Data/LICENSE-McBopomofo.txt

wc -l Data/BPMFBase.txt Data/BPMFMappings.txt Data/phrase.occ Data/exclusion.txt
