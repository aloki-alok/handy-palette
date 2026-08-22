# Handy

Handy is a private, open-source input shelf for your own text: kaomojis, emoji, snippets, and symbols.

On macOS, press `Option-Command-Space`, search, and copy the item you want. Your library is a portable JSON file you own.

## Status

Handy is an early Mac-first prototype. Copy is the reliable core action. Paste is deliberately not part of the initial contract because global insertion is application and accessibility-permission dependent.

## Run it

Requires macOS 14 or later and Swift 6:

```sh
swift run Handy
```

Run local verification:

```sh
swift run HandyChecks
```

## Shortcuts

| Shortcut | Action |
| --- | --- |
| `Option-Command-Space` | Open or close Handy |
| `Return` | Copy selected item |
| `Escape` | Close the shelf |
| `Up` / `Down` | Move through results |

## Privacy

- No account, tracking, analytics, network requests, or server.
- Handy does not read or store clipboard history.
- Your library is stored locally at `~/Library/Application Support/Handy/library.json`.
- The file is ordinary JSON and can be backed up, versioned, or shared by you.

## Library format

```json
{
  "version": 1,
  "items": [
    {
      "id": "shrug",
      "text": "¯\\_(ツ)_/¯",
      "title": "Shrug",
      "tags": ["kaomoji", "confused"],
      "isPinned": true,
      "useCount": 0
    }
  ]
}
```

## Roadmap

1. Mac menu-bar palette and JSON library.
2. Editor, import/export, and configurable shortcut.
3. iPhone editor and offline keyboard that reads the same library through iCloud.
4. Small adapters for terminal, Raycast, and other platforms.

## Inspiration

Handy takes inspiration from [kaomoji-palette](https://github.com/freysie/kaomoji-palette) and [kaomoji-picker](https://github.com/rory660/kaomoji-picker), while deliberately expanding their focused kaomoji workflows into a private, portable personal library.

## License

MIT. See [LICENSE](LICENSE).
