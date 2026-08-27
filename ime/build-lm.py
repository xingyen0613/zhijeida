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

# 單字：BPMFBase 第 2 欄是讀音、第 4 欄是按鍵
# 資料把注音符號與聲調符號本身也列為可輸入的字（ㄝ / ˇ / ˊ …），
# 留著會讓單一聲母或聲調鍵變成「合法音節」，切壞英文詞尾與數字串。
TONE_MARKS = set('ˊˇˋ˙')
def is_symbol_itself(s):
    return all('ㄅ' <= c <= 'ㄯ' or c in TONE_MARKS for c in s)
BPMF_RANGE = is_symbol_itself

base = []                      # [(字, 讀音, 按鍵)]
readings = defaultdict(list)   # 字 -> 讀音清單
with open(f'{D}/BPMFBase.txt', encoding='utf-8') as f:
    for line in f:
        p = line.split()
        if len(p) != 5 or not p[4].startswith('big5'):
            continue
        han, reading, keys = p[0], p[1], p[3]
        if is_symbol_itself(han):   # 注音／聲調符號本身不算字
            continue
        base.append((han, reading, keys))
        if reading not in readings[han]:
            readings[han].append(reading)

# 詞組：BPMFMappings 是「詞 注音1 注音2 …」
phrases = []
with open(f'{D}/BPMFMappings.txt', encoding='utf-8') as f:
    for line in f:
        p = line.split()
        if len(p) < 3:
            continue
        word, syllables = p[0], p[1:]
        if len(word) != len(syllables) or is_symbol_itself(word):
            continue
        phrases.append((word, syllables))

# 多音字要分讀音計次。phrase.occ 只有整字次數，不分讀音，
# 於是「說」在 ㄕㄨㄟˋ 底下也帶著 shuō 的全部次數，壓過「睡」。
# 詞組資料標了每個字在詞裡的讀音，拿它當證據，把整字次數按比例攤到各讀音：
# 說話／說明 都算 ㄕㄨㄛ，只有遊說算 ㄕㄨㄟˋ，攤完「睡」就排到前面。
evidence = defaultdict(int)   # (字, 讀音) -> 證據權重
for word, syllables in phrases:
    weight = occ.get(word, 0) + 1   # 加一讓沒列次數的詞也算一次證據
    for han, reading in zip(word, syllables):
        evidence[(han, reading)] += weight


def char_count(han, reading):
    total = occ.get(han, 0)
    if len(readings[han]) < 2:
        return total
    # 完全沒有詞組證據的讀音（說 ㄩㄝˋ）靠平滑拿到極小的一份
    weights = {r: evidence[(han, r)] + 1 for r in readings[han]}
    return total * weights[reading] / sum(weights.values())


for han, reading, keys in base:
    entries[keys].append((han, char_count(han, reading)))

for word, syllables in phrases:
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

# 音節判定表：只收單音節，供中英判別使用
syllables_only = {}
with open(f'{D}/BPMFBase.txt', encoding='utf-8') as f:
    for line in f:
        p = line.split()
        if len(p) != 5 or not p[4].startswith('big5'):
            continue
        if is_symbol_itself(p[0]):
            continue
        syllables_only.setdefault(p[3], []).append(p[0])
with open(f'{D}/bpmf.tsv', 'w', encoding='utf-8') as f:
    for k, v in sorted(syllables_only.items()):
        f.write(f"{k}\t{''.join(v)}\n")
print(f'音節判定表 {len(syllables_only)} 個音節')

print(f'按鍵序列 {len(entries)} 個，詞條 {sum(len(v) for v in entries.values())} 筆')
print(f'總出現次數 {total}')
print(f'輸出 {out}：{os.path.getsize(out)} bytes')
