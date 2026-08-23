import Foundation

/// 使用者的選字習慣。
///
/// 刻意存放在使用者自己的 Application Support 目錄，而不是專案目錄，
/// 這樣個人使用記錄不會有任何機會被提交進版控。
/// 每個使用者帳號各自獨立，換人使用就是一份新的統計。
enum UserPhrases {

    /// 每被選用一次加多少分。
    /// 分數是對數機率，同音詞之間的差距常在 1~3（「紀錄」與「記錄」相差 1.49），
    /// 給 3.0 是為了讓「使用者明確選過一次」就足以翻轉，不必重選好幾遍。
    private static let step = 3.0
    /// 加成上限，選再多次也不會無限膨脹
    private static let cap = 9.0

    private static let fileURL: URL = {
        // 測試時導向暫存路徑，避免污染使用者真實的記錄
        if let path = ProcessInfo.processInfo.environment["USER_PHRASES_PATH"] {
            return URL(fileURLWithPath: path)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
            .appendingPathComponent("Zhijeida", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("user-phrases.tsv")
    }()

    /// 按鍵序列 -> 詞 -> 被選用次數
    private static var counts: [String: [String: Int]] = load()

    private static func load() -> [String: [String: Int]] {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return [:] }
        var result: [String: [String: Int]] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "\t")
            guard parts.count == 3, let count = Int(parts[2]) else { continue }
            result[String(parts[0]), default: [:]][String(parts[1])] = count
        }
        imeLog("使用者詞彙載入 \(result.count) 個按鍵序列")
        return result
    }

    static var isEmpty: Bool { counts.isEmpty }

    /// 這個詞被選用過幾次，換算成分數加成
    static func boost(keys: String, word: String) -> Double {
        guard let count = counts[keys]?[word] else { return 0 }
        return min(Double(count) * step, cap)
    }

    /// 記錄一次使用者的明確選擇
    static func record(keys: String, word: String) {
        counts[keys, default: [:]][word, default: 0] += 1
        imeLog("記住選擇 \(keys) -> \(word)（第 \(counts[keys]![word]!) 次）")
        save()
    }

    private static func save() {
        let text = counts.flatMap { keys, words in
            words.map { "\(keys)\t\($0.key)\t\($0.value)" }
        }.sorted().joined(separator: "\n")
        try? text.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// 清除所有使用者記錄
    static func reset() {
        counts.removeAll()
        try? FileManager.default.removeItem(at: fileURL)
        imeLog("已清除使用者詞彙記錄")
    }
}
