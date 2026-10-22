import AppKit
@main struct IconGenerator {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for size in [16, 32, 128, 256, 512] { for scale in [1, 2] {
            let px = size * scale
            let image = BrandArtwork.icon(size: CGFloat(px))
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            image.draw(in: NSRect(x: 0, y: 0, width: px, height: px)); NSGraphicsContext.restoreGraphicsState()
            let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
            try bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent(name))
        }}
    }
}
