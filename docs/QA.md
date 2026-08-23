# Mac QA matrix

Run this matrix before a tagged release. Kana finds and copies kaomoji, emoji, clipboard history, Favorites, Recents, and optional snippets. It does not promise automatic paste into other applications.

## Automated gate

```sh
swift build
swift run KanaChecks
swift run -c release Kana --check-search-performance
swift run -c release Kana --check-focus
swift run -c release Kana --check-background-focus
swift run -c release Kana --check-snippet-focus
swift run -c release Kana --check-keyboard
./Scripts/package_macos_app.sh 0.3.0 .build/package-check
npm ci
npm run test:web
```

The checks cover search ranking and limits, Unicode JSON round trips, coordinated library updates, Favorites, custom items, clipboard validation, keyboard routing, real window focus, actual text insertion, broad-query latency, website interaction, and mobile layout.

## Manual gate

| Scenario | Expected result |
| --- | --- |
| First launch | A starter `library.json` is created locally and the menu-bar item appears. |
| Homebrew cask | The cask installs `Kana.app` in Applications and exposes the `kana` command. |
| Command-line open | `kana open` shows the palette on cold start and reuses the same process when already running. |
| Open at login | The menu toggle registers and unregisters the app through the system Login Items service. |
| Shortcut is available | `Option-Command-K` opens the shelf, search receives focus, and Escape closes it. |
| Shortcut collision | The app shows an honest warning and remains reachable from the menu bar. |
| Keyboard-only selection | Type a title or tag, use Up and Down, then Return. The exact selected item is copied. |
| No implicit selection | Open the palette or change shelves. No row is selected until Up or Down is pressed. |
| Shelf navigation | `Control-Tab`, `Control-Shift-Tab`, and `Command-1` through `Command-9` move to the expected shelf and keep search focused. |
| Favorites | Click a row's star or select it and press `Command-D`. The item appears in Favorites and survives relaunch. |
| Clipboard consent | Clipboard stays empty before opt-in. Enabling history captures later text copies only. Disabling stops capture. |
| Sensitive clipboard | Pasteboard entries marked concealed or transient are not stored. |
| Clipboard limits | History keeps at most 50 valid text entries and Clear removes them after confirmation. |
| Snippet editor | `Command-N` opens the writable shelf editor. Title receives focus, Escape cancels, and a failed save preserves entered text. |
| Mouse selection | Clicking an item copies that item and closes the shelf. |
| Unicode | Copy `¯\_(ツ)_/¯`, `(╯°□°）╯︵ ┻━┻`, and a multiline snippet into TextEdit. Bytes and line breaks match the library. |
| Search | Exact title ranks first. Tags find their matching entry. Empty search shows the curated shelf. |
| Maccy coexistence | Copy an item, then retrieve it with Maccy. When Kana clipboard history is disabled it does not keep the copy. When enabled it keeps the copy independently. |
| Offline | Disconnect networking, relaunch, search, and copy. All behavior remains available. |
| Invalid library | Replace a copy of the library with malformed JSON or duplicate IDs, then relaunch. The valid in-memory starter data remains usable and the app shows the error rather than overwriting a file. |
| Library path | Menu bar `Reveal library.json` opens the file location, and the file remains human-readable JSON. |
| Accessibility denied | The complete copy flow works without granting Accessibility or Input Monitoring permissions. |

## Deliberate exclusions

Password fields, secure-input applications, remote desktop sessions, and apps that block automation are outside automatic paste because Kana does not inject keystrokes. Clipboard managers cannot guarantee that every source app labels sensitive content correctly.

## GitHub Pages gate

The Pages workflow builds its artifact from `docs/index.html`, the canonical icon, and the same generated catalog used by the app. Verify the HTTPS URL in light mode, dark mode, reduced-motion mode, and at 390 px width. The Playwright suite must pass search, section shortcuts, copy, Favorites, result limits, and mobile overflow. Do not describe a build as signed or notarized unless the published artifact passes those checks.
