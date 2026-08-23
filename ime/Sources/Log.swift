import Foundation

/// 輸入法跑在 IMK 進程裡，NSLog 不一定進得了 unified log，
/// 所以另外寫一份到 ~/Library/Logs/Zhijeida.log 方便除錯。
func imeLog(_ message: String) {
    NSLog("Zhijeida: \(message)")
    let path = NSHomeDirectory() + "/Library/Logs/Zhijeida.log"
    let stamp = ISO8601DateFormatter().string(from: Date())
    guard let data = "\(stamp)  \(message)\n".data(using: .utf8) else { return }
    if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    } else {
        try? data.write(to: URL(fileURLWithPath: path))
    }
}
