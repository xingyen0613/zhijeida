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
    let score: Double
    /// 原始按鍵本身（數字或英文），供判錯時選回去
    var isLiteral: Bool = false
    /// 若這個候選是從英文段落的尾段切出來的，這是切剩的英文前綴
    var englishPrefix: String? = nil
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

    /// 把一串待處理的按鍵切段後插入。
    /// InputController 與測試共用這裡，避免兩邊邏輯漂移。
    mutating func insertPending(_ keys: String) {
        for part in Bopomofo.split(keys) {
            if part.isChinese {
                insert(keys: part.keys, isChinese: true)
            } else {
                // 符號拆成獨立單位，游標才能移進 () 之間
                for token in Bopomofo.englishTokens(part.keys) {
                    insert(keys: token, isChinese: false)
                }
            }
        }
    }

    mutating func deleteForward() {
        guard cursor < items.count else { return }
        items.remove(at: cursor)
        overrides.removeValue(forKey: cursor)
        shiftOverrides(from: cursor + 1, by: -1)
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
                let overridden = overrides[i]?.word
                result.append(Chunk(text: overridden ?? items[i].keys,
                                    isChinese: overridden != nil, range: i..<(i + 1)))
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

    /// 使用者這次明確選過的詞，送出時用來累積個人習慣
    func userChoices() -> [(keys: String, word: String)] {
        overrides.compactMap { start, choice in
            let end = start + choice.span
            guard end <= items.count else { return nil }
            let keys = items[start..<end].map(\.keys).joined()
            // 選回原始按鍵不是詞彙偏好，不必記錄
            guard keys != choice.word else { return nil }
            return (keys, choice.word)
        }
    }

    // MARK: - 選字

    /// 選字針對的位置：游標左側那個；游標在最前面時改看右側第一個
    private var targetIndex: Int? {
        let idx = cursor > 0 ? cursor - 1 : 0
        guard idx >= 0, idx < items.count else { return nil }
        return idx
    }

    /// 游標左側那「一個字」在顯示文字中的範圍。
    /// 即使它屬於某個詞（「測試」的「測」），也只標示該字，選字以字為單位。
    func highlightRange() -> Range<Int>? {
        guard let target = targetIndex else { return nil }
        var offset = 0
        for chunk in chunks() {
            if chunk.range.contains(target) {
                let within = target - chunk.range.lowerBound
                guard within < chunk.text.count else {
                    return offset..<(offset + chunk.text.count)
                }
                return (offset + within)..<(offset + within + 1)
            }
            offset += chunk.text.count
        }
        return nil
    }

    /// 所有涵蓋游標左側音節的候選。
    ///
    /// 詞排在單字前面：同音單字動輒數十個，若照長度排會把「測試」這種
    /// 常用詞擠到幾十位之後。詞與單字各自依分數由高到低。
    func candidatesAtCursor() -> [Candidate] {
        guard let target = targetIndex else { return [] }
        let literal = items[target].keys

        // 英文段落：除了整串對應的中文，也列出尾段可能構成的字。
        // cpoep 是「cpo」+「跟」，沒有非字母鍵當線索時判不出切點，交給使用者選。
        guard items[target].isChinese else {
            var list = LanguageModel.candidates(literal).map {
                Candidate(word: $0.word, start: target, span: 1, score: $0.score)
            }
            for offset in 0..<literal.count {
                let idx = literal.index(literal.startIndex, offsetBy: offset)
                let tail = String(literal[idx...])
                let prefix = String(literal[..<idx])
                guard offset > 0 || !prefix.isEmpty || literal.count > 0 else { continue }
                // 尾段本身，以及尾段再接上後面幾個中文音節（56 + 接 = 直接）
                for extra in 0..<LanguageModel.maxSpan {
                    let end = target + 1 + extra
                    guard end <= items.count else { break }
                    guard items[(target + 1)..<end].allSatisfy(\.isChinese) else { break }
                    let keys = tail + items[(target + 1)..<end].map(\.keys).joined()
                    for entry in LanguageModel.candidates(keys) {
                        list.append(Candidate(word: entry.word, start: target,
                                              span: 1 + extra, score: entry.score,
                                              englishPrefix: offset == 0 ? "" : prefix))
                    }
                }
            }
            // 同一個字可能從不同切點出現，保留前綴最長的（切得最少）
            var seen = Set<String>()
            list = list.filter { seen.insert($0.word + ($0.englishPrefix ?? "")).inserted }
            list.sort { $0.score > $1.score }
            list.append(Candidate(word: literal, start: target, span: 1,
                                  score: 0, isLiteral: true))
            return list
        }

        var result: [Candidate] = []
        for span in 1...LanguageModel.maxSpan {
            for start in max(0, target - span + 1)...target {
                let end = start + span
                guard end <= items.count, start + span > target else { continue }
                guard items[start..<end].allSatisfy(\.isChinese) else { continue }
                let keys = items[start..<end].map(\.keys).joined()
                for entry in LanguageModel.candidates(keys) {
                    result.append(Candidate(word: entry.word, start: start,
                                            span: span, score: entry.score))
                }
            }
        }
        // 同一個詞可能從不同起點重複出現，保留分數最高的那個
        var best: [String: Candidate] = [:]
        for candidate in result {
            if let existing = best[candidate.word], existing.score >= candidate.score { continue }
            best[candidate.word] = candidate
        }
        var list = best.values.sorted {
            if ($0.span == 1) != ($1.span == 1) { return $0.span > $1.span }
            return $0.score > $1.score
        }
        // 原始按鍵排在多字詞之後、同音單字之前，判錯時容易找到
        if !list.contains(where: { $0.word == literal }) {
            let insertAt = list.firstIndex { $0.span == 1 } ?? list.count
            list.insert(Candidate(word: literal, start: target, span: 1,
                                  score: 0, isLiteral: true), at: insertAt)
        }
        return list
    }

    mutating func choose(_ candidate: Candidate) {
        // 從英文段落切出中文：把該段拆成「英文前綴」與「中文音節」兩個 item
        if let prefix = candidate.englishPrefix, candidate.start < items.count {
            let whole = items[candidate.start].keys
            guard prefix.count < whole.count else { return }
            let syllable = String(whole.dropFirst(prefix.count))
            if prefix.isEmpty {
                // 整段都是中文，不需要拆
                items[candidate.start] = .chinese(keys: syllable)
                overrides[candidate.start] = (candidate.word, candidate.span)
            } else {
                items[candidate.start] = .english(prefix)
                items.insert(.chinese(keys: syllable), at: candidate.start + 1)
                shiftOverrides(from: candidate.start + 1, by: 1)
                overrides[candidate.start + 1] = (candidate.word, candidate.span)
                if cursor > candidate.start { cursor += 1 }
            }
            return
        }
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
