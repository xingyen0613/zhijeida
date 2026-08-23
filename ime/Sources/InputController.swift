import Cocoa
import InputMethodKit

@objc(ZhijeidaInputController)
class ZhijeidaInputController: IMKInputController {

    /// 已完成、尚未上屏的段落
    private var composition = Composition()
    /// 正在輸入中的按鍵
    private var pending = ""
    private var candidatesVisible = false
    /// 上次送出的內容是否以中文結尾，組字區清空後仍要據此判斷符號形式
    private var lastCommitWasChinese = false
    /// 候選視窗目前列出的項目，用來把選中的字串對應回音節範圍
    private var shownCandidates: [Candidate] = []

    // MARK: - 輸入

    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        guard let s = string, let ch = s.first,
              let client = sender as? IMKTextInput else { return false }

        // 私有區字元（方向鍵等）與控制字元不是可輸入的文字，直接忽略。
        // 注意這裡要吃掉而不是回傳 false —— 回傳 false 會讓按鍵落到
        // 應用程式手上，組字區就被清掉了。
        if let scalar = ch.unicodeScalars.first {
            let isFunctionKey = (0xF700...0xF8FF).contains(scalar.value)
            let isControl = scalar.value < 0x20 || scalar.value == 0x7F
            if isFunctionKey || isControl {
                imeLog("忽略非文字按鍵 U+\(String(scalar.value, radix: 16))")
                return !composition.isEmpty || !pending.isEmpty
            }
        }

        // 符號依前文自動決定全形或半形。
        //
        // 原本想用 Option / Ctrl + 符號來切換，但兩條路都不通：
        // Ctrl 組合被應用程式攔在輸入法之前（日誌收不到按鍵），
        // 而 IMK 是透過 IPC 送按鍵進來、不走 NSApplication 的事件循環，
        // NSApp.currentEvent 因此拿不到修飾鍵。能取得修飾鍵的
        // inputText(_:key:modifiers:client:) 與 handle(_:client:)
        // 都會改變 IMK 的事件分派（先前已因此回歸三次）。
        //
        // 看前一個字是中文還是英文更穩，也更貼近實際書寫習慣。
        if pending.isEmpty, let full = Symbols.full(s),
           composition.precededByChinese || (composition.isEmpty && lastCommitWasChinese) {
            imeLog("中文後的符號 \(s) -> \(full)")
            composition.insert(keys: full, isChinese: false)
            update(client)
            return true
        }

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

        // 聲調鍵標記一個音節結束。但數字鍵同時是聲調鍵，
        // 打長數字串時尾段不是中文，就不該結算。
        if Bopomofo.tone[ch] != nil, Bopomofo.split(pending).last?.isChinese == true {
            flushPending()
        }
        update(client)
        return true
    }

    override func didCommand(by aSelector: Selector!, client sender: Any!) -> Bool {
        imeLog("command \(aSelector.map(NSStringFromSelector) ?? "nil") pending=\(pending) items=\(composition.itemCount)")
        guard let client = sender as? IMKTextInput else { return false }

        switch aSelector {
        case #selector(NSResponder.insertNewline(_:)):
            if candidatesVisible {
                // 交給候選視窗處理，它會回調 candidateSelected
                candidatesWindow?.interpretKeyEvents([
                    NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                     timestamp: 0, windowNumber: 0, context: nil,
                                     characters: "\r", charactersIgnoringModifiers: "\r",
                                     isARepeat: false, keyCode: 36)
                ].compactMap { $0 })
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

        case #selector(NSResponder.deleteForward(_:)):
            guard !composition.isEmpty || !pending.isEmpty else { return false }
            flushPending()
            composition.deleteForward()
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
            // 沒有在組字就讓應用程式自己處理（換行、移動游標）
            guard !pending.isEmpty || !composition.isEmpty else { return false }
            flushPending()
            shownCandidates = composition.candidatesAtCursor()
            imeLog("候選 \(shownCandidates.count) 項：\(shownCandidates.prefix(5).map(\.word).joined(separator: "/"))")
            update(client)
            // 即使沒有候選也要吃掉這個按鍵，否則組字區會被應用程式清掉
            guard !shownCandidates.isEmpty else {
                imeLog("游標處沒有候選")
                return true
            }
            showCandidates()
            return true

        case #selector(NSResponder.moveUp(_:)):
            if candidatesVisible { candidatesWindow?.moveUp(nil); return true }
            return false   // 不在選字就放行

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
        NSLog("Zhijeida: candidateSelected \(candidateString?.string ?? "nil")")
        applyCandidate(matching: candidateString?.string ?? "")
        if let client = client() {
            update(client)
        } else {
            imeLog("client() 為 nil，畫面沒更新")
        }
    }

    private func applyCandidate(matching word: String) {
        guard let picked = shownCandidates.first(where: { $0.word == word }) else {
            imeLog("候選 \(word) 不在清單中（\(shownCandidates.count) 項）")
            return
        }
        imeLog("選定 \(picked.word) start=\(picked.start) span=\(picked.span)")
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
        imeLog("數字鍵選 \(shownCandidates[index].word)")
        composition.choose(shownCandidates[index])
        hideCandidates()
        update(client)
    }

    // MARK: - 組字區

    /// 把 pending 的按鍵切成段落放進組字區
    private func flushPending() {
        guard !pending.isEmpty else { return }
        composition.insertPending(pending)
        pending = ""
    }

    private func update(_ client: IMKTextInput) {
        let (text, offset) = composition.marked(pendingKeys: pending)
        let attributed = NSMutableAttributedString(string: text)
        let whole = NSRange(location: 0, length: (text as NSString).length)
        attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: whole)
        // 游標所在的字用粗底線，讓使用者看得出現在會改到哪一個
        if pending.isEmpty, let hl = composition.highlightRange() {
            let ns = NSRange(location: hl.lowerBound, length: hl.count)
            if NSMaxRange(ns) <= whole.length {
                attributed.addAttribute(.underlineStyle,
                                        value: NSUnderlineStyle.thick.rawValue, range: ns)
            }
        }
        client.setMarkedText(attributed,
                             selectionRange: NSRange(location: offset, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    private func commit(_ client: IMKTextInput) {
        flushPending()
        guard !composition.isEmpty else { return }
        let text = composition.text
        imeLog("commit -> \(text)")
        lastCommitWasChinese = text.last.map { ("\u{4E00}"..."\u{9FFF}").contains(String($0)) } ?? false
        // 記住這次手動選過的詞，下次自動選字會偏向它
        for choice in composition.userChoices() {
            UserPhrases.record(keys: choice.keys, word: choice.word)
        }
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
