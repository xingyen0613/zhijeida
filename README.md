# zhijeida (直接打)

English | [繁體中文](README.zh-TW.md)

A Zhuyin (Bopomofo) input method for macOS that lets you type English directly while in Chinese input mode — no need to switch input methods.

Type `hk4g4` to get 測試 (test), type `good` to get `good` — the input method figures out which is which on its own.

## Why this works

On the standard Dayi (大千) keyboard layout, all 26 English letters map to Zhuyin symbols, so any English word is simultaneously a string of Zhuyin. At first glance the two seem indistinguishable, but if the user **types tone marks, with the first tone bound to the space bar**, two strong constraints emerge:

1. Tone keys (`3467`) and space are natural boundaries.
2. **A single unit can contain at most one Chinese syllable** — if there are two, a tone key or space must appear after the first one.

Point 2 is the key insight. It turns "this string can't form a single valid syllable" directly into evidence that it's English:

| Keystrokes | Zhuyin | Verdict |
|---|---|---|
| `cpu` | ㄏㄣㄧ | Not a valid syllable → English |
| `sdk` `api` `npm` | — | Same as above |
| `d9` | ㄎㄞ | Valid syllable → Chinese 開 (open) |
| `284` | ㄉㄚˋ | All digits, but still a valid syllable → Chinese 大 (big) |

Testing against high-frequency English words, only two remain genuinely ambiguous: `up` (ㄧㄣ, as in 因/音) and `i` (ㄛ, as in 喔).

This rule doesn't apply to users who don't type tone marks — that case needs a different, language-model-based approach.

## Features

- **Mixed Chinese/English typing**: `macbooknji3` automatically splits into `macbook` + 所, no separator needed
- **Automatic word selection**: `hk4g4` directly produces 測試 rather than 冊市
- **Character-by-character correction**: move the cursor within the composition buffer, replace a single character, or insert mid-sentence
- **Comprehensive candidates**: homophone words, homophone single characters, and the raw keystrokes (to fall back to digits or English when the guess is wrong) all appear in one list
- **Learns your usage**: manually selected words get a higher weight, so future auto-selection favors them
- **Numbers and punctuation**: `1234567890` is never read as Zhuyin; a `,` after Chinese text becomes `，` automatically, while it stays half-width after English text

## Download and install

