import AppKit

/// A row is one selectable Monday–Sunday week. Only today gets a date highlight.
final class WeekSelectionPopover: NSObject, NSPopoverDelegate {
    let popover = NSPopover()
    let grid: WeekSelectionGrid
    var onSelect: ((CivilDate) -> Void)?
    var onClose: (() -> Void)?

    init(week: CivilDate) {
        grid = WeekSelectionGrid(month: week.adding(days: 3).monthStart, selectedWeek: week.weekStart)
        super.init()
        let content = NSViewController(); content.view = grid
        popover.contentViewController = content; popover.contentSize = grid.frame.size
        popover.behavior = .transient; popover.animates = false; popover.delegate = self
        popover.appearance = NSAppearance(named: .aqua)
        grid.onResize = { [weak self] in self?.popover.contentSize = $0 }
        grid.onSelect = { [weak self] week in
            guard let self else { return }
            let callback = self.onSelect
            self.popover.performClose(nil)
            callback?(week)
        }
    }

    func show(relativeTo view: NSView) { popover.show(relativeTo: view.bounds, of: view, preferredEdge: .maxY) }
    func close() { popover.performClose(nil) }
    func popoverDidClose(_ notification: Notification) { onClose?() }
}

final class WeekSelectionGrid: NSView {
    private var month: CivilDate
    private let selectedWeek: CivilDate
    private let monthLabel = Theme.label("", size: 15, weight: .semibold)
    private var previous: ActionButton!, next: ActionButton!
    private var rows: [WeekRowButton] = []
    var onSelect: ((CivilDate) -> Void)?
    var onResize: ((NSSize) -> Void)?
    override var isFlipped: Bool { true }

    init(month: CivilDate, selectedWeek: CivilDate) {
        self.month = month; self.selectedWeek = selectedWeek
        super.init(frame: .zero)
        wantsLayer = true; layer?.backgroundColor = NSColor.white.cgColor; layer?.cornerRadius = 10
        monthLabel.alignment = .center; monthLabel.frame = NSRect(x: 48, y: 12, width: 176, height: 26)
        addSubview(monthLabel)
        previous = ActionButton(title: "上个月", symbol: "chevron.left") { [weak self] in self?.navigate(-1) }
        next = ActionButton(title: "下个月", symbol: "chevron.right") { [weak self] in self?.navigate(1) }
        for (button, x) in [(previous!, CGFloat(12)), (next!, CGFloat(234))] {
            button.frame = NSRect(x: x, y: 10, width: 26, height: 28)
            button.hoverBackground = Theme.purple.withAlphaComponent(0.10)
            button.layer?.cornerRadius = 5; addSubview(button)
        }
        for (i, title) in ["一", "二", "三", "四", "五", "六", "日"].enumerated() {
            let label = Theme.label(title, size: 11, color: Theme.muted)
            label.alignment = .center
            label.frame = NSRect(x: 14 + i * 35, y: 46, width: 35, height: 18)
            addSubview(label)
        }
        reload()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func navigate(_ delta: Int) {
        let target = month.adding(months: delta)
        guard (2...9998).contains(target.year) else { return }
        month = target; reload()
    }

    private func reload() {
        rows.forEach { $0.removeFromSuperview() }; rows = []
        monthLabel.stringValue = "\(month.year)年\(month.month)月"
        previous.isEnabled = month > CivilDate(year: 2, month: 1, day: 1)
        next.isEnabled = month < CivilDate(year: 9998, month: 12, day: 1)
        let days = month.monthDays
        let today = CivilDate(Date())
        for row in 0..<(days.count / 7) {
            let week = days[row * 7]
            let button = WeekRowButton(week: week, month: month, today: today, isSelected: week == selectedWeek) { [weak self] in self?.onSelect?(week) }
            button.frame = NSRect(x: 10, y: 68 + row * 36, width: 252, height: 34)
            button.isEnabled = (2...9998).contains(week.year)
            addSubview(button); rows.append(button)
        }
        let size = NSSize(width: 272, height: 76 + days.count / 7 * 36)
        setFrameSize(size); onResize?(size)
    }
}

final class WeekRowButton: NSButton {
    let week: CivilDate
    let month: CivilDate
    let today: CivilDate
    let isSelected: Bool
    private let onChoose: () -> Void
    private var hovered = false
    private var tracking: NSTrackingArea?
    override var isFlipped: Bool { true }

    init(week: CivilDate, month: CivilDate, today: CivilDate, isSelected: Bool, onChoose: @escaping () -> Void) {
        self.week = week; self.month = month; self.today = today; self.isSelected = isSelected; self.onChoose = onChoose
        super.init(frame: .zero)
        isBordered = false; target = self; action = #selector(choose)
        let end = week.adding(days: 6)
        setAccessibilityLabel("选择 \(week.description) 至 \(end.description) 这一周")
        setAccessibilityValue(isSelected ? "当前显示周" : "")
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func choose() { onChoose() }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: .zero, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited], owner: self)
        addTrackingArea(tracking!)
    }
    override func mouseEntered(with event: NSEvent) { hovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovered = false; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        if isSelected || (hovered && isEnabled) {
            Theme.purple.withAlphaComponent(isSelected ? (hovered ? 0.22 : 0.16) : 0.09).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7).fill()
        }
        let style = NSMutableParagraphStyle(); style.alignment = .center
        for column in 0..<7 {
            let day = week.adding(days: column)
            let isToday = day == today && today.monthStart == month
            let x = CGFloat(column) * 35 + 3.5
            if isToday {
                Theme.purple.setFill()
                NSBezierPath(ovalIn: NSRect(x: x + 3, y: 3, width: 28, height: 28)).fill()
            }
            let color = isToday ? NSColor.white : (day.monthStart == month ? Theme.ink : Theme.muted)
            (String(day.day) as NSString).draw(in: NSRect(x: x, y: 8, width: 35, height: 20),
                withAttributes: [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: color, .paragraphStyle: style])
        }
    }
}
