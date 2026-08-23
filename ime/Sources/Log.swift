import Foundation

/// 輸入法看得到使用者輸入的一切，因此日誌分兩級：
///
/// - `imeLog` 只記錄不涉及輸入內容的事件（啟動、資料載入、錯誤）。
/// - `imeDebug` 會帶出實際輸入的文字，**預設完全不記錄**，
///   需要除錯時才以環境變數開啟：
///
///       launchctl setenv ZHIJEIDA_DEBUG 1
///
/// 日誌與使用者詞彙都以 0600 建立，避免同機其他帳號讀取。
private let debugEnabled = ProcessInfo.processInfo.environment["ZHIJEIDA_DEBUG"] == "1"

private let logURL: URL = {
    let dir = NSHomeDirectory() + "/Library/Logs"
    return URL(fileURLWithPath: dir).appendingPathComponent("Zhijeida.log")
}()

/// 不含使用者輸入內容的事件
func imeLog(_ message: String) {
    NSLog("Zhijeida: \(message)")
    write(message)
}

/// 含使用者輸入內容，僅在明確開啟除錯時記錄
func imeDebug(_ message: String) {
    guard debugEnabled else { return }
    NSLog("Zhijeida: \(message)")
    write(message)
}

private func write(_ message: String) {
    let stamp = ISO8601DateFormatter().string(from: Date())
    guard let data = "\(stamp)  \(message)\n".data(using: .utf8) else { return }
    let path = logURL.path
    if !FileManager.default.fileExists(atPath: path) {
        FileManager.default.createFile(atPath: path, contents: nil,
                                       attributes: [.posixPermissions: 0o600])
    }
    guard let handle = FileHandle(forWritingAtPath: path) else { return }
    handle.seekToEndOfFile()
    handle.write(data)
    try? handle.close()
}
