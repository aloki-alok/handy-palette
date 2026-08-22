import AppKit

enum HandyMenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSGraphicsContext.current?.imageInterpolation = .none
            NSColor.black.setFill()

            // Pixel monitor frame, derived from Handy Palette's canonical Mac mark.
            NSRect(x: 4, y: 15, width: 10, height: 2).fill()
            NSRect(x: 3, y: 8, width: 2, height: 8).fill()
            NSRect(x: 13, y: 8, width: 2, height: 8).fill()
            NSRect(x: 4, y: 7, width: 10, height: 2).fill()

            // The same friendly face used on the full-color screen.
            NSRect(x: 6, y: 12, width: 2, height: 1).fill()
            NSRect(x: 10, y: 12, width: 2, height: 1).fill()
            NSRect(x: 7, y: 10, width: 1, height: 1).fill()
            NSRect(x: 8, y: 9, width: 2, height: 1).fill()
            NSRect(x: 10, y: 10, width: 1, height: 1).fill()

            // Keyboard base and a few deliberate pixel gaps.
            NSRect(x: 3, y: 5, width: 12, height: 2).fill()
            NSRect(x: 2, y: 3, width: 14, height: 2).fill()
            NSColor.clear.setFill()
            NSRect(x: 5, y: 4, width: 2, height: 1).fill(using: .copy)
            NSRect(x: 8, y: 4, width: 2, height: 1).fill(using: .copy)
            NSRect(x: 11, y: 4, width: 2, height: 1).fill(using: .copy)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Handy Palette"
        return image
    }()
}
