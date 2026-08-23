import Cocoa
import InputMethodKit

let kConnectionName = "com.yen.inputmethod.SmartBopomofo_Connection"

let server = IMKServer(name: kConnectionName, bundleIdentifier: Bundle.main.bundleIdentifier)

/// 候選字視窗。IMKCandidates 需要 server，所以在這裡建立供 controller 取用。
let candidatesWindow = IMKCandidates(server: server,
                                     panelType: kIMKSingleColumnScrollingCandidatePanel)

imeLog("server started (\(server != nil))")

// 預先載入資料，避免第一次輸入時卡頓，也讓載入問題在啟動時就浮現
imeLog("bundle=\(Bundle.main.bundlePath)")
NSLog("SmartBopomofo: bpmf 音節 \(Bopomofo.isSyllable("d9") ? "OK" : "FAILED")")
NSLog("SmartBopomofo: lm 詞條 \(LanguageModel.candidates("hk4g4").first?.word ?? "FAILED")")
NSApplication.shared.run()
