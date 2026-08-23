import Cocoa
import InputMethodKit

let kConnectionName = "com.smartbopomofo.inputmethod_Connection"

// IMKServer 需要 Info.plist 中的 InputMethodConnectionName 與此一致
let server = IMKServer(name: kConnectionName,
                       bundleIdentifier: Bundle.main.bundleIdentifier)
NSLog("SmartBopomofo: server started (\(server != nil))")
NSApplication.shared.run()
