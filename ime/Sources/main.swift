import Cocoa
import InputMethodKit

let kConnectionName = "com.yen.inputmethod.Zhijeida_Connection"

let server = IMKServer(name: kConnectionName, bundleIdentifier: Bundle.main.bundleIdentifier)

/// 候選字視窗。IMKCandidates 需要 server，所以在這裡建立供 controller 取用。
let candidatesWindow = IMKCandidates(server: server,
                                     panelType: kIMKSingleColumnScrollingCandidatePanel)

// 系統預設底色偏淡，文字對比不足；加深底色（依淺色/深色模式各自調整）提高可讀性。
let candidatesBackgroundColor = NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        ? NSColor(white: 0.10, alpha: 1.0)
        : NSColor(white: 0.82, alpha: 1.0)
}
// setAttributes 是整包覆蓋而非合併，必須先讀回既有的再加上去。
// IMK 建立候選視窗時預設帶了 IMKCandidatesSendServerKeyEventFirst = 1
// （按鍵先送到 controller），直接覆蓋會把它洗掉，方向鍵就進不了
// didCommand(by:)，選字與組字區游標移動全部失靈。
var candidatesAttributes = candidatesWindow?.attributes() ?? [:]
candidatesAttributes[NSAttributedString.DocumentAttributeKey.backgroundColor] = candidatesBackgroundColor
candidatesWindow?.setAttributes(candidatesAttributes)

imeLog("server started (\(server != nil))")

// 預先載入資料，避免第一次輸入時卡頓，也讓載入問題在啟動時就浮現
imeDebug("bundle=\(Bundle.main.bundlePath)")
NSLog("Zhijeida: bpmf 音節 \(Bopomofo.isSyllable("d9") ? "OK" : "FAILED")")
NSLog("Zhijeida: lm 詞條 \(LanguageModel.candidates("hk4g4").first?.word ?? "FAILED")")
NSApplication.shared.run()
