#!/usr/bin/env python3
"""把 McBopomofo 的注音資料編成語言模型：按鍵序列 -> [(詞, 對數分數)]

分數 = log((出現次數 + 平滑) / 總數)，單字與詞組同一個尺度，
讓 DAG 最短路徑能公平比較「測試」與「冊」+「市」。
"""
import math
import os
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(HERE, 'Data')

# 注音符號 -> 大千按鍵（KEY 的反查）
KEY = {
    '1': 'ㄅ', 'q': 'ㄆ', 'a': 'ㄇ', 'z': 'ㄈ', '2': 'ㄉ', 'w': 'ㄊ', 's': 'ㄋ', 'x': 'ㄌ',
    'e': 'ㄍ', 'd': 'ㄎ', 'c': 'ㄏ', 'r': 'ㄐ', 'f': 'ㄑ', 'v': 'ㄒ', '5': 'ㄓ', 't': 'ㄔ',
    'g': 'ㄕ', 'b': 'ㄖ', 'y': 'ㄗ', 'h': 'ㄘ', 'n': 'ㄙ', 'u': 'ㄧ', 'j': 'ㄨ', 'm': 'ㄩ',
    '8': 'ㄚ', 'i': 'ㄛ', 'k': 'ㄜ', ',': 'ㄝ', '9': 'ㄞ', 'o': 'ㄟ', 'l': 'ㄠ', '.': 'ㄡ',
    '0': 'ㄢ', 'p': 'ㄣ', ';': 'ㄤ', '/': 'ㄥ', '-': 'ㄦ',
}
SYM = {v: k for k, v in KEY.items()}
SYM.update({'ˇ': '3', 'ˋ': '4', 'ˊ': '6', '˙': '7'})


def to_keys(bopomofo):
    """一個注音音節 -> 按鍵序列，遇到不認得的符號回傳 None"""
    out = []
    for ch in bopomofo:
        k = SYM.get(ch)
        if k is None:
            return None
        out.append(k)
    return ''.join(out)


# 出現次數
occ = {}
with open(f'{D}/phrase.occ', encoding='utf-8') as f:
    for line in f:
        parts = line.split()
        if len(parts) == 2 and parts[1].isdigit():
            occ[parts[0]] = int(parts[1])

entries = defaultdict(list)   # 按鍵序列 -> [(詞, 次數)]

# 單字：BPMFBase 第 4 欄就是按鍵
BPMF_RANGE = lambda s: all('ㄅ' <= c <= 'ㄯ' for c in s)
with open(f'{D}/BPMFBase.txt', encoding='utf-8') as f:
    for line in f:
        p = line.split()
        if len(p) != 5 or not p[4].startswith('big5'):
            continue
        han, keys = p[0], p[3]
        if BPMF_RANGE(han):        # 注音符號本身不算字
            continue
        entries[keys].append((han, occ.get(han, 0)))

# 詞組：BPMFMappings 是「詞 注音1 注音2 …」
with open(f'{D}/BPMFMappings.txt', encoding='utf-8') as f:
    for line in f:
        p = line.split()
        if len(p) < 3:
            continue
        word, syllables = p[0], p[1:]
        if len(word) != len(syllables):
            continue
        keys = [to_keys(s) for s in syllables]
        if any(k is None for k in keys):
            continue
        entries[''.join(keys)].append((word, occ.get(word, 0)))

# 分數：加 0.5 平滑後取對數機率
total = sum(c for lst in entries.values() for _, c in lst)
smooth = 0.5
denom = total + smooth * sum(len(v) for v in entries.values())

lines = []
for keys, lst in entries.items():
    seen = {}
    for word, count in lst:
        seen[word] = max(seen.get(word, 0), count)
    scored = sorted(((w, math.log((c + smooth) / denom)) for w, c in seen.items()),
                    key=lambda x: -x[1])
    lines.append(keys + '\t' + '\t'.join(f'{w} {s:.4f}' for w, s in scored))

out = f'{D}/lm.tsv'
with open(out, 'w', encoding='utf-8') as f:
    f.write('\n'.join(sorted(lines)))

print(f'按鍵序列 {len(entries)} 個，詞條 {sum(len(v) for v in entries.values())} 筆')
print(f'總出現次數 {total}')
print(f'輸出 {out}：{os.path.getsize(out)} bytes')
