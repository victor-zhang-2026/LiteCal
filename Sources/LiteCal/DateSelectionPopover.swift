import AppKit

/// Shared, content-sized civil-date selector. Navigation never mutates the editor.
final class DateSelectionPopover: NSObject, NSPopoverDelegate {
    let popover = NSPopover()
    let grid: DateSelectionGrid
    let choosingStart: Bool
    var onSelect: ((CivilDate) -> Void)?
    var onSelectRange: ((CivilDate, CivilDate) -> Void)?
    var onClose: (() -> Void)?
    init(selected: CivilDate, minimum: CivilDate?, choosingStart: Bool) {
        self.choosingStart = choosingStart
        grid = DateSelectionGrid(selected: selected, minimum: minimum)
        super.init()
        let content = NSViewController(); content.view = grid
        popover.contentViewController = content; popover.contentSize = grid.frame.size
        popover.behavior = .transient; popover.animates = false; popover.delegate = self
        popover.appearance = NSAppearance(named: .aqua)
        grid.onResize = { [weak self] size in self?.popover.contentSize = size }
        grid.onSelect = { [weak self] day in
            guard let self else { return }
            let callback = self.onSelect
            self.popover.performClose(nil)
            callback?(day)
        }
        grid.onSelectRange = { [weak self] first, last in
            guard let self else { return }
            let callback = self.onSelectRange; self.popover.performClose(nil); callback?(first, last)
        }
        grid.onCancel = { [weak self] in self?.popover.performClose(nil) }
    }
    func show(relativeTo field: NSView) {
        guard let window = field.window, let content = window.contentView else { return }
        let fieldRect = content.convert(field.bounds, from: field)
        let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? window.frame
        let placement = Placement.datePickerEdge(editor: window.frame, content: grid.frame.size, visible: visible)
        let edge: NSRectEdge
        switch placement { case .maxYEdge: edge = .maxY; case .minYEdge: edge = .minY; case .maxXEdge: edge = .maxX; case .minXEdge: edge = .minX; @unknown default: edge = .maxY }
        // Anchor outside the editor's full vertical extent: neither the active field
        // nor its Save/Delete buttons can be covered by a downward/upward popover.
        let vertical = edge == .maxY || edge == .minY
        let anchor = vertical ? NSRect(x: fieldRect.minX, y: content.bounds.minY, width: fieldRect.width, height: content.bounds.height) : content.bounds
        popover.show(relativeTo: anchor, of: content, preferredEdge: edge)
        grid.window?.makeFirstResponder(grid)
    }
    func close() { popover.performClose(nil) }
    func popoverDidClose(_ notification: Notification) { onClose?() }
}

