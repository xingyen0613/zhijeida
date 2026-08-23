import Foundation

/// 模擬 InputController 的按鍵處理，驗證判別、分詞與選字。
func typed(_ keys: String) -> Composition {
    var comp = Composition()
    var pending = ""
    func flush() {
        guard !pending.isEmpty else { return }
        for part in Bopomofo.split(pending) {
            comp.insert(keys: part.keys, isChinese: part.isChinese)
        }
        pending = ""
    }
    for ch in keys.lowercased() {
        if ch == " " {
            // 英文詞之間的空白要保留，中文一聲的空白只是確認
            let afterEnglish = !pending.isEmpty
                && (Bopomofo.split(pending).last.map { !$0.isChinese } ?? false)
            flush()
            if afterEnglish { comp.insert(keys: " ", isChinese: false) }
            continue
        }
        pending.append(ch)
        if Bopomofo.tone[ch] != nil, Bopomofo.split(pending).last?.isChinese == true { flush() }
    }
    flush()
    return comp
}

var failures = 0
func check(_ label: String, _ got: String, _ want: String) {
    if got == want {
        print("  ✓ \(label)")
    } else {
        failures += 1
        print("  ✗ \(label)\n      得到 \(got)\n      應為 \(want)")
    }
}

print("中英混輸（真實樣本）")
check("整句混輸",
      typed("Up jo4ji32k72u04sl3g4macbooknji3u3u.3vu, u/4m/41j4vu; bj/6").text,
      "因為我的電腦是macbook所以有些應用不相容")
check("技術縮寫", typed("cpu ccl pcb ").text, "cpu ccl pcb ")
check("英文黏著注音", typed("macbooknji3").text, "macbook所")

print("\n分詞")
check("測試", typed("hk4g4").text, "測試")
check("開發", typed("d9 z8 ").text, "開發")
check("這是一個", typed("5k4g4u ek7").text, "這是一個")

print("\n數字")
check("英文接數字", typed("ji3g4xingyen0613").text, "我是xingyen0613")
check("手機號碼", typed("ji32k7g.3ru g40985463251").text, "我的手機是0985463251")
check("全數字仍是音節：大", typed("284").text, "大")
check("全數字仍是音節：八", typed("18").text, "八")

print("\n候選")
var c = typed("hk4g4")
c.moveCursor(-1)
let list = c.candidatesAtCursor()
check("常用詞排第一", list.first?.word ?? "", "測試")
check("含單字候選", list.contains { $0.span == 1 } ? "yes" : "no", "yes")

print("\n編輯")
var d = typed("d9 z8 ")
d.moveCursor(-1)
for part in Bopomofo.split("5k4") { d.insert(keys: part.keys, isChinese: part.isChinese) }
check("句中插入", d.text, "開這發")
var e = typed("5k4g4u ek7")
e.moveCursor(-1)
let (text, offset) = e.marked(pendingKeys: "")
check("游標落在詞中間", String(text.prefix(offset)) + "|" + String(text.dropFirst(offset)), "這是一|個")

print("\n判錯時選回原樣")
var f = typed("284")
let fList = f.candidatesAtCursor()
check("中文候選含原始按鍵", fList.contains { $0.word == "284" } ? "yes" : "no", "yes")
check("原始按鍵排在單字之前",
      (fList.firstIndex { $0.isLiteral } ?? 99) < (fList.firstIndex { $0.span == 1 && !$0.isLiteral } ?? 99)
        ? "yes" : "no", "yes")
if let literal = fList.first(where: { $0.isLiteral }) {
    f.choose(literal)
    check("選回數字", f.text, "284")
}
var g = typed("cpu ")
let gList = g.candidatesAtCursor()
check("英文段落也有候選", gList.isEmpty ? "no" : "yes", "yes")

print("\n全字母黏著（cpoep = cpo + 跟）")
var h = typed("cpoep ")
check("預設判為英文", h.text, "cpoep ")
h.moveCursorToStart()
h.moveCursor(1)
let hList = h.candidatesAtCursor()
check("候選含尾段的中文", hList.contains { $0.word == "跟" } ? "yes" : "no", "yes")
if let gen = hList.first(where: { $0.word == "跟" }) {
    h.choose(gen)
    check("選後切成 cpo + 跟", h.text, "cpo跟 ")
}

print("\n使用者選字習慣")
UserPhrases.reset()
let recordKeys = "ru4xj4"
let before = LanguageModel.candidates(recordKeys).first?.word ?? ""
check("預設選字", before, "紀錄")
UserPhrases.record(keys: recordKeys, word: "記錄")
check("選過一次後改為偏好", LanguageModel.candidates(recordKeys).first?.word ?? "", "記錄")
check("整句跟著改變", typed("ji3ul4ru4xj4").text.hasSuffix("記錄") ? "yes" : "no", "yes")
UserPhrases.reset()
check("清除後回到預設", LanguageModel.candidates(recordKeys).first?.word ?? "", "紀錄")

print(failures == 0 ? "\n全部通過" : "\n\(failures) 項失敗")
exit(failures == 0 ? 0 : 1)
