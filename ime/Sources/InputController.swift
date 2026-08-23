import Cocoa
import InputMethodKit

@objc(SmartBopomofoInputController)
class SmartBopomofoInputController: IMKInputController {

    /// 尚未上屏的原始按鍵序列
    private var buffer = ""

    /// 組字區呈現：中文段落顯示注音，英文段落顯示原樣字母
    private var markedText: String {
        Bopomofo.split(buffer).map {
            $0.isChinese ? Bopomofo.symbols($0.keys) : $0.keys
        }.joined()
    }

    /// 上屏內容：中文段落取最常用的漢字
    private var committedText: String {
        Bopomofo.split(buffer).map { part in
            guard part.isChinese else { return part.keys }
            return Bopomofo.candidates(part.keys).first ?? Bopomofo.symbols(part.keys)
        }.joined()
    }

    /// buffer 是否以英文結尾（決定空白要不要一起送出）
    private var endsWithEnglish: Bool {
        Bopomofo.split(buffer).last.map { !$0.isChinese } ?? false
    }

    // MARK: - IMKInputController

    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        guard let s = string, let ch = s.first,
              let client = sender as? IMKTextInput else { return false }

        // 空白：結束目前單元。英文詞之間的空白要保留，中文一聲的空白是選字確認。
        if ch == " " {
            guard !buffer.isEmpty else { return false }
            let keepSpace = endsWithEnglish
            commit(client)
            if keepSpace {
                client.insertText(" ", replacementRange: NSRange(location: NSNotFound, length: 0))
            }
            return true
        }

        buffer.append(ch)

        // 聲調鍵標記一個音節結束，一律結算
        if Bopomofo.tone[ch] != nil {
            commit(client)
            return true
        }

        update(client)
        return true
    }

    override func didCommand(by aSelector: Selector!, client sender: Any!) -> Bool {
        guard let client = sender as? IMKTextInput else { return false }
        switch aSelector {
        case #selector(NSResponder.deleteBackward(_:)):
            guard !buffer.isEmpty else { return false }
            buffer.removeLast()
            update(client)
            return true
        case #selector(NSResponder.insertNewline(_:)):
            guard !buffer.isEmpty else { return false }
            commit(client)
            return true
        default:
            return false
        }
    }

    override func commitComposition(_ sender: Any!) {
        guard let client = sender as? IMKTextInput else { return }
        commit(client)
    }

    // MARK: - 組字區

    private func update(_ client: IMKTextInput) {
        let text = markedText
        client.setMarkedText(text,
                             selectionRange: NSRange(location: text.count, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    private func commit(_ client: IMKTextInput) {
        guard !buffer.isEmpty else { return }
        let text = committedText
        NSLog("SmartBopomofo: commit keys=\(buffer) -> \(text)")
        buffer = ""
        client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
    }
}
