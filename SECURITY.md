# Security policy

Please do not report security or privacy vulnerabilities in a public issue. Use GitHub's private vulnerability reporting feature for this repository, or contact the maintainer through the email address on their GitHub profile.

Kana stores its library and optional clipboard history in the user's Application Support directory. Clipboard monitoring is off until the user enables it, entries marked concealed or transient are ignored, and source application identities are not saved. Apps do not always label sensitive clipboard content correctly.

Reports involving unexpected clipboard capture, consent bypasses, unsafe file permissions, global shortcut interception, or library-file exposure are especially welcome. Please include the macOS version, Kana version, and the smallest reliable reproduction you have.
