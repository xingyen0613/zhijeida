import Foundation

/// 組字區的一個輸入單位：一個中文音節，或一段英文。
enum Item {
    case chinese(keys: String)
    case english(String)

    var isChinese: Bool { if case .chinese = self { return true }; return false }
    var keys: String {
        switch self {
        case .chinese(let k): return k
        case .english(let t): return t
        }
    }
}

/// 畫面上呈現的一個區塊。中文區塊可能由多個音節合成一個詞。
struct Chunk {
    let text: String
    let isChinese: Bool
    /// 涵蓋 items 的哪幾個
    let range: Range<Int>
}

/// 尚未上屏的組字內容。
///
/// 中文音節不逐字決定，而是整串交給 LanguageModel.walk 找最佳切法，
/// 所以「ㄘㄜˋ ㄕˋ」會合成「測試」而不是「冊」「市」兩個字。
struct Composition {
    private(set) var items: [Item] = []
    /// 使用者手動選過的詞：起始 item 位置 -> (詞, 涵蓋幾個音節)
    private var overrides: [Int: (word: String, span: Int)] = [:]
    /// 游標指向第幾個 chunk
    private(set) var cursorChunk: Int = 0

    var isEmpty: Bool { items.isEmpty }

    mutating func append(keys: String, isChinese: Bool) {
        items.append(isChinese ? .chinese(keys: keys) : .english(keys))
        cursorChunk = max(chunks().count - 1, 0)
    }

    mutating func removeLast() {
        guard !items.isEmpty else { return }
        items.removeLast()
        overrides = overrides.filter { $0.key < items.count }
        cursorChunk = max(chunks().count - 1, 0)
    }

    mutating func clear() {
        items.removeAll()
        overrides.removeAll()
        cursorChunk = 0
    }

    mutating func moveCursor(_ delta: Int) {
        let upper = max(chunks().count - 1, 0)
        cursorChunk = min(max(cursorChunk + delta, 0), upper)
    }

    /// 把 items 切成畫面區塊：連續的中文音節交給 walk 分詞，英文原樣保留
    func chunks() -> [Chunk] {
        var result: [Chunk] = []
        var i = 0
        while i < items.count {
            guard items[i].isChinese else {
                result.append(Chunk(text: items[i].keys, isChinese: false, range: i..<(i + 1)))
                i += 1
                continue
            }
            var j = i
            while j < items.count, items[j].isChinese { j += 1 }
            let syllables = items[i..<j].map(\.keys)
            let localOverrides = overrides.reduce(into: [Int: (word: String, span: Int)]()) {
                if $1.key >= i && $1.key < j { $0[$1.key - i] = $1.value }
            }
            for chunk in LanguageModel.walk(syllables, overrides: localOverrides) {
                result.append(Chunk(text: chunk.word, isChinese: true,
                                    range: (i + chunk.range.lowerBound)..<(i + chunk.range.upperBound)))
            }
            i = j
        }
        return result
    }

    var text: String { chunks().map(\.text).joined() }

    /// 游標所在區塊
    var currentChunk: Chunk? {
        let list = chunks()
        guard cursorChunk >= 0, cursorChunk < list.count else { return nil }
        return list[cursorChunk]
    }

    /// 游標所在區塊的候選詞
    var currentCandidates: [String] {
        guard let chunk = currentChunk, chunk.isChinese else { return [] }
        let keys = items[chunk.range].map(\.keys).joined()
        return LanguageModel.candidates(keys).map(\.word)
    }

    /// 對游標所在區塊選定某個候選詞
    mutating func choose(_ word: String) {
        guard let chunk = currentChunk, chunk.isChinese else { return }
        overrides[chunk.range.lowerBound] = (word, chunk.range.count)
    }

    /// 組字區顯示字串，游標所在的中文區塊用括號標示
    func marked(pendingKeys: String) -> String {
        var parts: [String] = []
        for (i, chunk) in chunks().enumerated() {
            parts.append(i == cursorChunk && chunk.isChinese ? "[\(chunk.text)]" : chunk.text)
        }
        if !pendingKeys.isEmpty {
            parts.append(Bopomofo.split(pendingKeys).map {
                $0.isChinese ? Bopomofo.symbols($0.keys) : $0.keys
            }.joined())
        }
        return parts.joined()
    }
}
