#!/bin/bash
# 取得 McBopomofo 的注音對照資料（MIT License）
# Copyright (c) 2011-2026 Mengjuei Hsieh et al. — 見 Data/LICENSE-McBopomofo.txt
set -e
cd "$(dirname "$0")"
mkdir -p Data

for f in BPMFBase.txt; do
    echo "取得 $f ..."
    gh api "repos/openvanilla/McBopomofo/contents/Source/Data/$f" --jq '.content' \
        | base64 -d > "Data/$f"
done

gh api repos/openvanilla/McBopomofo/contents/LICENSE.txt --jq '.content' \
    | base64 -d > Data/LICENSE-McBopomofo.txt

wc -l Data/*.txt
