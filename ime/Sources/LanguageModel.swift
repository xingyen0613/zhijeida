import Foundation

/// Unigram 語言模型與最佳路徑搜尋。
///
/// 作法沿用 McBopomofo 的 Gramambular：每個詞有獨立的對數機率，
/// 把一串音節排成 DAG，用動態規劃找總分最高的切法。
/// 常用詞的機率高過兩個單字碰巧相連，長詞優先是這個結果的自然產物。
///
/// 資料由 build-lm.py 從 McBopomofo 的 BPMFBase.txt / BPMFMappings.txt /
/// phrase.occ 編成，授權見 Data/LICENSE-McBopomofo.txt。
enum LanguageModel {

    /// 一個詞最多幾個音節
    static let maxSpan = 6

    /// 按鍵序列 -> 候選詞（依分數由高到低）
    private static let table: [String: [(word: String, score: Double)]] = load()

    private static func load() -> [String: [(String, Double)]] {
        guard let path = Bundle.main.path(forResource: "lm", ofType: "tsv")
                ?? ProcessInfo.processInfo.environment["LM_TSV"],
              let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            NSLog("SmartBopomofo: 找不到 lm.tsv")
            return [:]
        }
        var result = [String: [(String, Double)]](minimumCapacity: 140_000)
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            var fields = line.split(separator: "\t")
            guard fields.count >= 2 else { continue }
            let keys = String(fields.removeFirst())
            var list: [(String, Double)] = []
            list.reserveCapacity(fields.count)
            for field in fields {
                let pair = field.split(separator: " ")
                guard pair.count == 2, let score = Double(pair[1]) else { continue }
                list.append((String(pair[0]), score))
            }
            result[keys] = list
        }
        NSLog("SmartBopomofo: 語言模型載入 \(result.count) 個按鍵序列")
        return result
    }

    /// 這串按鍵對應的候選詞
    static func candidates(_ keys: String) -> [(word: String, score: Double)] {
        table[keys] ?? []
    }

    /// 一段音節的最佳切法。回傳每個詞涵蓋的音節範圍。
    struct Chunk {
        let word: String
        let range: Range<Int>   // 涵蓋 syllables 的哪幾個
    }

    /// overrides：使用者手動選過的詞，key 是起始音節位置
    static func walk(_ syllables: [String],
                     overrides: [Int: (word: String, span: Int)] = [:]) -> [Chunk] {
        let n = syllables.count
        guard n > 0 else { return [] }

        var best = [Double](repeating: -.infinity, count: n + 1)
        var from = [Chunk?](repeating: nil, count: n + 1)
        best[0] = 0

        for i in 0..<n where best[i] > -.infinity {
            // 使用者手動選過的詞，固定住不再參與搜尋
            if let fixed = overrides[i], i + fixed.span <= n {
                let end = i + fixed.span
                if best[i] > best[end] {
                    best[end] = best[i]
                    from[end] = Chunk(word: fixed.word, range: i..<end)
                }
                continue
            }
            for span in 1...min(maxSpan, n - i) {
                let keys = syllables[i..<(i + span)].joined()
                guard let top = candidates(keys).first else { continue }
                let score = best[i] + top.score
                if score > best[i + span] {
                    best[i + span] = score
                    from[i + span] = Chunk(word: top.word, range: i..<(i + span))
                }
            }
        }

        var chunks: [Chunk] = []
        var pos = n
        while pos > 0, let chunk = from[pos] {
            chunks.append(chunk)
            pos = chunk.range.lowerBound
        }
        return chunks.reversed()
    }
}
