# Contributing

Thank you for helping Handy Palette stay small, private, and dependable.

## Before opening a pull request

Run the local verification loop:

```sh
swift build
swift run HandyChecks
npm ci
npm run test:web
```

Keep the core library portable, offline, and free of tracking. Clipboard changes must preserve explicit consent, the 50-entry limit, sensitive pasteboard filtering, and separate storage from the main library.

Catalog changes belong in `Scripts/update_catalog.py` or its pinned upstream inputs. Do not hardcode new content categories or varieties into the SwiftUI palette or website. Declare category behavior in the library data and add a verification check for it.

## Pull requests

- Keep one concern per pull request.
- Add or extend a verification check for data-model behavior.
- Describe manual macOS checks for interaction changes.
- Do not add a dependency without explaining its privacy and maintenance cost.
- Update `THIRD_PARTY_NOTICES.md` when adding or changing an upstream content source.
- Keep website interactions usable with Tab, arrow keys, Return, and Escape.
