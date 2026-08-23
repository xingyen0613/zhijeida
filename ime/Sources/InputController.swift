import Cocoa
import InputMethodKit

@objc(SmartBopomofoInputController)
class SmartBopomofoInputController: IMKInputController {

    /// 已完成、尚未上屏的段落
    private var composition = Composition()
    /// 正在輸入中的按鍵
    private var pending = ""
    private var candidatesVisible = false
    /// 候選視窗目前列出的項目，用來把選中的字串對應回音節範圍
    private var shownCandidates: [Candidate] = []

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
                // 英文詞之間的空白要保留，中文一聲的空白只是確認
                let afterEnglish = Bopomofo.split(pending).last.map { !$0.isChinese } ?? false
                flushPending()
                if afterEnglish { composition.insert(keys: " ", isChinese: false) }
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
            if candidatesVisible {
                if let picked = candidatesWindow?.selectedCandidateString() {
                    applyCandidate(matching: picked.string)
                }
                hideCandidates()
                update(client)
                return true
            }
            guard !pending.isEmpty || !composition.isEmpty else { return false }
            flushPending()
            commit(client)
            return true

        case #selector(NSResponder.deleteBackward(_:)):
            if !pending.isEmpty {
                pending.removeLast()
            } else if !composition.isEmpty {
                composition.deleteBackward()
            } else {
                return false
            }
            update(client)
            return true

        case #selector(NSResponder.moveToBeginningOfLine(_:)):
            guard !composition.isEmpty else { return false }
            flushPending()
            composition.moveCursorToStart()
            update(client)
            return true

        case #selector(NSResponder.moveToEndOfLine(_:)):
            guard !composition.isEmpty else { return false }
            flushPending()
            composition.moveCursorToEnd()
            update(client)
            return true

        case #selector(NSResponder.moveDown(_:)):
            if candidatesVisible { candidatesWindow?.moveDown(nil); return true }
            flushPending()
            shownCandidates = composition.candidatesAtCursor()
            guard !shownCandidates.isEmpty else { return false }
            update(client)
            showCandidates()
            return true

        case #selector(NSResponder.moveUp(_:)):
            if candidatesVisible { candidatesWindow?.moveUp(nil); return true }
            return false

        case #selector(NSResponder.moveLeft(_:)):
            if candidatesVisible { candidatesWindow?.moveLeft(nil); return true }
            guard !pending.isEmpty || !composition.isEmpty else { return false }
            flushPending()
            composition.moveCursor(-1)
            update(client)
            return true

        case #selector(NSResponder.moveRight(_:)):
            if candidatesVisible { candidatesWindow?.moveRight(nil); return true }
            guard !pending.isEmpty || !composition.isEmpty else { return false }
            flushPending()
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
        shownCandidates.map(\.word)
    }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        applyCandidate(matching: candidateString.string)
        if let client = client() { update(client) }
    }

    private func applyCandidate(matching word: String) {
        guard let picked = shownCandidates.first(where: { $0.word == word }) else { return }
        composition.choose(picked)
        hideCandidates()
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
        guard index < shownCandidates.count else { return }
        composition.choose(shownCandidates[index])
        hideCandidates()
        update(client)
    }

    // MARK: - 組字區

    /// 把 pending 的按鍵切成段落放進組字區
    private func flushPending() {
        guard !pending.isEmpty else { return }
        for part in Bopomofo.split(pending) {
            composition.insert(keys: part.keys, isChinese: part.isChinese)
        }
        pending = ""
    }

    private func update(_ client: IMKTextInput) {
        let (text, offset) = composition.marked(pendingKeys: pending)
        client.setMarkedText(text,
                             selectionRange: NSRange(location: offset, length: 0),
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