final class DateSelectionGrid: NSView {
    let selected: CivilDate
    let minimum: CivilDate?
    private(set) var month: CivilDate
    var onSelect: ((CivilDate) -> Void)?
    var onSelectRange: ((CivilDate, CivilDate) -> Void)?
    var onCancel: (() -> Void)?
    var onResize: ((NSSize) -> Void)?
    private var monthLabel = Theme.label("", size: 14, weight: .semibold)
    private var previous: ActionButton!, next: ActionButton!
    private(set) var dayButtons: [PickerDayButton] = []
    private var rangeStart: CivilDate?
    private var rangeEnd: CivilDate?
    private var focusedDay: CivilDate
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    init(selected: CivilDate, minimum: CivilDate?) {
        self.selected = selected; self.minimum = minimum; month = selected.monthStart; focusedDay = selected
        super.init(frame: .zero)
        wantsLayer = true; layer?.backgroundColor = NSColor.white.cgColor; layer?.cornerRadius = 10
        monthLabel.alignment = .center; monthLabel.frame = NSRect(x: 40, y: 12, width: 140, height: 24); addSubview(monthLabel)
        previous = ActionButton(title: "上个月", symbol: "chevron.left") { [weak self] in self?.navigate(-1) }
        next = ActionButton(title: "下个月", symbol: "chevron.right") { [weak self] in self?.navigate(1) }
        previous.image = Theme.symbol("chevron.left", size: 12); next.image = Theme.symbol("chevron.right", size: 12)
        previous.frame = NSRect(x: 12, y: 10, width: 26, height: 28); next.frame = NSRect(x: 182, y: 10, width: 26, height: 28)
        previous.hoverBackground = Theme.purple.withAlphaComponent(0.10); next.hoverBackground = Theme.purple.withAlphaComponent(0.10)
        previous.layer?.cornerRadius = 5; next.layer?.cornerRadius = 5
        addSubview(previous); addSubview(next)
        for (i, title) in ["一", "二", "三", "四", "五", "六", "日"].enumerated() {
            let label = Theme.label(title, size: 11, color: Theme.muted); label.alignment = .center
            label.frame = NSRect(x: 12 + i * 28, y: 46, width: 28, height: 18); addSubview(label)
        }
        reload()
    }
    required init?(coder: NSCoder) { fatalError() }
    func navigate(_ delta: Int) {
        let target = month.adding(months: delta)
        guard (2...9998).contains(target.year) else { return }
        month = target; focusedDay = target; reload()
    }
    func choose(_ day: CivilDate) {
        guard (2...9998).contains(day.year), minimum.map({ day >= $0 }) ?? true else { return }
        onSelect?(day)
    }
    private func reload() {
        dayButtons.forEach { $0.removeFromSuperview() }; dayButtons = []
        monthLabel.stringValue = "\(month.year)年\(month.month)月"
        previous.isEnabled = month > CivilDate(year: 2, month: 1, day: 1)
        next.isEnabled = month < CivilDate(year: 9998, month: 12, day: 1)
        let days = month.monthDays
        for (i, day) in days.enumerated() {
            let button = PickerDayButton(day: day, grid: self)
            button.font = .systemFont(ofSize: 12, weight: day == selected ? .semibold : .regular)
            button.frame = NSRect(x: 14 + i % 7 * 28, y: 68 + i / 7 * 28, width: 24, height: 24)
            button.isEnabled = (2...9998).contains(day.year) && (minimum.map { day >= $0 } ?? true)
            button.contentTintColor = !button.isEnabled ? Theme.muted.withAlphaComponent(0.4) : (day == selected ? .white : (day.month == month.month ? Theme.ink : Theme.muted))
            button.wantsLayer = true; button.layer?.cornerRadius = 12
            if day == selected { button.layer?.backgroundColor = Theme.purple.cgColor }
            if day == focusedDay && day != selected { button.layer?.borderWidth = 1; button.layer?.borderColor = Theme.purple.withAlphaComponent(0.45).cgColor }
            button.setAccessibilityLabel("选择 \(day.description)")
            addSubview(button); dayButtons.append(button)
        }
        refreshSelectionAppearance()
        let size = NSSize(width: 220, height: 68 + days.count / 7 * 28 + 8)
        setFrameSize(size); onResize?(size); needsDisplay = true
    }
    func date(at point: NSPoint) -> CivilDate? {
        guard point.x >= 12, point.x < 208, point.y >= 68 else { return nil }
        let index = Int((point.y - 68) / 28) * 7 + Int((point.x - 12) / 28)
        guard dayButtons.indices.contains(index), dayButtons[index].isEnabled else { return nil }
        return dayButtons[index].day
    }
    func beginRange(_ day: CivilDate) { rangeStart = day; rangeEnd = day; refreshSelectionAppearance() }
    func updateRange(at point: NSPoint) { rangeEnd = date(at: point); refreshSelectionAppearance() }
    func finishRange(at point: NSPoint) {
        let first = rangeStart, last = date(at: point)
        rangeStart = nil; rangeEnd = nil; refreshSelectionAppearance()
        if let first, let last { onSelectRange?(min(first, last), max(first, last)) }
    }
    private func refreshSelectionAppearance() {
        for button in dayButtons {
            let day = button.day
            let inRange = rangeStart.flatMap { start in rangeEnd.map { min(start, $0) <= day && day <= max(start, $0) } } ?? false
            let endpoint = inRange && (day == rangeStart || day == rangeEnd)
            let strong = endpoint || (rangeStart == nil && day == selected)
            button.restingBackground = strong ? Theme.purple : (inRange ? Theme.purple.withAlphaComponent(0.16) : .clear)
            button.hoverBackground = strong ? Theme.purple.blended(withFraction: 0.13, of: .black) : Theme.purple.withAlphaComponent(0.12)
            button.contentTintColor = !button.isEnabled ? Theme.muted.withAlphaComponent(0.4) : (strong ? .white : (day.month == month.month ? Theme.ink : Theme.muted))
        }
    }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?(); return }
        if event.keyCode == 36 || event.keyCode == 49 { choose(focusedDay); return }
        let steps: [UInt16: Int] = [123: -1, 124: 1, 125: 7, 126: -7]
        if let step = steps[event.keyCode] {
            let target = focusedDay.adding(days: step)
            guard (2...9998).contains(target.year) else { return }
            focusedDay = target
            if target.monthStart != month { month = target.monthStart }; reload()
            return
        }
        super.keyDown(with: event)
    }
}

/// Keep ordinary click/accessibility activation, but use a drag threshold before range selection.
final class PickerDayButton: ActionButton {
    let day: CivilDate
    weak var grid: DateSelectionGrid?
    private var press: NSPoint?
    private var dragging = false
    init(day: CivilDate, grid: DateSelectionGrid) {
        self.day = day; self.grid = grid
        super.init(title: String(day.day)) { [weak grid] in grid?.choose(day) }
    }
    required init?(coder: NSCoder) { fatalError() }
    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        press = grid?.convert(event.locationInWindow, from: nil); dragging = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard let grid, let press else { return }
        let point = grid.convert(event.locationInWindow, from: nil)
        if !dragging && hypot(point.x - press.x, point.y - press.y) >= 4 { dragging = true; grid.beginRange(day) }
        if dragging { grid.updateRange(at: point) }
    }
    override func mouseUp(with event: NSEvent) {
        defer { press = nil; dragging = false }
        guard press != nil, let grid else { return }
        if dragging { grid.finishRange(at: grid.convert(event.locationInWindow, from: nil)) }
        else if bounds.contains(convert(event.locationInWindow, from: nil)) { grid.choose(day) }
    }
}
