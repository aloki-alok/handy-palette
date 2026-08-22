# Contributing

Thank you for helping Handy stay small, private, and dependable.

## Before opening a pull request

Run the local verification loop:

```sh
swift build
swift run HandyChecks
```

Keep the core library portable, offline, and free of tracking. New features must not read clipboard history, send input data off-device, or weaken the copy-first contract without a documented architecture decision.

## Pull requests

- Keep one concern per pull request.
- Add or extend a verification check for data-model behavior.
- Describe manual macOS checks for interaction changes.
- Do not add a dependency without explaining its privacy and maintenance cost.
