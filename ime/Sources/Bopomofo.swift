import Foundation

/// 大千（標準）注音鍵盤佈局與音節判定。
/// 與 Phase 1 的 judge.py 同一套規則，見專案 README。
enum Bopomofo {

    static let key: [Character: Character] = [
        "1": "ㄅ", "q": "ㄆ", "a": "ㄇ", "z": "ㄈ",
        "2": "ㄉ", "w": "ㄊ", "s": "ㄋ", "x": "ㄌ",
        "e": "ㄍ", "d": "ㄎ", "c": "ㄏ",
        "r": "ㄐ", "f": "ㄑ", "v": "ㄒ",
        "5": "ㄓ", "t": "ㄔ", "g": "ㄕ", "b": "ㄖ",
        "y": "ㄗ", "h": "ㄘ", "n": "ㄙ",
        "u": "ㄧ", "j": "ㄨ", "m": "ㄩ",
        "8": "ㄚ", "i": "ㄛ", "k": "ㄜ", ",": "ㄝ",
        "9": "ㄞ", "o": "ㄟ", "l": "ㄠ", ".": "ㄡ",
        "0": "ㄢ", "p": "ㄣ", ";": "ㄤ", "/": "ㄥ",
        "-": "ㄦ",
    ]

    static let tone: [Character: Character] = ["3": "ˇ", "4": "ˋ", "6": "ˊ", "7": "˙"]

    static let initials = Set("ㄅㄆㄇㄈㄉㄊㄋㄌㄍㄎㄏㄐㄑㄒㄓㄔㄕㄖㄗㄘㄙ")
    static let medials = Set("ㄧㄨㄩ")
    static let finals = Set("ㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦ")
    /// 空韻，可自成音節（之吃是日資次私）
    static let soloInitials = Set("ㄓㄔㄕㄖㄗㄘㄙ")

    /// 整串按鍵是否恰好構成單一合法注音音節（可帶聲調）。
    /// 回傳注音字串，不合法則為 nil。
    static func asSyllable(_ keys: String) -> String? {
        var symbols = ""
        var toneMark: Character? = nil
        for ch in keys {
            if let t = tone[ch] {
                guard toneMark == nil else { return nil }
                toneMark = t
            } else if let s = key[ch] {
                guard toneMark == nil else { return nil }  // 聲調後不能再接注音
                symbols.append(s)
            } else {
                return nil
            }
        }
        var idx = symbols.startIndex
        var ini: Character? = nil, med: Character? = nil, fin: Character? = nil
        if idx < symbols.endIndex, initials.contains(symbols[idx]) {
            ini = symbols[idx]; idx = symbols.index(after: idx)
        }
        if idx < symbols.endIndex, medials.contains(symbols[idx]) {
            med = symbols[idx]; idx = symbols.index(after: idx)
        }
        if idx < symbols.endIndex, finals.contains(symbols[idx]) {
            fin = symbols[idx]; idx = symbols.index(after: idx)
        }
        guard idx == symbols.endIndex, ini != nil || med != nil || fin != nil else { return nil }
        if med == nil, fin == nil, let i = ini, !soloInitials.contains(i) { return nil }
        return symbols + (toneMark.map(String.init) ?? "")
    }

    /// 這串按鍵有沒有可能再延伸成合法音節（決定組字區要顯示注音還是英文）
    static func couldBeSyllable(_ keys: String) -> Bool {
        if asSyllable(keys) != nil { return true }
        for extra in Array(key.keys) + Array(tone.keys) {
            if asSyllable(keys + String(extra)) != nil { return true }
        }
        return false
    }

    /// 把按鍵轉成注音符號串（不檢查合法性，供組字區顯示用）
    static func symbols(_ keys: String) -> String {
        String(keys.compactMap { key[$0] ?? tone[$0] })
    }
}
