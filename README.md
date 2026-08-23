<p align="center">
  <img src="docs/kana-icon.png" width="128" height="128" alt="Kana pixel Mac logo">
</p>

<h1 align="center">Kana</h1>

<p align="center">
  Kaomoji, emoji, and clipboard history, one shortcut away.
</p>

<p align="center">
  <a href="https://github.com/aloki-alok/kana/actions/workflows/verify.yml"><img src="https://github.com/aloki-alok/kana/actions/workflows/verify.yml/badge.svg" alt="Verify workflow status"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-08705a.svg" alt="MIT license"></a>
  <a href="https://github.com/aloki-alok/kana"><img src="https://img.shields.io/badge/macOS-14%2B-151815.svg" alt="macOS 14 or later"></a>
</p>

Press `Option-Command-K` in any app, search 2,300+ kaomoji and emoji, press Return to copy. Works offline, no account.

[Try the interactive preview](https://aloki-alok.github.io/kana/) or read on to run the native Mac app.

## Install

Install from the public Homebrew tap:

```sh
brew install --cask aloki-alok/tap/kana
```

Open Kana from Applications or Spotlight, then press `Option-Command-K` from any app. You can enable Open at login from its menu-bar menu.

The current community build is unsigned and not notarized. On first launch, try opening Kana once, then choose Open Anyway in System Settings > Privacy & Security and confirm.

You can also open the palette from the command line:

```sh
kana open
```

Or run it from source with macOS 14 or later and Swift 6:

```sh
swift run Kana
```

To remove it cleanly:

```sh
brew uninstall --cask kana
```

## One shelf, five useful views

| View | What it is for |
| --- | --- |
| Kaomoji | Find expressions such as `¯\_(ツ)_/¯` by name, mood, tag, or characters. |
| Emoji | Search the bundled emoji catalog without opening a separate character viewer. |
| Clipboard | Restore up to 50 text copies after explicitly enabling history. |
| Recents | Reuse kaomoji and emoji previously copied through Kana. |
| Favorites | Pin the items you want available immediately. |

Search crosses every view and groups matching results by their source. The palette opens without a preselected row, so pressing Return cannot copy something accidentally.

## What it does

- Searches kaomoji and emoji by title, tag, category, or the characters themselves.
- Keeps the last 50 text copies when clipboard history is explicitly enabled.
- Ignores pasteboard entries marked concealed or transient by password managers and other apps.
- Learns Recents when an item is copied through Kana.
- Lets any library item be added to Favorites with its star, the context menu, or `Command-D`.
- Loads sections, icons, writable capabilities, and content from the versioned library data.
- Works without an account, analytics, or a network connection.

Clipboard history starts off. Enable it from the Clipboard shelf or menu-bar menu. Kana stores only text, does not save source application identities, and ignores entries marked concealed or transient. Apps do not always mark sensitive clipboard content correctly, so treat any clipboard manager as sensitive software.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| `Option-Command-K` | Open or close Kana |
| `Up` / `Down` | Select a result |
| `Return` | Copy the selected result |
| `Escape` | Close the palette |
| `Control-Tab` | Move to the next shelf |
| `Control-Shift-Tab` | Move to the previous shelf |
| `Command-1` through `Command-9` | Open a shelf directly |
| `Command-D` | Add or remove the selected item from Favorites |
| `Command-N` | Add an item to the writable shelf |

No result is selected when the palette opens. Return only copies after you choose a row.

## Command line

The Homebrew command and the Mac interface use the same library:

```text
kana search <query>
kana favorites list
kana favorite add <item-id>
kana snippets
kana add --title <title> --text <text> --tags tag-one,tag-two
kana copy <query>
kana clipboard status
kana clipboard enable
kana clipboard disable
kana clipboard list
kana clipboard clear
```

Run `kana help` for the complete command reference.

## Library data

The portable library lives at:

```text
~/Library/Application Support/Kana/library.json
```

Clipboard history is stored separately in the same directory. Both files are private user data and should not be committed to this repository.

Categories are data, not UI branches. A category declares its title, native symbol, optional display glyph, order, and capabilities. Items refer to a category by ID:

```json
{
  "version": 2,
  "catalogRevision": 3,
  "categories": [
    {
      "id": "kaomoji",
      "title": "Kaomoji",
      "symbol": "textformat.characters",
      "displayGlyph": ";)",
      "order": 10
    }
  ],
  "items": [
    {
      "id": "shrug",
      "text": "¯\\_(ツ)_/¯",
      "title": "Shrug",
      "tags": ["confused"],
      "categoryID": "kaomoji",
      "isPinned": true,
      "useCount": 0
    }
  ]
}
```

Maintainers update the bundled catalog through [Scripts/update_catalog.py](Scripts/update_catalog.py). The generator uses pinned upstream revisions, removes duplicate text, and writes the same JSON consumed by the Mac app and website. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for source licenses.

## Verification

```sh
swift build
swift run KanaChecks
swift run -c release Kana --check-search-performance
swift run -c release Kana --check-focus
swift run -c release Kana --check-snippet-focus
swift run -c release Kana --check-keyboard
npm ci
npm run test:web
```

The native diagnostics verify real macOS window focus, responder-chain text insertion, sheet focus, Return, Escape, and broad-query responsiveness. The browser tests cover the full catalog, search, shortcuts, Favorites, clipboard denial, catalog failure, accessibility, light and dark appearance, and mobile overflow.

## Project layout

```text
Sources/KanaCore/   portable library, search, clipboard history, keyboard routing
Sources/KanaShared/ shared clipboard and preference bridges
Sources/Kana/       macOS menu-bar app and palette
Sources/KanaCLI/    command-line interface
Sources/KanaChecks/ deterministic native verification
Distribution/        macOS app bundle metadata
Scripts/             catalog, packaging, and Pages build tools
docs/                GitHub Pages source
Tests/web/           browser interaction tests
```

## Inspiration

Kana builds on ideas from [kaomoji-palette](https://github.com/freysie/kaomoji-palette) and [kaomoji-picker](https://github.com/rory660/kaomoji-picker), then combines them with Favorites, Recents, global search, and optional clipboard history.

## Contributing and security

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Report security or privacy issues through the process in [SECURITY.md](SECURITY.md).

## License

MIT. Copyright 2026 Alok Ranjan. See [LICENSE](LICENSE).
