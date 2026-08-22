# Agent instructions

Read [REVIEWING.md](REVIEWING.md) before changing native interaction, Swift architecture, clipboard behavior, catalog data, the website, packaging, CI, or release automation. Treat its release checks as required gates.

Keep product content and category behavior data-driven through the versioned library. Keep the macOS app offline, private by default, and native to AppKit and SwiftUI conventions.

Run the smallest relevant checks while working, then run every command in the release gate before proposing a tag or publishing from `main`.
