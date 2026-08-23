import Cocoa
import InputMethodKit

@objc(SmartBopomofoInputController)
class SmartBopomofoInputController: IMKInputController {

    /// 已完成、尚未上屏的段落
    private var composition = Composition()
    /// 正在輸入中的按鍵
    private var pending = ""
    private var candidatesVisible = false

    // MARK: - 輸入

    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        guard let s = string, let ch = s.first,
              let client = sender as? IMKTextInput else { return false }

        // 候選字視窗開啟時，數字鍵直接選字
        if candidatesVisible, let n = ch.wholeNumberValue, (1...9).contains(n) {
            selectCandidate(n - 1, client: client)
            return true
        }

        if ch == " " {
            // 有正在輸入的按鍵就先結算，否則把組字區送出
            if !pending.isEmpty {
                flushPending()
                update(client)
            } else if !composition.isEmpty {
                commit(client)
            } else {
                return false   // 沒有任何內容，讓空白照常輸入
            }
            return true
        }

        pending.append(ch)

        // 聲調鍵標記一個音節結束
        if Bopomofo.tone[ch] != nil {
            flushPending()
        }
        update(client)
        return true
    }

    override func didCommand(by aSelector: Selector!, client sender: Any!) -> Bool {
        guard let client = sender as? IMKTextInput else { return false }

        switch aSelector {
        case #selector(NSResponder.insertNewline(_:)):
            guard !pending.isEmpty || !composition.isEmpty else { return false }
            flushPending()
            commit(client)
            return true

        case #selector(NSResponder.deleteBackward(_:)):
            if !pending.isEmpty {
                pending.removeLast()
            } else if !composition.isEmpty {
                composition.removeLast()
            } else {
                return false
            }
            update(client)
            return true

        case #selector(NSResponder.moveDown(_:)):
            guard composition.currentSegment?.isChinese == true else { return false }
            showCandidates()
            return true

        case #selector(NSResponder.moveUp(_:)):
            hideCandidates()
            return true

        case #selector(NSResponder.moveLeft(_:)):
            guard !composition.isEmpty else { return false }
            composition.moveCursor(-1)
            update(client)
            return true

        case #selector(NSResponder.moveRight(_:)):
            guard !composition.isEmpty else { return false }
            composition.moveCursor(1)
            update(client)
            return true

        case #selector(NSResponder.cancelOperation(_:)):
            guard !pending.isEmpty || !composition.isEmpty else { return false }
            hideCandidates()
            pending = ""
            composition.clear()
            update(client)
            return true

        default:
            return false
        }
    }

    // MARK: - 候選字

    override func candidates(_ sender: Any!) -> [Any]! {
        composition.currentSegment?.candidates ?? []
    }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        guard let list = composition.currentSegment?.candidates,
              let idx = list.firstIndex(of: candidateString.string) else { return }
        composition.choose(idx)
        hideCandidates()
        if let client = client() { update(client) }
    }

    private func showCandidates() {
        candidatesWindow?.update()
        candidatesWindow?.show(kIMKLocateCandidatesBelowHint)
        candidatesVisible = true
    }

    private func hideCandidates() {
        candidatesWindow?.hide()
        candidatesVisible = false
    }

    private func selectCandidate(_ index: Int, client: IMKTextInput) {
        guard let list = composition.currentSegment?.candidates, index < list.count else { return }
        composition.choose(index)
        hideCandidates()
        update(client)
    }

    // MARK: - 組字區

    /// 把 pending 的按鍵切成段落放進組字區
    private func flushPending() {
        guard !pending.isEmpty else { return }
        for part in Bopomofo.split(pending) {
            composition.append(keys: part.keys, isChinese: part.isChinese)
        }
        pending = ""
    }

    private func update(_ client: IMKTextInput) {
        let text = composition.marked(pendingKeys: pending)
        client.setMarkedText(text,
                             selectionRange: NSRange(location: text.count, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    private func commit(_ client: IMKTextInput) {
        flushPending()
        guard !composition.isEmpty else { return }
        let text = composition.text
        NSLog("SmartBopomofo: commit -> \(text)")
        composition.clear()
        hideCandidates()
        client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    override func commitComposition(_ sender: Any!) {
        guard let client = sender as? IMKTextInput else { return }
        commit(client)
    }
}
