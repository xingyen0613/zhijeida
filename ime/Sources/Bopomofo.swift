import Foundation

/// 大千（標準）注音鍵盤佈局，以及以真實音節表為準的判定。
///
/// 音節表來自 McBopomofo 的 BPMFBase.txt（MIT License,
/// Copyright (c) 2011-2026 Mengjuei Hsieh et al.），
/// 只取 big5 常用字集，見 fetch-data.sh 與 Data/LICENSE-McBopomofo.txt。
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

    /// 按鍵序列 -> 該音節的候選漢字（依常用度排序）
    private static let table: [String: [String]] = load()

    /// 所有合法按鍵序列的前綴，用來判斷「還可能打成中文」
    private static let prefixes: Set<String> = {
        var set = Set<String>()
        for keys in table.keys {
            for end in 1...keys.count {
                set.insert(String(keys.prefix(end)))
            }
        }
        return set
    }()

    private static func load() -> [String: [String]] {
        let path = Bundle.main.path(forResource: "bpmf", ofType: "tsv")
            ?? ProcessInfo.processInfo.environment["BPMF_TSV"]   // 命令列測試用
        guard let path, let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            imeLog("找不到 bpmf.tsv，中文將只顯示注音")
            return [:]
        }
        var result: [String: [String]] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "\t")
            guard parts.count == 2 else { continue }
            result[String(parts[0])] = parts[1].map(String.init)
        }
        imeLog("載入 \(result.count) 個音節")
        return result
    }

    /// 這串按鍵是不是一個完整合法的音節（以真實音節表為準）
    static func isSyllable(_ keys: String) -> Bool {
        table[keys] != nil
    }

    /// 這串按鍵有沒有可能再延伸成合法音節
    static func couldBeSyllable(_ keys: String) -> Bool {
        prefixes.contains(keys)
    }

    /// 候選漢字，依常用度排序
    static func candidates(_ keys: String) -> [String] {
        table[keys] ?? []
    }

    /// 把一段按鍵切成「英文前綴 + 中文音節」。
    /// 英文與注音之間沒有分隔符（macbooknji3），從尾部取最長合法音節，前綴即英文。
    static func split(_ keys: String) -> [(isChinese: Bool, keys: String)] {
        if isSyllable(keys) { return [(true, keys)] }
        // 全是數字又不成音節，就是使用者在打數字（0613、手機號碼），
        // 不要從尾部切出「06」=ㄢˊ 這種音節。注意「18」=ㄅㄚ=八 這類
        // 全數字的合法音節已在上一行認定為中文。
        if keys.allSatisfy(\.isNumber) { return [(false, keys)] }
        // 中文音節後必有聲調鍵或空白，所以全字母的單元不會是「英文+注音」黏著
        let hasNonLetter = keys.contains { !$0.isLetter }
        if hasNonLetter, keys.count > 1 {
            for offset in 1..<keys.count {
                let idx = keys.index(keys.startIndex, offsetBy: offset)
                let tail = String(keys[idx...])
                // 尾段全是數字時視為數字的一部分（xingyen0613 的 06 不是ㄢˊ）
                if tail.allSatisfy(\.isNumber) { continue }
                if isSyllable(tail) {
                    return [(false, String(keys[..<idx])), (true, tail)]
                }
            }
        }
        return [(false, keys)]
    }

    /// 把按鍵轉成注音符號串（組字區顯示用）
    static func symbols(_ keys: String) -> String {
        String(keys.compactMap { key[$0] ?? tone[$0] })
    }
}
