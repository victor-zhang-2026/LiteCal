import Foundation
import CoreGraphics

enum Placement {
    static func screenIndex(window: CGRect, screens: [CGRect], pointer: CGPoint? = nil) -> Int? {
        if let pointer, let i = screens.firstIndex(where: { $0.contains(pointer) }) { return i }
        let areas = screens.map { r -> CGFloat in let a = r.intersection(window); return a.isNull ? 0 : a.width * a.height }
        if let i = areas.indices.max(by: { areas[$0] < areas[$1] }), areas[i] > 0 { return i }
        let p = CGPoint(x: window.midX, y: window.midY)
        return screens.indices.min { a, b in
            func distance(_ r: CGRect) -> CGFloat { hypot(p.x - min(max(p.x, r.minX), r.maxX), p.y - min(max(p.y, r.minY), r.maxY)) }
            return distance(screens[a]) < distance(screens[b])
        }
    }
    static func clamp(_ rect: CGRect, to visible: CGRect, margin: CGFloat = 8) -> CGRect {
        let width = min(rect.width, max(1, visible.width - margin * 2))
        let height = min(rect.height, max(1, visible.height - margin * 2))
        return CGRect(x: min(max(rect.minX, visible.minX + margin), visible.maxX - width - margin), y: min(max(rect.minY, visible.minY + margin), visible.maxY - height - margin), width: width, height: height)
    }
    /// Edge names refer to the editor's flipped content view (maxY is below).
    static func datePickerEdge(editor: CGRect, content: CGSize, visible: CGRect) -> CGRectEdge {
        let needed = content.height + 20
        if editor.minY - visible.minY >= needed { return .maxYEdge }
        if visible.maxY - editor.maxY >= needed { return .minYEdge }
        if visible.maxX - editor.maxX >= content.width + 20 { return .maxXEdge }
        if editor.minX - visible.minX >= content.width + 20 { return .minXEdge }
        return editor.minY - visible.minY >= visible.maxY - editor.maxY ? .maxYEdge : .minYEdge
    }
    static func overlay(anchor: CGRect, size: CGSize, visible: CGRect) -> CGRect {
        let below = anchor.minY - size.height - 8
        let above = anchor.maxY + 8
        let y = below >= visible.minY + 8 ? below : (above + size.height <= visible.maxY - 8 ? above : anchor.midY - size.height / 2)
        return clamp(CGRect(x: anchor.midX - size.width / 2, y: y, width: size.width, height: size.height), to: visible)
    }
    static func panel(trigger: CGRect, visible: CGRect) -> CGRect {
        // Preserve a separate trigger even on compact displays.
        let width = min(980, max(1, visible.width - trigger.width - 28))
        let height = min(760, max(1, visible.height - 24))
        let left = trigger.minX - visible.minX - 12
        let right = visible.maxX - trigger.maxX - 12
        let x = left >= width || left >= right ? trigger.minX - width - 4 : trigger.maxX + 4
        return clamp(CGRect(x: x, y: trigger.midY - height / 2, width: width, height: height), to: visible, margin: 12)
    }
}
