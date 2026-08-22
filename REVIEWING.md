# Reviewing Handy Palette

This is the standing review guide for maintainers and coding agents. A release is ready only when every applicable item has evidence from a command or a documented manual check.

## Product boundary

Handy Palette is a macOS kaomoji and emoji picker with optional clipboard history. Favorites and Recents support that core. Snippets are a secondary, data-driven capability.

- Keep the app useful without an account, analytics, or network access.
- Keep clipboard monitoring off until the user explicitly enables it.
- Keep category names, ordering, icons, capabilities, and items in the versioned catalog rather than UI branches.
- Keep macOS and web preview behavior aligned where the platforms allow it.

## Apple platform review

Use current official Apple documentation for API and platform claims. Start with:

- [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/)
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility/)
- [Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards)
- [NSEvent local monitors](https://developer.apple.com/documentation/appkit/nsevent/addlocalmonitorforevents%28matching%3Ahandler%3A%29)
- [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard)

Check the native app for:

- A key-capable palette, immediate search focus, Escape dismissal, and Return activation only after a result is selected.
- Full keyboard reachability for shelves, results, Favorites, Clipboard controls, and snippet editing.
- Search focus restoration after shelf shortcuts.
- VoiceOver labels for icon-only controls and announcements for dynamic selection or copy outcomes.
- Native light and dark appearance through semantic system colors.
- Reduced-motion support for nonessential animation.
- A menu-bar icon and menu behavior that match the canonical product identity.
- No global event interception beyond the registered open shortcut. Local event handling stays scoped to the key palette window.

## Swift and architecture review

- Keep `HandyCore` independent of AppKit and SwiftUI.
- Keep file formats versioned, bounded, validated, and backward compatible.
- Coordinate read-modify-write persistence with file locks and atomic replacement.
- Keep UI state on the main actor and keep expensive search work bounded and cached.
- Preserve user input when an operation fails and surface a useful error.
- Prefer native APIs and semantic SwiftUI behavior over custom event machinery.
- Add a deterministic regression check for every fixed behavior or explain why the available seam cannot test it honestly.

## Clipboard privacy review

- Capture plain text only after opt-in.
- Ignore pasteboard values marked concealed or transient.
- Store at most 50 entries and enforce the text-size limit.
- Persist no source application identity or unrelated pasteboard metadata.
- Keep clipboard history in a separate private file.
- Make disable and clear actions understandable and reversible where possible.
- Treat clipboard changes as security-sensitive and review migration behavior for existing files.

## Web review

- Preserve visible focus, logical Tab order, arrow navigation, Return, Escape, shelf shortcuts, and reduced motion.
- Use valid native HTML and ARIA without nested interactive controls.
- Pass automated accessibility checks in light and dark appearance.
- Keep the Content Security Policy free of `unsafe-inline` and `unsafe-eval`.
- Provide usable states for catalog failure and clipboard denial.
- Disclose browser-local demo persistence.
- Run browser verification inside the Pages deployment job before publishing its artifact.

## Catalog review

- Update generated content through `Scripts/update_catalog.py` and pinned upstream revisions.
- Preserve stable item and category IDs.
- Deduplicate by the inserted text value.
- Update `THIRD_PARTY_NOTICES.md` when a source or revision changes.
- Verify the Mac app and Pages preview consume the same generated catalog.

## iPhone boundary

An iPhone companion should be an offline custom keyboard plus a containing app. The keyboard inserts catalog text through `textDocumentProxy` and reads a compact snapshot from an App Group.

- Keep `RequestsOpenAccess` off for the initial keyboard.
- Do not promise iOS clipboard history or background clipboard monitoring.
- Do not sync clipboard history.
- Keep a next-keyboard control and respect secure-field and host-app restrictions.
- Use the containing app for library management, setup, privacy controls, and any later CloudKit sync.

Review current Apple guidance before implementation:

- [Custom keyboard text interactions](https://developer.apple.com/documentation/uikit/handling-text-interactions-in-custom-keyboards)
- [Configuring open access](https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard)
- [Configuring App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## Release gate

Run from a clean checkout of the intended release commit:

```sh
swift build
swift run HandyChecks
swift run -c release Handy --check-search-performance
swift run -c release Handy --check-focus
swift run -c release Handy --check-snippet-focus
swift run -c release Handy --check-keyboard
npm ci
npm run test:web
git diff --check
```

For Homebrew, create the upstream tag first. Then run formula style, audit, source install, packaged checks, and service lifecycle verification against that exact tag. Remove test taps and local test packages after verification.

For GitHub Pages, require a successful Pages workflow and then verify the live URL for HTTP status, static assets, console errors, content, interaction, accessibility, light and dark appearance, and mobile overflow.
