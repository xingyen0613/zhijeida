import Foundation

/// 半形符號對應的全形／中文標點。
enum Symbols {
    static let fullWidth: [String: String] = [
        ",": "，", ".": "。", ";": "；", ":": "：",
        "?": "？", "!": "！", "\\": "、",
        "(": "（", ")": "）", "[": "「", "]": "」",
        "{": "『", "}": "』", "<": "《", ">": "》",
        "'": "‘", "\"": "“", "`": "・",
        "-": "－", "=": "＝", "+": "＋", "*": "＊", "/": "／",
        "@": "＠", "#": "＃", "$": "＄", "%": "％", "&": "＆",
        "^": "＾", "_": "＿", "|": "｜", "~": "～",
    ]

    static func full(_ halfWidth: String) -> String? {
        fullWidth[halfWidth]
    }

    private static let fullWidthSet = Set(fullWidth.values)

    /// 是不是這裡轉出來的全形標點。全形標點存在組字區裡是英文 item，
    /// 但它的前後仍是中文語境，後面接的符號也該是全形（好，」不是 好，]）。
    static func isFullWidth(_ text: String) -> Bool {
        fullWidthSet.contains(text)
    }

    /// 這個鍵既是標點也是注音韻母（, . ; / - 分別是 ㄝㄡㄤㄥㄦ）。
    /// 中文之後按下去，當下無法判斷是哪一個，要等下一鍵才知道。
    static func isAmbiguous(_ key: String) -> Bool {
        guard key.count == 1, let ch = key.first else { return false }
        return fullWidth[key] != nil && Bopomofo.key[ch] != nil
    }

    /// 擱置中的標點遇到下一個按鍵：回傳 true 表示它其實是注音韻母。
    /// 這些韻母都沒有聲母，音節最多就是「韻母 + 聲調鍵」（-6 = ㄦˊ = 而），
    /// 所以只有下一鍵是聲調鍵、且兩鍵合起來是合法音節時才算中文。
    /// 一聲的韻母（ㄡ = 歐）要按空白確認，會與句號衝突，一律當標點。
    static func staysBopomofo(_ pending: String, next: Character) -> Bool {
        Bopomofo.tone[next] != nil && Bopomofo.isSyllable(pending + String(next))
    }
}
