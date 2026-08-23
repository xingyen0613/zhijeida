"""中英混輸判別器：輸入原始按鍵序列，切分並判斷中文注音 / 英文單字。

前提：使用者會打聲調，一聲直接按空白鍵。
聲調鍵(3467)與空白是天然的單元邊界；單元內部可能英文與注音黏著，需再切分。
"""
import re
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


def read_syllable(keys, i):
    """從 keys[i] 起貪婪讀一個合法注音音節，回傳 (結束位置, 注音) 或 None"""
    j = i
    ini = med = fin = ''
    if j < len(keys) and KEY.get(keys[j]) in INITIAL:
        ini = KEY[keys[j]]; j += 1
    if j < len(keys) and KEY.get(keys[j]) in MEDIAL:
        med = KEY[keys[j]]; j += 1
    if j < len(keys) and KEY.get(keys[j]) in FINAL:
        fin = KEY[keys[j]]; j += 1
    if j == i:
        return None
    if not (med or fin) and ini not in SOLO_INITIAL:
        return None
    tone = ''
    if j < len(keys) and keys[j] in TONE:
        tone = TONE[keys[j]]; j += 1
    return j, ini + med + fin + tone


def load_dict():
    words = set()
    with open('/usr/share/dict/words', encoding='utf-8', errors='ignore') as f:
        for line in f:
            w = line.strip().lower()
            if len(w) >= 2 and w.isalpha():
                words.add(w)
    words |= {'i', 'a'}
    return words


def segment(unit, endict):
    """把一個輸入單元切成 [(類型, 內容)]。DP 取 token 數最少的切法。"""
    n = len(unit)
    best = [None] * (n + 1)
    best[0] = (0, [])
    for i in range(n):
        if best[i] is None:
            continue
        cost, path = best[i]
        syl = read_syllable(unit, i)
        if syl:
            j, zh = syl
            cand = (cost + 1, path + [('ZH', unit[i:j], zh)])
            if best[j] is None or cand[0] < best[j][0]:
                best[j] = cand
        for j in range(n, i + 1, -1):
            w = unit[i:j]
            if w.isalpha() and w in endict:
                cand = (cost + 1, path + [('EN', w, '')])
                if best[j] is None or cand[0] < best[j][0]:
                    best[j] = cand
                break
    if best[n]:
        return best[n][1]
    # 無法完整解析：整個單元的字母前綴視為英文，其餘照原樣
    m = re.match(r'^[a-z]+', unit)
    if m:
        head = m.group()
        rest = unit[len(head):]
        return [('EN', head, '')] + (segment(rest, endict) if rest else [])
    return [('EN', unit, '')]


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


def main():
    endict = load_dict()
    src = open(sys.argv[1], encoding='utf-8') if len(sys.argv) > 1 else sys.stdin
    with src as f:
        for line in f:
            line = line.strip().lower()
            if not line:
                continue
            toks = [t for u in units(line) for t in segment(u, endict)]
            print(' '.join(f'<{k}>{v}' if k == 'EN' else zh for k, v, zh in toks))
            print()


if __name__ == '__main__':
    main()
