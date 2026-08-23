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
    let range: Range<Int>   // 涵蓋 items 的哪幾個
}

/// 候選項：一個詞，以及它會蓋住哪幾個音節。
struct Candidate {
    let word: String
    let start: Int
    let span: Int
}

/// 尚未上屏的組字內容。
///
/// 游標是音節層級的插入點（0...items.count），行為比照文字編輯器：
/// 可以移到句中插入、刪除，選字則針對游標左側那個音節。
struct Composition {
    private(set) var items: [Item] = []
    /// 使用者手動選過的詞：起始 item 位置 -> (詞, 涵蓋幾個音節)
    private var overrides: [Int: (word: String, span: Int)] = [:]
    /// 插入點，介於 0 與 items.count 之間
    private(set) var cursor: Int = 0

    var isEmpty: Bool { items.isEmpty }

    // MARK: - 編輯

    mutating func insert(keys: String, isChinese: Bool) {
        items.insert(isChinese ? .chinese(keys: keys) : .english(keys), at: cursor)
        shiftOverrides(from: cursor, by: 1)
        cursor += 1
    }

    mutating func deleteBackward() {
        guard cursor > 0 else { return }
        items.remove(at: cursor - 1)
        overrides.removeValue(forKey: cursor - 1)
        shiftOverrides(from: cursor, by: -1)
        cursor -= 1
    }

    mutating func clear() {
        items.removeAll()
        overrides.removeAll()
        cursor = 0
    }

    mutating func moveCursor(_ delta: Int) {
        cursor = min(max(cursor + delta, 0), items.count)
    }

    mutating func moveCursorToStart() { cursor = 0 }
    mutating func moveCursorToEnd() { cursor = items.count }

    /// 插入或刪除後，把後面的 override 位置一起挪動
    private mutating func shiftOverrides(from index: Int, by delta: Int) {
        guard delta != 0 else { return }
        var moved: [Int: (word: String, span: Int)] = [:]
        for (key, value) in overrides {
            moved[key >= index ? key + delta : key] = value
        }
        overrides = moved
    }

    // MARK: - 分詞

    /// 連續的中文音節交給 walk 分詞，英文原樣保留
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
            let local = overrides.reduce(into: [Int: (word: String, span: Int)]()) {
                if $1.key >= i && $1.key < j { $0[$1.key - i] = $1.value }
            }
            for chunk in LanguageModel.walk(syllables, overrides: local) {
                result.append(Chunk(text: chunk.word, isChinese: true,
                                    range: (i + chunk.range.lowerBound)..<(i + chunk.range.upperBound)))
            }
            i = j
        }
        return result
    }

    var text: String { chunks().map(\.text).joined() }

    // MARK: - 選字

    /// 游標左側的音節位置，選字以它為準
    private var targetIndex: Int? {
        let idx = cursor - 1
        guard idx >= 0, idx < items.count, items[idx].isChinese else { return nil }
        return idx
    }

    /// 所有涵蓋游標左側音節的候選：先單字，再兩字詞、三字詞…
    /// 這樣「測試」中的「測」可以單獨換掉，也可以整個詞換掉。
    func candidatesAtCursor() -> [Candidate] {
        guard let target = targetIndex else { return [] }
        var result: [Candidate] = []
        for span in 1...LanguageModel.maxSpan {
            for start in max(0, target - span + 1)...target {
                let end = start + span
                guard end <= items.count, start + span > target else { continue }
                guard items[start..<end].allSatisfy(\.isChinese) else { continue }
                let keys = items[start..<end].map(\.keys).joined()
                for entry in LanguageModel.candidates(keys) {
                    result.append(Candidate(word: entry.word, start: start, span: span))
                }
            }
        }
        // 同一個詞可能從不同起點重複出現，保留先出現的（span 較短者）
        var seen = Set<String>()
        return result.filter { seen.insert($0.word).inserted }
    }

    mutating func choose(_ candidate: Candidate) {
        // 蓋住的範圍內原有的選擇要清掉，避免衝突
        for i in candidate.start..<(candidate.start + candidate.span) {
            overrides.removeValue(forKey: i)
        }
        overrides[candidate.start] = (candidate.word, candidate.span)
    }

    // MARK: - 顯示

    /// 組字區文字，以及游標應該落在第幾個字元。
    /// 游標可能落在一個詞的中間（「一個」的兩字之間），此時按音節比例換算。
    func marked(pendingKeys: String) -> (text: String, cursorOffset: Int) {
        var text = ""
        var found: Int? = nil
        for chunk in chunks() {
            if found == nil {
                if cursor <= chunk.range.lowerBound {
                    found = text.count
                } else if cursor < chunk.range.upperBound {
                    let within = cursor - chunk.range.lowerBound
                    found = text.count + min(within, chunk.text.count)
                }
            }
            text += chunk.text
        }
        var offset = found ?? text.count
        if !pendingKeys.isEmpty {
            let pendingText = Bopomofo.split(pendingKeys).map {
                $0.isChinese ? Bopomofo.symbols($0.keys) : $0.keys
            }.joined()
            text.insert(contentsOf: pendingText, at: text.index(text.startIndex, offsetBy: offset))
            offset += pendingText.count
        }
        return (text, offset)
    }
}
