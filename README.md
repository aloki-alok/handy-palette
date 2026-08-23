<p align="center">
  <img src="docs/handy-icon.png" width="128" height="128" alt="Handy Palette pixel Mac logo">
</p>

<h1 align="center">Handy Palette</h1>

<p align="center">
  Kaomoji, emoji, and clipboard history, one shortcut away.
</p>

<p align="center">
  <a href="https://github.com/aloki-alok/handy-palette/actions/workflows/verify.yml"><img src="https://github.com/aloki-alok/handy-palette/actions/workflows/verify.yml/badge.svg" alt="Verify workflow status"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-08705a.svg" alt="MIT license"></a>
  <a href="https://github.com/aloki-alok/handy-palette"><img src="https://img.shields.io/badge/macOS-14%2B-151815.svg" alt="macOS 14 or later"></a>
</p>

Handy Palette lives in the macOS menu bar and stays out of the way until you press `Option-Command-K`. Search the whole shelf, choose a result, and press Return to copy it. No account, analytics, or network connection is required.

The bundled library contains more than 2,300 kaomoji and emoji. Recents bring back things you actually use, Favorites keep the best ones close, and optional clipboard history restores text you copied elsewhere.

[Try the interactive preview](https://aloki-alok.github.io/handy-palette/) or read on to run the native Mac app.

## Install

Install from the public Homebrew tap:

```sh
brew install aloki-alok/tap/handy-palette
```

Start it now and at login:

```sh
brew services start aloki-alok/tap/handy-palette
```

Press `Option-Command-K` from any app. For a one-time foreground run instead:

```sh
handy-palette open
```

Or run it from source with macOS 14 or later and Swift 6:

```sh
swift run Handy
```

To remove it cleanly:

```sh
brew services stop handy-palette
brew uninstall handy-palette
```

## One shelf, five useful views

| View | What it is for |
| --- | --- |
| Kaomoji | Find expressions such as `¯\_(ツ)_/¯` by name, mood, tag, or characters. |
| Emoji | Search the bundled emoji catalog without opening a separate character viewer. |
| Clipboard | Restore up to 50 text copies after explicitly enabling history. |
| Recents | Reuse kaomoji and emoji previously copied through Handy Palette. |
| Favorites | Pin the items you want available immediately. |

Search crosses every view and groups matching results by their source. The palette opens without a preselected row, so pressing Return cannot copy something accidentally.

## What it does

- Searches kaomoji and emoji by title, tag, category, or the characters themselves.
- Keeps the last 50 text copies when clipboard history is explicitly enabled.
- Ignores pasteboard entries marked concealed or transient by password managers and other apps.
- Learns Recents when an item is copied through Handy Palette.
- Lets any library item be added to Favorites with its star, the context menu, or `Command-D`.
- Loads sections, icons, writable capabilities, and content from the versioned library data.
- Works without an account, analytics, or a network connection.

Clipboard history starts off. Enable it from the Clipboard shelf or menu-bar menu. Handy stores only text, does not save source application identities, and ignores entries marked concealed or transient. Apps do not always mark sensitive clipboard content correctly, so treat any clipboard manager as sensitive software.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| `Option-Command-K` | Open or close Handy Palette |
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
handy-palette search <query>
handy-palette favorites list
handy-palette favorite add <item-id>
handy-palette snippets
handy-palette add --title <title> --text <text> --tags tag-one,tag-two
handy-palette copy <query>
handy-palette clipboard status
handy-palette clipboard enable
handy-palette clipboard disable
handy-palette clipboard list
handy-palette clipboard clear
```

Run `handy-palette help` for the complete command reference.

## Library data

The portable library lives at:

```text
~/Library/Application Support/Handy/library.json
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
swift run HandyChecks
swift run -c release Handy --check-search-performance
swift run -c release Handy --check-focus
swift run -c release Handy --check-snippet-focus
swift run -c release Handy --check-keyboard
npm ci
npm run test:web
```

The native diagnostics verify real macOS window focus, responder-chain text insertion, sheet focus, Return, Escape, and broad-query responsiveness. The browser tests cover the full catalog, search, shortcuts, Favorites, clipboard denial, catalog failure, accessibility, light and dark appearance, and mobile overflow.

## Project layout

```text
Sources/HandyCore/   portable library, search, clipboard history, keyboard routing
Sources/Handy/       macOS menu-bar app, palette, storage, and CLI
Sources/HandyChecks/ deterministic native verification
Scripts/             catalog and Pages build tools
docs/                GitHub Pages source
Tests/web/           browser interaction tests
```

## Inspiration

Handy Palette builds on ideas from [kaomoji-palette](https://github.com/freysie/kaomoji-palette) and [kaomoji-picker](https://github.com/rory660/kaomoji-picker), then combines them with Favorites, Recents, global search, and optional clipboard history.

## Contributing and security

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Report security or privacy issues through the process in [SECURITY.md](SECURITY.md).

## License

MIT. Copyright 2026 Alok Ranjan. See [LICENSE](LICENSE).
