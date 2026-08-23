# zhijeida 直接打

macOS 的注音輸入法，讓你在中文輸入狀態下直接打英文，不必切換輸入法。

打 `hk4g4` 出「測試」，打 `good` 出 `good`——輸入法自己判斷哪個是哪個。

## 為什麼可行

在標準大千鍵盤下，26 個英文字母全部對應到注音符號，所以任何英文單字同時也是一串注音。
乍看無法區分，但只要使用者**會打聲調、一聲按空白**，就會出現兩個很強的約束：

1. 聲調鍵（3467）與空白是天然的邊界。
2. **一個單元內中文最多只有一個音節**——若有兩個，第一個後面就會出現聲調鍵或空白。

第 2 點是關鍵。它讓「整串構不成單一合法音節」直接成為英文的證據：

| 按鍵 | 注音 | 判定 |
|---|---|---|
| `cpu` | ㄏㄣㄧ | 不是合法音節 → 英文 |
| `sdk` `api` `npm` | — | 同上 |
| `d9` | ㄎㄞ | 合法音節 → 中文「開」 |
| `284` | ㄉㄚˋ | 全是數字，但仍是合法音節 → 中文「大」 |

以英文高頻詞測試，真正無法判別的只剩 `up`（ㄧㄣ 因/音）與 `i`（ㄛ 喔）兩個詞。

不打聲調的使用者不適用這套規則，需要另一套基於語言模型的做法。

## 功能

- **中英混打**：`macbooknji3` 自動切成 `macbook` + 「所」，中間不需要分隔符
- **自動選詞**：`hk4g4` 直接出「測試」而不是「冊市」
- **逐字修正**：組字區可移動游標、單獨替換某一個字、句中插入
- **候選涵蓋完整**：同音詞、同音單字、原始按鍵（判錯時選回數字或英文）都在同一份清單
- **學習你的用字**：手動選過的詞會提高權重，下次自動選字偏向它
- **數字與符號**：`1234567890` 不會被讀成注音；中文後的 `,` 自動變「，」，英文後維持半形

## 安裝

需要 macOS 12 以上。**不需要 Xcode**，Command Line Tools 的 `swiftc` 就能編譯。

```bash
./ime/fetch-data.sh    # 取得注音詞庫（見「授權」）
./ime/build-lm.py      # 編譯語言模型
./ime/build.sh         # 編譯輸入法
cp -R ime/build/Zhijeida.app ~/Library/Input\ Methods/
```

接著**登出再登入**（或重新開機）——macOS 只在登入時掃描輸入法目錄，這一步無法省略，
Apple 官方也確認目前沒有規避的方法（開發者論壇 thread 775526，Feedback FB23026482）。

登入後到「系統設定 → 鍵盤 → 輸入來源 → +→ 繁體中文」選擇 Zhijeida。

之後若只改了 Swift 程式碼、沒動 `Info.plist`，重新編譯後 `pkill -f Zhijeida` 即可，不必再登出。

## 操作

| 按鍵 | 行為 |
|---|---|
| `← →` | 以字為單位移動插入點 |
| `Home` / `End` | 跳到組字區頭尾 |
| `↓` | 對游標左側那個字叫出候選 |
| `↑↓` `←→` | 候選清單內移動 |
| `Enter` | 清單開著＝選定；否則送出組字區 |
| 數字鍵 | 清單開著時直接選第 N 個 |
| `Backspace` / `fn+Delete` | 刪除游標左側／右側一個 |
| `Esc` | 清空組字區 |

候選清單順序：多字詞 → 原始按鍵 → 同音單字，各組內依詞頻排序。

## 開發

```bash
./ime/run-tests.sh     # 49 項回歸測試，不需安裝輸入法
```

測試涵蓋中英判別、分詞、數字處理、候選排序、組字區編輯與使用者習慣學習。
`judge.py` 是最初的離線判別器原型，保留作為規則的參考實作。

除錯日誌寫在 `~/Library/Logs/Zhijeida.log`。IMK 進程的 `NSLog` 不一定進得了
unified log，所以另外寫一份檔案。

### 踩過的坑

IMK 會依 controller 實作了哪些方法來決定事件分派，加一個方法不只是多一條路，
而是改變既有的路。以下三者都曾導致按鍵完全不進判別邏輯：

- override `handle(_:client:)` → IMK 不再呼叫 `inputText`
- 實作 `inputText(_:key:modifiers:client:)` → 方向鍵與 Enter 也被送進文字路徑
- 在 `inputText` 或 `didCommand` 回傳 `false` → 按鍵落到應用程式手上，組字區被清空

另外 `NSApp.currentEvent` 在 IMK 進程中拿不到事件（按鍵經 IPC 送入，
不走 NSApplication 的事件循環），所以無法用它讀修飾鍵。

## 隱私

選字習慣存放在使用者自己的目錄，不在專案內：

```
~/Library/Application Support/Zhijeida/user-phrases.tsv
```

不是靠 `.gitignore` 擋——檔案根本不在 repo 裡。每個使用者帳號各自獨立，
要清除直接刪掉該檔案即可。輸入法不連網、不上傳任何內容。

## 授權

本專案為 MIT。

注音詞庫資料由 `ime/fetch-data.sh` 從 [McBopomofo](https://github.com/openvanilla/McBopomofo)
取得，不隨本專案散布：

- `BPMFBase.txt`、`phrase.occ`、`exclusion.txt` — MIT License,
  Copyright (c) 2011-2026 Mengjuei Hsieh et al.
- `BPMFMappings.txt` — 源自 libtabe 的 `tsi.src`，**BSD License**

自動選詞的作法沿用 McBopomofo 的 Gramambular：unigram 分數搭配 DAG 最短路徑。
它不看上下文，「測試」能勝過「冊」+「市」是因為常用詞的機率高於兩個單字碰巧相連。
