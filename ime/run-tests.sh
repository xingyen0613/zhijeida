#!/bin/bash
# 回歸測試：不需要安裝輸入法，直接驗證判別、分詞、選字與編輯邏輯
set -e
cd "$(dirname "$0")"
swiftc -O -o /tmp/smartbopomofo-tests \
    Sources/Log.swift Sources/Bopomofo.swift Sources/LanguageModel.swift \
    Sources/Composition.swift tests/main.swift
LM_TSV="$PWD/Data/lm.tsv" BPMF_TSV="$PWD/Data/bpmf.tsv" /tmp/smartbopomofo-tests 2>/dev/null
