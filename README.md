# smart-bopomofo

macOS 注音輸入法的中英混輸判別器。目標是在中文輸入狀態下直接打英文，由輸入法判斷該串按鍵是中文還是英文單字，免去手動切換。

對標 Windows 上的華碩智慧輸入法（macOS 無官方版本）。

## 現況

- Phase 1：離線判別器（`judge.py`），已完成驗證。
- Phase 2：IMK 輸入法原型（`ime/`），可編譯安裝，待實機測試。

### Phase 2 已驗證的環境結論

- **不需要 Xcode**。Command Line Tools 的 `swiftc` 就能編譯 InputMethodKit，
  手工組 `.app` bundle 即可（見 `ime/build.sh`）。本機磁碟僅剩 21GB，裝不下 Xcode，
  這條路徑繞開了該限制。
- **ad-hoc 簽名可用**（`codesign --sign -`），自用不需要 Apple Developer Program。
- **安裝後必須登出再登入（或重開機）**，macOS 才會把新輸入法列進系統設定。
  `TISRegisterInputSource` 回傳成功也一樣。Apple DTS 工程師 2026-06 於開發者論壇
  確認無法規避（thread 775526，Feedback FB23026482）。
  開發迭代時：改 Info.plist 需登出；只改 Swift 邏輯應可 `pkill` 重啟進程即可（待驗證）。
- `InputMethodConnectionName` 使用 bundle identifier 形式較穩妥。
- 系統內建輸入法（`/System/Library/Input Methods/`）不是 IMK 架構，
  不能拿來當 Info.plist 範例，參考 McBopomofo 的配置。

Swift 版判別邏輯（`ime/Sources/Bopomofo.swift`）與 `judge.py` 對 147 個真實單元
比對結果完全一致。

## 核心原理

前提：使用者**會打聲調，一聲直接按空白鍵**。由此得到兩個約束：

1. 聲調鍵(3467)與空白是天然的單元邊界。
2. **一個單元內中文最多只有一個音節** —— 若有兩個，第一個後面就會出現聲調鍵或空白。

第 2 點是關鍵。它讓「整串構不成單一合法音節」直接成為英文的證據，
`cpu`=ㄏㄣㄧ、`mrvl`、`goog`、`csp` 都靠這條判定，**不需要任何詞典**。

英文與注音黏著時（`macbooknji3`），從尾部取最長合法音節，前綴即英文。
`skillsu3` 也因此切在正確位置（`su3`=ㄋㄧˇ 比 `u3`=ㄧˇ 長）。

不打聲調的使用者不適用，需要另一套基於語言模型的做法。

## 真實樣本驗證（10 句中英混輸，147 個輸入單元）

| 單元類型 | 佔比 | 判定依據 |
|---|---|---|
| 帶聲調的中文音節 | 68.7% | 聲調鍵即證據，零歧義 |
| 無聲調短單元 | 17.7% | 音節合法性 |
| 含 4+ 連續字母 | 13.6% | 一定有英文，11/20 與注音黏著 |

結果（排除使用者打錯字的 3 處）：

- 中文 101 個帶聲調音節：**全部正確**
- 英文 26 個詞：**不使用任何個人詞庫，正確 24 個**

重要發現：英文與中文之間**沒有分隔符**（`macbooknji3` = macbook + ㄙㄨㄛˇ），
不能按空白切 token。但聲調鍵補足了邊界資訊，實作反而比預期單純。

## 已知待辦

1. **嚴格音節表**：`eml`=ㄍㄩㄠ 在結構規則下合法（聲母+介音+韻母），
   但國語 ㄍ 不接 ㄩ。McBopomofo 的詞庫含完整音節資料，Phase 2 fork 進來即可解決。
2. **全字母黏著**：`cpoep`（cpo跟）沒有數字鍵當線索，判不出切點，
   這種情況仍需個人詞庫。目前樣本中僅此一例。
3. 個人詞庫的累積機制（使用者修正後自動收錄）。

## 使用

```bash
python3 judge.py samples/mine.txt
```

`userdict.txt`（選配，格式見 `userdict.example.txt`）會併入詞典，用於處理全字母黏著。

測試資料產生方式：切到英文輸入法，照平常中英混打的方式打一段
（中文部分照打注音鍵位含聲調，英文部分照打英文）。

`samples/*.txt` 與 `userdict.txt` 不進版控（含個人輸入內容與工作術語）。
