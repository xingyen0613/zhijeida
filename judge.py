"""中英混輸判別器：輸入原始按鍵序列，切分並判斷中文注音 / 英文單字。

前提：使用者會打聲調，一聲直接按空白鍵。

由此得到兩個約束，判別幾乎不需要詞典：
1. 聲調鍵(3467)與空白是單元邊界。
2. 一個單元內中文最多一個音節 —— 若有兩個，第一個後面就會有聲調鍵或空白。

所以「整串構不成單一合法音節」即可判定為英文（cpu=ㄏㄣㄧ、mrvl、goog）。
英文與注音黏著時（macbooknji3），從尾部取最長合法音節，前綴即英文。
"""
import sys

KEY = {
    '1': 'ㄅ', 'q': 'ㄆ', 'a': 'ㄇ', 'z': 'ㄈ',
    '2': 'ㄉ', 'w': 'ㄊ', 's': 'ㄋ', 'x': 'ㄌ',
    'e': 'ㄍ', 'd': 'ㄎ', 'c': 'ㄏ',
    'r': 'ㄐ', 'f': 'ㄑ', 'v': 'ㄒ',
    '5': 'ㄓ', 't': 'ㄔ', 'g': 'ㄕ', 'b': 'ㄖ',
    'y': 'ㄗ', 'h': 'ㄘ', 'n': 'ㄙ',
    'u': 'ㄧ', 'j': 'ㄨ', 'm': 'ㄩ',
    '8': 'ㄚ', 'i': 'ㄛ', 'k': 'ㄜ', ',': 'ㄝ',
    '9': 'ㄞ', 'o': 'ㄟ', 'l': 'ㄠ', '.': 'ㄡ',
    '0': 'ㄢ', 'p': 'ㄣ', ';': 'ㄤ', '/': 'ㄥ',
    '-': 'ㄦ',
}
TONE = {'3': 'ˇ', '4': 'ˋ', '6': 'ˊ', '7': '˙'}

INITIAL = set('ㄅㄆㄇㄈㄉㄊㄋㄌㄍㄎㄏㄐㄑㄒㄓㄔㄕㄖㄗㄘㄙ')
MEDIAL = set('ㄧㄨㄩ')
FINAL = set('ㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦ')
SOLO_INITIAL = set('ㄓㄔㄕㄖㄗㄘㄙ')


def as_syllable(keys):
    """整串 keys 是否恰好構成單一合法注音音節（可帶聲調）"""
    j = 0
    ini = med = fin = ''
    if j < len(keys) and KEY.get(keys[j]) in INITIAL:
        ini = KEY[keys[j]]; j += 1
    if j < len(keys) and KEY.get(keys[j]) in MEDIAL:
        med = KEY[keys[j]]; j += 1
    if j < len(keys) and KEY.get(keys[j]) in FINAL:
        fin = KEY[keys[j]]; j += 1
    tone = ''
    if j < len(keys) and keys[j] in TONE:
        tone = TONE[keys[j]]; j += 1
    if j != len(keys) or not (ini or med or fin):
        return None
    if not (med or fin) and ini not in SOLO_INITIAL:
        return None
    return ini + med + fin + tone


def units(line):
    """以空白與聲調鍵為邊界切出輸入單元"""
    out, cur = [], ''
    for ch in line:
        if ch == ' ':
            if cur:
                out.append(cur); cur = ''
        else:
            cur += ch
            if ch in TONE:
                out.append(cur); cur = ''
    if cur:
        out.append(cur)
    return out


def load_dict():
    """系統英文詞典，只用於全字母單元的邊界判斷"""
    words = set()
    with open('/usr/share/dict/words', encoding='utf-8', errors='ignore') as f:
        for line in f:
            w = line.strip().lower()
            if len(w) >= 2 and w.isalpha():
                words.add(w)
    try:
        with open('userdict.txt', encoding='utf-8') as f:
            words |= {w.strip().lower() for w in f if w.strip()}
    except FileNotFoundError:
        pass
    return words | {'i', 'a'}


def classify(unit, endict):
    zh = as_syllable(unit)
    if zh:
        return [('ZH', unit, zh)]
    has_nonalpha = not unit.isalpha()
    if unit.isalpha() and unit in endict:
        return [('EN', unit, '')]
    # 從尾部取最長合法音節，前綴視為英文
    for i in range(1, len(unit)):
        tail = as_syllable(unit[i:])
        if tail:
            head = unit[:i]
            if has_nonalpha or head in endict:
                return [('EN', head, ''), ('ZH', unit[i:], tail)]
    return [('EN', unit, '')]


def main():
    endict = load_dict()
    with open(sys.argv[1], encoding='utf-8') as f:
        for line in f:
            line = line.strip().lower()
            if not line:
                continue
            toks = [t for u in units(line) for t in classify(u, endict)]
            print(' '.join(f'<{k}>{v}' if k == 'EN' else z for k, v, z in toks))


if __name__ == '__main__':
    main()
