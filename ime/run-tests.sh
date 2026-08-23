#!/bin/bash
# 回歸測試：不需要安裝輸入法，直接驗證判別、分詞、選字與編輯邏輯
set -eo pipefail
cd "$(dirname "$0")"
swiftc -O -o /tmp/zhijeida-tests \
    Sources/Log.swift Sources/Bopomofo.swift Sources/LanguageModel.swift \
    Sources/UserPhrases.swift Sources/Symbols.swift Sources/Composition.swift \
    tests/main.swift

# 使用者詞彙導向暫存檔，測試不會動到真實的個人記錄
LM_TSV="$PWD/Data/lm.tsv" BPMF_TSV="$PWD/Data/bpmf.tsv" \
    USER_PHRASES_PATH="/tmp/zhijeida-test-phrases.tsv" \
    /tmp/zhijeida-tests 2>/dev/null
