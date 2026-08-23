import Foundation

/// 組字區的一個段落：一個中文音節，或一段英文。
struct Segment {
    let keys: String
    let isChinese: Bool
    /// 中文段落選用第幾個候選字
    var choice: Int = 0

    var candidates: [String] {
        isChinese ? Bopomofo.candidates(keys) : []
    }

    /// 顯示與上屏用的文字
    var text: String {
        guard isChinese else { return keys }
        let list = candidates
        guard !list.isEmpty else { return Bopomofo.symbols(keys) }
        return list[min(choice, list.count - 1)]
    }
}

/// 尚未上屏的組字內容。游標指向的段落可以換字。
struct Composition {
    private(set) var segments: [Segment] = []
    /// 游標所在段落索引；等於 segments.count 表示在最後面
    private(set) var cursor: Int = 0

    var isEmpty: Bool { segments.isEmpty }
    var text: String { segments.map(\.text).joined() }

    /// 游標所在的段落，用於顯示候選字
    var currentSegment: Segment? {
        guard cursor < segments.count else { return nil }
        return segments[cursor]
    }

    mutating func append(keys: String, isChinese: Bool) {
        segments.append(Segment(keys: keys, isChinese: isChinese))
        cursor = segments.count
    }

    mutating func removeLast() {
        guard !segments.isEmpty else { return }
        segments.removeLast()
        cursor = segments.count
    }

    mutating func clear() {
        segments.removeAll()
        cursor = 0
    }

    mutating func moveCursor(_ delta: Int) {
        let upper = max(segments.count - 1, 0)
        cursor = min(max(cursor + delta, 0), upper)
    }

    mutating func choose(_ index: Int) {
        guard cursor < segments.count else { return }
        segments[cursor].choice = index
    }

    /// 組字區顯示字串，游標所在的中文段落用括號標示
    func marked(pendingKeys: String) -> String {
        var parts: [String] = []
        for (i, seg) in segments.enumerated() {
            parts.append(i == cursor && seg.isChinese ? "[\(seg.text)]" : seg.text)
        }
        if !pendingKeys.isEmpty {
            parts.append(Bopomofo.split(pendingKeys).map {
                $0.isChinese ? Bopomofo.symbols($0.keys) : $0.keys
            }.joined())
        }
        return parts.joined()
    }
}
