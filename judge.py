"""中英混輸判別器：輸入原始按鍵序列，判斷每個 token 是中文注音還是英文單字。

前提：使用者會打聲調，一聲直接按空白鍵。
因此每個中文音節結束時必有非字母鍵，一個音節最多 3 個注音符號。
"""
import sys
from collections import Counter

# 大千（標準）注音鍵盤，僅英文字母部分
KEY = {
    'a': 'ㄇ', 'z': 'ㄈ', 'w': 'ㄊ', 's': 'ㄋ', 'x': 'ㄌ', 'e': 'ㄍ', 'd': 'ㄎ',
    'c': 'ㄏ', 'r': 'ㄐ', 'f': 'ㄑ', 'v': 'ㄒ', 't': 'ㄔ', 'g': 'ㄕ', 'b': 'ㄖ',
    'y': 'ㄗ', 'h': 'ㄘ', 'n': 'ㄙ', 'q': 'ㄆ',
    'u': 'ㄧ', 'j': 'ㄨ', 'm': 'ㄩ',
    'i': 'ㄛ', 'k': 'ㄜ', 'o': 'ㄟ', 'l': 'ㄠ', 'p': 'ㄣ',
}

INITIAL = set('ㄆㄇㄈㄊㄋㄌㄍㄎㄏㄐㄑㄒㄔㄕㄖㄗㄘㄙ')
MEDIAL = set('ㄧㄨㄩ')
FINAL = set('ㄛㄜㄟㄠㄣ')
SOLO_INITIAL = set('ㄔㄕㄖㄗㄘㄙ')  # 空韻，可自成音節

# 長度<=3 且為合法音節，靠規則分不出來的詞。
# 這幾個注音的一聲少有常用字，預設判英文；覺得誤判就從這裡拿掉。
AMBIGUOUS_AS_EN = {'do', 'go', 'i', 'no', 'so', 'to', 'up'}


def is_syllable(zh):
    """判斷一串注音符號是否構成單一合法音節（結構規則，非權威音節表）"""
    i = 0
    ini = med = fin = ''
    if i < len(zh) and zh[i] in INITIAL:
        ini = zh[i]; i += 1
    if i < len(zh) and zh[i] in MEDIAL:
        med = zh[i]; i += 1
    if i < len(zh) and zh[i] in FINAL:
        fin = zh[i]; i += 1
    if i != len(zh):
        return False
    if med or fin:
        return True
    return bool(ini) and ini in SOLO_INITIAL


def classify(token):
    """回傳 (判定, 理由, 注音)"""
    low = token.lower()
    if not low.isalpha():
        return 'ZH', '含非字母鍵（聲調或注音數字鍵）', ''
    zh = ''.join(KEY.get(c, '?') for c in low)
    if len(low) >= 4:
        return 'EN', '長度>=4，中文音節不可能這麼長', zh
    if not is_syllable(zh):
        return 'EN', f'{zh} 不是合法音節', zh
    if low in AMBIGUOUS_AS_EN:
        return 'EN', f'{zh} 合法但一聲罕用，清單判英文', zh
    return 'ZH', f'{zh} 是合法音節', zh


def main():
    src = open(sys.argv[1], encoding='utf-8') if len(sys.argv) > 1 else sys.stdin
    stats = Counter()
    with src as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            toks = line.split()
            print(' '.join(f'[{classify(t)[0]}]{t}' for t in toks))
            for t in toks:
                verdict, reason, zh = classify(t)
                stats[verdict] += 1
                print(f'    {t:<12} {verdict}   {reason}')
            print()
    total = sum(stats.values())
    if total:
        print(f'共 {total} 個 token：中文 {stats["ZH"]}，英文 {stats["EN"]}')


if __name__ == '__main__':
    main()
