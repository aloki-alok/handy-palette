# Contributing

Thank you for helping Kana stay small, private, and dependable.

Use [REVIEWING.md](REVIEWING.md) as the standing review standard for native interaction, Swift architecture, clipboard privacy, the website, catalog changes, iPhone work, and releases.

## Before opening a pull request

Run the local verification loop:

```sh
swift build
swift run KanaChecks
swift run -c release Kana --check-search-performance
./Scripts/package_macos_app.sh 0.3.0 .build/package-check
ditto -x -k .build/package-check/Kana-0.3.0-arm64.zip .build/package-check/app
.build/package-check/app/Kana.app/Contents/MacOS/Kana --check-window
.build/package-check/app/Kana.app/Contents/MacOS/Kana --check-focus
.build/package-check/app/Kana.app/Contents/MacOS/Kana --check-background-focus
.build/package-check/app/Kana.app/Contents/MacOS/Kana --check-snippet-focus
.build/package-check/app/Kana.app/Contents/MacOS/Kana --check-keyboard
npm ci
npm run test:web
```

The focus and keyboard checks run against the packaged app on purpose. A `swift run` binary is not a bundle, cannot reliably take key focus, and reports failure for reasons that have nothing to do with the code.

Keep the core library portable, offline, and free of tracking. Clipboard changes must preserve explicit consent, the 50-entry limit, sensitive pasteboard filtering, and separate storage from the main library.

Catalog changes belong in `Scripts/update_catalog.py` or its pinned upstream inputs. Do not hardcode new content categories or varieties into the SwiftUI palette or website. Declare category behavior in the library data and add a verification check for it.

## Pull requests

- Keep one concern per pull request.
- Add or extend a verification check for data-model behavior.
- Describe manual macOS checks for interaction changes.
- Do not add a dependency without explaining its privacy and maintenance cost.
- Update `THIRD_PARTY_NOTICES.md` when adding or changing an upstream content source.
- Keep website interactions usable with Tab, arrow keys, Return, and Escape.