Download **`Zhijeida-0.1.2.pkg`** from [Releases](https://github.com/xingyen0613/zhijeida/releases) — it's the only file you need, shared between Apple Silicon and Intel. Requires macOS 12 or later.

**1. Open the installer.** The first time, macOS will block it with "cannot be opened because the developer cannot be verified." This input method isn't signed with an Apple Developer certificate (code signing and notarization require a paid Apple Developer Program membership) — the file itself is fine. Go to **System Settings → Privacy & Security**, scroll down to find the blocked file, click **Open Anyway**, then open the installer again.

**2. Click "Continue" through the installer.** The input method installs into your own home directory (`~/Library/Input Methods`) — no administrator password needed, and it never touches system files.

**3. Restart your Mac.** The installer will ask you to restart at the end. macOS only scans the input method directory at login, so this step can't be skipped — Apple has confirmed there is currently no way around it (Developer Forums thread 775526, Feedback FB23026482).

**4. Add it as an input source.** After restarting, go to **System Settings → Keyboard → Input Sources → Edit**, click the **+** in the bottom left, choose **Traditional Chinese**, and add **Zhijeida** from the list.

You can then switch to it from the input method menu in the top-right menu bar, or with `Control + Space`. To remove it, delete `~/Library/Input Methods/Zhijeida.app` and restart.

### Intel Macs

The installer is a universal binary containing both `arm64` and `x86_64` architectures. The `x86_64` half has been verified to launch, load the language model, and look up entries correctly on Apple Silicon via Rosetta, but it **has not been tested on real Intel hardware**. If it installs but doesn't respond, or behaves incorrectly, on an Intel Mac, please open an [issue](https://github.com/xingyen0613/zhijeida/issues) with your macOS version.

## Building from source

**No Xcode required** — the `swiftc` that ships with Command Line Tools is enough.

```bash
./ime/fetch-data.sh    # fetch the Zhuyin word database (see "License")
./ime/build-lm.py      # build the language model
./ime/build.sh         # build the input method
cp -R ime/build/Zhijeida.app ~/Library/Input\ Methods/
```

Then restart (logging out and back in also works), and add it as an input source following step 4 above.

If you only change Swift code afterward and don't touch `Info.plist`, rebuilding and running `pkill -f Zhijeida` is enough — no restart needed.

To produce an installer for others to download:

```bash
./ime/make-installer.sh    # produces ime/build/Zhijeida-<version>.pkg
```

This script builds a dual-architecture binary via `./build.sh --universal`, bundles the word database license alongside it, then packages everything into a home-directory installer with `pkgbuild` / `productbuild`. Installers aren't checked into version control — they're uploaded to GitHub Releases when published.

## Usage

| Key | Behavior |
|---|---|
| `← →` | Move the insertion point by character |
| `Home` / `End` | Jump to the start/end of the composition buffer |
| `↓` | Bring up candidates for the character to the left of the cursor |
| `↑↓` `←→` | Navigate within the candidate list |
| `Enter` | Confirms selection if the list is open; otherwise commits the composition buffer |
| Number keys | Select the Nth candidate directly while the list is open |
| `Backspace` / `fn+Delete` | Delete one character to the left/right of the cursor |
| `Esc` | Clear the composition buffer |

Candidate list order: multi-character words → raw keystrokes → homophone single characters, each group sorted by frequency.

## Development

```bash
./ime/run-tests.sh     # 49 regression tests, no need to install the input method
```

Tests cover Chinese/English disambiguation, word segmentation, number handling, candidate ranking, composition buffer editing, and learning from user habits. `judge.py` is the original offline disambiguation prototype, kept as a reference implementation of the rules.

Debug logs are written to `~/Library/Logs/Zhijeida.log` (an IMK process's `NSLog` doesn't reliably reach the unified log, so a separate file is kept).

**By default, only startup and loading events are logged — no input content.** Enable detailed logging only when debugging a disambiguation issue:

```bash
launchctl setenv ZHIJEIDA_DEBUG 1     # once enabled, actual typed text is logged
launchctl unsetenv ZHIJEIDA_DEBUG     # disable
```

### Pitfalls encountered

IMK decides how to dispatch events based on which methods the controller implements — adding a method doesn't just add a new path, it changes the existing one. All three of the following caused keystrokes to stop reaching the disambiguation logic entirely:

- Overriding `handle(_:client:)` → IMK stops calling `inputText`
- Implementing `inputText(_:key:modifiers:client:)` → arrow keys and Enter also get routed into the text path
- Returning `false` from `inputText` or `didCommand` → the keystroke falls through to the application, and the composition buffer gets cleared

Also, `NSApp.currentEvent` is unavailable inside an IMK process (keystrokes arrive via IPC, not through the NSApplication event loop), so it can't be used to read modifier keys.

## Privacy

Word selection history is stored in the user's own directory, not inside the project:

```
~/Library/Application Support/Zhijeida/user-phrases.tsv
```

This isn't enforced via `.gitignore` — the file simply never exists inside the repo. Each user account has its own independent file; delete it to clear the history. The input method never connects to the network and never uploads anything.

The input method can see everything the user types, so:

- Logs **do not record input content by default** — it must be explicitly enabled with `ZHIJEIDA_DEBUG=1`
- Both the user word file and the log file are created with `0600` permissions, unreadable by other accounts on the same machine
- Password fields are protected by macOS Secure Input, which disables third-party input methods while active

`ime/fetch-data.sh` downloads the word database from GitHub, pinned to a specific commit (see `MCBOPOMOFO_COMMIT` in the script), so the data fetched is identical no matter when you run it, and upstream changes never affect an existing build. To update the database, change that SHA and rerun the tests.

The input method itself never connects to the network at runtime. The word database is a plain-text lookup table, and parsing it never involves code execution — so even if the data were tampered with, it could only affect word selection results, not compromise the system.

## License

This project is MIT licensed.

The Zhuyin word database is fetched by `ime/fetch-data.sh` from [McBopomofo](https://github.com/openvanilla/McBopomofo); the source files are not checked into this project:

- `BPMFBase.txt`, `phrase.occ`, `exclusion.txt` — MIT License, Copyright (c) 2011-2026 Mengjuei Hsieh et al.
- `BPMFMappings.txt` — derived from libtabe's `tsi.src`, **BSD License**

The installers provided in Releases include `lm.tsv` and `bpmf.tsv` compiled from this data, which are derivative works. Both MIT and BSD permit redistribution provided the full license text is included, so `LICENSE-McBopomofo.txt` is bundled into the app bundle's `Contents/Resources/`.

Automatic word selection follows McBopomofo's Gramambular approach: unigram scores combined with a DAG shortest-path search. It doesn't consider context — 測試 (test) beats 冊 + 市 simply because the probability of a common word is higher than that of two single characters happening to appear next to each other.
