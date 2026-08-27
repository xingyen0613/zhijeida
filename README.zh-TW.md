# zhijeida 直接打

[English](README.md) | 繁體中文

macOS 的注音輸入法，讓你在中文輸入狀態下直接打英文，不必切換輸入法。

打 `hk4g4` 出「測試」，打 `good` 出 `good`——輸入法自己判斷哪個是哪個。

## 為什麼可行

在標準大千鍵盤下，26 個英文字母全部對應到注音符號，所以任何英文單字同時也是一串注音。
乍看無法區分，但只要使用者**會打聲調、一聲按空白**，就會出現兩個很強的約束：

1. 聲調鍵(3467)與空白是天然的邊界。
2. **一個單元內中文最多只有一個音節**——若有兩個，第一個後面就會出現聲調鍵或空白。

第 2 點是關鍵。它讓「整串構不成單一合法音節」直接成為英文的證據：

| 按鍵 | 注音 | 判定 |
|---|---|---|
| `cpu` | ㄏㄣㄧ | 不是合法音節 → 英文 |
| `sdk` `api` `npm` | — | 同上 |
| `d9` | ㄎㄞ | 合法音節 → 中文「開」 |
| `284` | ㄉㄚˋ | 全是數字，但仍是合法音節 → 中文「大」 |

以英文高頻詞測試，真正無法判別的只剩 `up`(ㄧㄣ 因/音)與 `i`(ㄛ 喔)兩個詞。

不打聲調的使用者不適用這套規則，需要另一套基於語言模型的做法。

## 功能

- **中英混打**：`macbooknji3` 自動切成 `macbook` + 「所」，中間不需要分隔符
- **自動選詞**：`hk4g4` 直接出「測試」而不是「冊市」
- **逐字修正**：組字區可移動游標、單獨替換某一個字、句中插入
- **候選涵蓋完整**：同音詞、同音單字、原始按鍵(判錯時選回數字或英文)都在同一份清單
- **學習你的用字**：手動選過的詞會提高權重，下次自動選字偏向它
- **數字與符號**：`1234567890` 不會被讀成注音；中文後的 `,` 自動變「，」，英文後維持半形

## 下載安裝

