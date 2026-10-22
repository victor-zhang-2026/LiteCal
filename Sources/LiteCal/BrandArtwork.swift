import AppKit

/// One compact calendar mark shared by the app icon, header and floating trigger.
/// Six generous date apertures remain legible at 21 pt; no raster dependencies.
enum BrandArtwork {
    static let purple = NSColor(srgbRed: 113/255, green: 75/255, blue: 103/255, alpha: 1)
    static func glyph(size: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            NSGraphicsContext.saveGraphicsState()
            let transform = AffineTransform(scale: size / 100)
            (transform as NSAffineTransform).concat()
            NSColor.white.setFill()
            NSBezierPath(roundedRect: NSRect(x: 15, y: 10, width: 70, height: 72), xRadius: 10, yRadius: 10).fill()
            for x: CGFloat in [30, 62] {
                NSBezierPath(roundedRect: NSRect(x: x, y: 74, width: 8, height: 18), xRadius: 4, yRadius: 4).fill()
            }
            // Punch out a separator and six days so the background tint shows through.
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            NSColor.white.setFill()
            NSRect(x: 22, y: 60, width: 56, height: 4).fill(using: .destinationOut)
            for y: CGFloat in [25, 42] { for x: CGFloat in [29, 46, 63] {
                NSBezierPath(roundedRect: NSRect(x: x, y: y, width: 8, height: 8), xRadius: 1.8, yRadius: 1.8).fill()
            }}
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
    }
    /// Optical proportions tuned for the 26 pt floating mark, drawn as vectors at any scale.
    static func floatingGlyph(size: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            NSGraphicsContext.saveGraphicsState()
            (AffineTransform(scale: size / 100) as NSAffineTransform).concat()
            NSColor.white.setStroke(); NSColor.white.setFill()
            let body = NSBezierPath(roundedRect: NSRect(x: 16, y: 12, width: 68, height: 70), xRadius: 11, yRadius: 11)
            body.lineWidth = 6.5; body.stroke()
            let binding = NSBezierPath(); binding.lineWidth = 7; binding.lineCapStyle = .round
            for x: CGFloat in [33, 67] { binding.move(to: NSPoint(x: x, y: 76)); binding.line(to: NSPoint(x: x, y: 90)) }; binding.stroke()
            let divider = NSBezierPath(); divider.lineWidth = 5
            divider.move(to: NSPoint(x: 18, y: 62)); divider.line(to: NSPoint(x: 82, y: 62)); divider.stroke()
            for y: CGFloat in [27, 44] { for x: CGFloat in [33, 57] {
                NSBezierPath(roundedRect: NSRect(x: x, y: y, width: 10, height: 9), xRadius: 2.5, yRadius: 2.5).fill()
            } }
            NSGraphicsContext.restoreGraphicsState(); return true
        }
    }
    static func icon(size: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { bounds in
            purple.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: size * 0.06, dy: size * 0.06), xRadius: size * 0.20, yRadius: size * 0.20).fill()
            let mark = glyph(size: size * 0.64)
            mark.draw(in: NSRect(x: size * 0.18, y: size * 0.18, width: size * 0.64, height: size * 0.64))
            return true
        }
    }
}
