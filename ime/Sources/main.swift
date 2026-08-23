import Cocoa
import InputMethodKit

let kConnectionName = "com.yen.inputmethod.SmartBopomofo_Connection"

let server = IMKServer(name: kConnectionName, bundleIdentifier: Bundle.main.bundleIdentifier)

/// 候選字視窗。IMKCandidates 需要 server，所以在這裡建立供 controller 取用。
let candidatesWindow = IMKCandidates(server: server,
                                     panelType: kIMKSingleRowSteppingCandidatePanel)

NSLog("SmartBopomofo: server started (\(server != nil))")
NSApplication.shared.run()
