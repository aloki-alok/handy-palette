# Mac QA matrix

Run this matrix before a tagged release. Handy's v1 claim is limited to opening, finding, and copying curated local text. Do not extend this checklist into a claim that Handy can paste everywhere.

## Automated gate

```sh
swift build
swift run HandyChecks
```

The checks cover search ranking, Unicode JSON round trips, invalid duplicate-ID rejection, and atomic preservation of the valid library when an invalid save is attempted.

## Manual gate

| Scenario | Expected result |
| --- | --- |
| First launch | A starter `library.json` is created locally and the menu-bar item appears. |
| Shortcut is available | `Option-Command-K` opens the shelf, search receives focus, and Escape closes it. |
| Shortcut collision | The app shows an honest warning and remains reachable from the menu bar. |
| Keyboard-only selection | Type a title or tag, use Up and Down, then Return. The exact selected item is copied. |
| Mouse selection | Clicking an item copies that item and closes the shelf. |
| Unicode | Copy `¯\_(ツ)_/¯`, `(╯°□°）╯︵ ┻━┻`, and a multiline snippet into TextEdit. Bytes and line breaks match the library. |
| Search | Exact title ranks first. Tags find their matching entry. Empty search shows the curated shelf. |
| Maccy coexistence | Copy an item, then retrieve it with Maccy. Handy never reads or persists other Maccy entries. |
| Offline | Disconnect networking, relaunch, search, and copy. All behavior remains available. |
| Invalid library | Replace a copy of the library with malformed JSON or duplicate IDs, then relaunch. The valid in-memory starter data remains usable and the app shows the error rather than overwriting a file. |
| Library path | Menu bar `Reveal library.json` opens the file location, and the file remains human-readable JSON. |
| Accessibility denied | The complete copy flow works without granting Accessibility or Input Monitoring permissions. |

## Deliberate exclusions

Password fields, secure-input applications, remote desktop sessions, non-US keyboard layouts, and apps that block automation are not copy-flow risks because Handy does not inject keystrokes or promise automatic paste in v1.

## GitHub Pages gate

Before manually running the Pages deployment workflow, test `docs/index.html` at the GitHub Pages HTTPS URL in light mode, dark mode, reduced-motion mode, and at 320 px width. Keyboard test the live demo with Tab, text input, Up, Down, Return, Escape, and Tab out. Confirm copy success and the browser-permission failure message. No signed app download link may appear until a signed, notarized `.app` release exists.
