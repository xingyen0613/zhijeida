import Cocoa
import InputMethodKit

@objc(SmartBopomofoInputController)
class SmartBopomofoInputController: IMKInputController {

    /// 尚未上屏的原始按鍵序列
    private var buffer = ""

    // MARK: - 判別

    /// 目前 buffer 該以什麼形式呈現：注音（中文）或原樣字母（英文）
    private var isChinese: Bool {
        Bopomofo.couldBeSyllable(buffer)
    }

    private var displayText: String {
        isChinese ? Bopomofo.symbols(buffer) : buffer
    }

    // MARK: - IMKInputController

    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        guard let s = string, let ch = s.first,
              let client = sender as? IMKTextInput else { return false }

        // 空白：結束目前單元。buffer 空的話讓空白照常輸入。
        if ch == " " {
            guard !buffer.isEmpty else { return false }
            commit(client)
            return true
        }

        // 聲調鍵：能構成合法音節就結束這個音節
        if Bopomofo.tone[ch] != nil {
            if Bopomofo.asSyllable(buffer + String(ch)) != nil {
                buffer += String(ch)
                commit(client)
                return true
            }
            // 構不成音節，聲調鍵本身不是字母，直接送出
            commit(client)
            client.insertText(s, replacementRange: NSRange(location: NSNotFound, length: 0))
            return true
        }

        buffer += String(ch)
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
        let text = displayText
        client.setMarkedText(text,
                             selectionRange: NSRange(location: text.count, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    private func commit(_ client: IMKTextInput) {
        guard !buffer.isEmpty else { return }
        let text = displayText
        NSLog("SmartBopomofo: commit keys=\(buffer) as=\(isChinese ? "ZH" : "EN") text=\(text)")
        buffer = ""
        client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
    }
}