到 [Releases](https://github.com/xingyen0613/zhijeida/releases) 下載 **`Zhijeida-0.1.2.pkg`**，
只有這一個檔案，Apple Silicon 與 Intel 共用。需要 macOS 12 以上。

**1. 打開安裝檔。** 第一次打開會被系統擋下，說「無法打開，因為無法驗證開發者」。
這個輸入法沒有 Apple 的開發者簽章(簽章與公證需要付費的 Apple Developer Program)，
不是檔案有問題。到「**系統設定 → 隱私權與安全性**」往下捲，會看到剛才被擋的檔案，
按「**仍要打開**」，再打開一次安裝檔即可。

**2. 一路按「繼續」完成安裝。** 輸入法會裝進你自己的家目錄
(`~/Library/Input Methods`)，不需要管理員密碼，也不會動到系統檔案。

**3. 重新開機。** 安裝程式最後會請你重開機。macOS 只在開機登入時掃描輸入法目錄，
這一步無法省略，Apple 官方也確認目前沒有規避的方法
(開發者論壇 thread 775526，Feedback FB23026482)。

**4. 加進輸入來源。** 重開機後到「**系統設定 → 鍵盤 → 輸入來源 → 編輯**」，
按左下角的 **+**，選「**繁體中文**」，在清單裡找到 **Zhijeida** 並加入。

之後用選單列右上角的輸入法選單、或 `Control + Space` 切換過去，就能開始打字。
要移除的話，刪掉 `~/Library/Input Methods/Zhijeida.app` 再重開機。

### Intel Mac

安裝檔是 universal binary，`arm64` 與 `x86_64` 兩個架構都包在裡面。`x86_64` 那一半
已在 Apple Silicon 上透過 Rosetta 確認能正常啟動、載入語言模型並正確查到詞條，
但**沒有在真正的 Intel 機器上測過**。如果你在 Intel Mac 上裝完沒反應、或輸入行為不正常，
請開一個 [issue](https://github.com/xingyen0613/zhijeida/issues) 回報，附上你的 macOS 版本。

## 從原始碼編譯

**不需要 Xcode**，Command Line Tools 的 `swiftc` 就能編譯。

```bash
./ime/fetch-data.sh    # 取得注音詞庫(見「授權」)
./ime/build-lm.py      # 編譯語言模型
./ime/build.sh         # 編譯輸入法
cp -R ime/build/Zhijeida.app ~/Library/Input\ Methods/
```

接著重新開機(登出再登入也可以)，然後照上面第 4 步加進輸入來源。

之後若只改了 Swift 程式碼、沒動 `Info.plist`，重新編譯後 `pkill -f Zhijeida` 即可，
不必再重開機。

要產生給別人下載的安裝檔：

```bash
./ime/make-installer.sh    # 產出 ime/build/Zhijeida-<版本>.pkg
```

這個腳本會用 `./build.sh --universal` 編出雙架構的 binary，把詞庫授權一併放進 bundle，
再用 `pkgbuild` / `productbuild` 打包成裝到家目錄的安裝檔。
安裝檔不進版控，發布時上傳到 GitHub Releases。

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

除錯日誌寫在 `~/Library/Logs/Zhijeida.log`(IMK 進程的 `NSLog` 不一定進得了
unified log，所以另外寫一份檔案)。

**預設只記錄啟動與載入事件，不含任何輸入內容。** 需要追查判別問題時才開啟：

```bash
launchctl setenv ZHIJEIDA_DEBUG 1     # 開啟後會記錄實際輸入的文字
launchctl unsetenv ZHIJEIDA_DEBUG     # 關閉
```

### 踩過的坑

IMK 會依 controller 實作了哪些方法來決定事件分派，加一個方法不只是多一條路，
而是改變既有的路。以下三者都曾導致按鍵完全不進判別邏輯：

- override `handle(_:client:)` → IMK 不再呼叫 `inputText`
- 實作 `inputText(_:key:modifiers:client:)` → 方向鍵與 Enter 也被送進文字路徑
- 在 `inputText` 或 `didCommand` 回傳 `false` → 按鍵落到應用程式手上，組字區被清空

另外 `NSApp.currentEvent` 在 IMK 進程中拿不到事件(按鍵經 IPC 送入，
不走 NSApplication 的事件循環)，所以無法用它讀修飾鍵。

## 隱私

選字習慣存放在使用者自己的目錄，不在專案內：

```
~/Library/Application Support/Zhijeida/user-phrases.tsv
```

不是靠 `.gitignore` 擋——檔案根本不在 repo 裡。每個使用者帳號各自獨立，
要清除直接刪掉該檔案即可。輸入法不連網、不上傳任何內容。

輸入法看得到使用者輸入的一切，因此：

- 日誌**預設不記錄輸入內容**，需以 `ZHIJEIDA_DEBUG=1` 明確開啟
- 使用者詞彙與日誌都以 `0600` 建立，同機其他帳號無法讀取
- 密碼欄位由 macOS 的 Secure Input 保護，第三方輸入法在該狀態下會被系統停用

`ime/fetch-data.sh` 會從 GitHub 下載詞庫資料，來源固定在特定 commit
(見腳本中的 `MCBOPOMOFO_COMMIT`)，因此不同時間取得的資料完全一致，
上游日後的變動不會影響既有建置。要更新詞庫時換掉該 SHA 並重跑測試。

輸入法本身在執行期不連網。詞庫資料是純文字對照表，解析過程不涉及
程式碼執行，因此即使資料遭竄改也只會影響選字結果，不會危及系統。

## 授權

本專案為 MIT。

注音詞庫資料由 `ime/fetch-data.sh` 從 [McBopomofo](https://github.com/openvanilla/McBopomofo)
取得，原始檔不進本專案版控：

- `BPMFBase.txt`、`phrase.occ`、`exclusion.txt` — MIT License,
  Copyright (c) 2011-2026 Mengjuei Hsieh et al.
- `BPMFMappings.txt` — 源自 libtabe 的 `tsi.src`，**BSD License**

Releases 提供的安裝檔內含由這些資料編出的 `lm.tsv` 與 `bpmf.tsv`，屬於衍生著作。
MIT 與 BSD 都允許再散布，條件是隨附授權全文，因此 `LICENSE-McBopomofo.txt`
一併放在 app bundle 的 `Contents/Resources/` 裡。

自動選詞的作法沿用 McBopomofo 的 Gramambular：unigram 分數搭配 DAG 最短路徑。
它不看上下文，「測試」能勝過「冊」+「市」是因為常用詞的機率高於兩個單字碰巧相連。
