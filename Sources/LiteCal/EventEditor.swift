import AppKit

/// One compact, borderless editor shared by create and edit. Its parent owns its lifetime.
final class EventEditor: NSObject, NSWindowDelegate, NSTextFieldDelegate {
    let window: CalendarPanel
    let store: EventStore
    let event: CalendarEvent?
    var onClose: (() -> Void)?
    var onDelete: (() -> Void)?
    let titleField = NSTextField()
    private let errorLabel = Theme.label("", size: 11, color: .systemRed)
    private var saveButton: NSButton!
    private var finished = false
    private(set) var dateSelector: DateSelectionPopover?
    private var startButton: ActionButton!
    private var endButton: ActionButton!
    var startDate: CivilDate { didSet { refreshDates() } }
    var endDate: CivilDate { didSet { refreshDates() } }
    init(event: CalendarEvent?, day: CivilDate, store: EventStore) {
        self.event = event; self.store = store
        startDate = event?.startDate ?? day; endDate = event?.endDate ?? day
        window = CalendarPanel(contentRect: NSRect(x: 0, y: 0, width: 344, height: 252), styleMask: [.borderless], backing: .buffered, defer: false)
        super.init()
        window.title = event == nil ? "新增事项" : "事项详情"
        window.level = .floating; window.isReleasedWhenClosed = false; window.hidesOnDeactivate = false
        window.delegate = self; window.appearance = NSAppearance(named: .aqua)
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = true
        window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        let view = FlippedView(frame: NSRect(x: 0, y: 0, width: 344, height: 252))
        view.wantsLayer = true; view.layer?.backgroundColor = NSColor.white.cgColor; view.layer?.cornerRadius = 12
        view.layer?.borderColor = Theme.line.cgColor; view.layer?.borderWidth = 1; window.contentView = view
        let heading = Theme.label(window.title, size: 16, weight: .semibold)
        heading.frame = NSRect(x: 18, y: 16, width: 260, height: 23); view.addSubview(heading)
        let close = ActionButton(title: "关闭", symbol: "xmark") { [weak self] in self?.cancel() }
        close.frame = NSRect(x: 304, y: 14, width: 24, height: 24); view.addSubview(close)
        titleField.frame = NSRect(x: 18, y: 49, width: 308, height: 32); titleField.font = .systemFont(ofSize: 15)
        titleField.focusRingType = .none
        titleField.bezelStyle = .roundedBezel; titleField.stringValue = event?.title ?? ""
        titleField.placeholderString = "事项名称"; titleField.delegate = self
        titleField.target = self; titleField.action = #selector(save); titleField.setAccessibilityLabel("事项名称"); view.addSubview(titleField)
        for index in 0...1 {
            let label = Theme.label(index == 0 ? "开始" : "结束", size: 13, color: Theme.muted)
            label.frame = NSRect(x: 18, y: 97 + index * 37, width: 42, height: 24); view.addSubview(label)
            let button = ActionButton(title: "") { [weak self] in self?.chooseDate(start: index == 0) }
            button.frame = NSRect(x: 68, y: 93 + index * 37, width: 258, height: 30)
            button.font = .systemFont(ofSize: 14); button.alignment = .left
            button.image = Theme.symbol("calendar", size: 15); button.imagePosition = .imageLeading
            button.restingBackground = NSColor(white: 0.97, alpha: 1); button.hoverBackground = Theme.purple.withAlphaComponent(0.10); button.layer?.cornerRadius = 5
            if index == 0 { startButton = button } else { endButton = button }; view.addSubview(button)
        }
        refreshDates()
        errorLabel.frame = NSRect(x: 18, y: 168, width: 308, height: 30)
        errorLabel.maximumNumberOfLines = 2; errorLabel.lineBreakMode = .byWordWrapping; view.addSubview(errorLabel)
        let cancel = NSButton(title: "取消", target: self, action: #selector(cancel)); cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"; cancel.frame = NSRect(x: 164, y: 207, width: 76, height: 29); view.addSubview(cancel)
        saveButton = NSButton(title: "保存", target: self, action: #selector(save)); saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"; saveButton.bezelColor = Theme.purple; saveButton.contentTintColor = .white
        saveButton.frame = NSRect(x: 244, y: 207, width: 82, height: 29); view.addSubview(saveButton)
        if event != nil {
            let delete = NSButton(title: "删除", target: self, action: #selector(deleteEvent)); delete.bezelStyle = .rounded
            delete.contentTintColor = .systemRed; delete.frame = NSRect(x: 18, y: 207, width: 76, height: 29); view.addSubview(delete)
        }
        window.initialFirstResponder = titleField; updateSave()
    }
    private func refreshDates() {
        for (button, day, label) in [(startButton, startDate, "开始日期"), (endButton, endDate, "结束日期")] {
            button?.title = "  \(day.year)年\(day.month)月\(day.day)日"
            button?.setAccessibilityLabel("\(label)，\(day.description)")
        }
    }
    private func chooseDate(start: Bool) {
        if let current = dateSelector {
            let sameField = current.choosingStart == start
            current.close()
            if sameField { return }
        }
        let selector = DateSelectionPopover(selected: start ? startDate : endDate, minimum: start ? nil : startDate, choosingStart: start)
        dateSelector = selector
        selector.onSelect = { [weak self] day in
            guard let self else { return }
            if start {
                let single = self.startDate == self.endDate
                self.startDate = day
                if single || self.endDate < day { self.endDate = day }
            } else { self.endDate = day }
            self.updateSave()
        }
        selector.onSelectRange = { [weak self] first, last in
            self?.startDate = first; self?.endDate = last; self?.updateSave()
        }
        selector.onClose = { [weak self, weak selector] in
            guard let self, self.dateSelector === selector else { return }; self.dateSelector = nil
        }
        selector.show(relativeTo: start ? startButton : endButton)
    }
    func show() { window.makeKeyAndOrderFront(nil); window.makeFirstResponder(titleField); titleField.selectText(nil) }
    func controlTextDidChange(_ obj: Notification) { updateSave() }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) { cancel(); return true }; return false
    }
    private func updateSave() { saveButton.isEnabled = !titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && startDate <= endDate }
    @objc func save() {
        guard window.attachedSheet == nil, !finished else { return }
        window.makeFirstResponder(nil)
        do { try store.save(id: event?.id, title: titleField.stringValue, startDate: startDate, endDate: endDate); finish() }
        catch { errorLabel.stringValue = error.localizedDescription; NSLog("LiteCal save error: %@", error.localizedDescription) }
    }
    @objc func cancel() { guard window.attachedSheet == nil else { return }; if let dateSelector { dateSelector.close(); return }; finish() }
    @objc private func deleteEvent() { onDelete?() }
    func finish() { guard !finished else { return }; finished = true; dateSelector?.close(); window.orderOut(nil); onClose?() }
    func windowShouldClose(_ sender: NSWindow) -> Bool { cancel(); return false }
}

final class YearField: NSTextField {
    var onScroll: ((Int) -> Void)?
    private var hoverTracking: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas(); if let hoverTracking { removeTrackingArea(hoverTracking) }
        let area = NSTrackingArea(rect: .zero, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited], owner: self)
        hoverTracking = area; addTrackingArea(area)
    }
    override func mouseEntered(with event: NSEvent) { backgroundColor = Theme.purple.withAlphaComponent(0.08) }
    override func mouseExited(with event: NSEvent) { backgroundColor = .white }
    override func scrollWheel(with event: NSEvent) {
        guard abs(event.scrollingDeltaY) >= 1 else { return }; onScroll?(event.scrollingDeltaY > 0 ? 1 : -1)
    }
}
final class MonthJumpPicker: NSObject, NSPopoverDelegate, NSTextFieldDelegate {
    let popover = NSPopover()
    let yearField = YearField()
    var year: Int
    let selected: CivilDate
    var onSelect: ((CivilDate) -> Void)?
    var onClose: (() -> Void)?
    private(set) var buttons: [ActionButton] = []
    init(month: CivilDate) {
        year = month.year; selected = month; super.init()
        let root = FlippedView(frame: NSRect(x: 0, y: 0, width: 272, height: 236))
        root.wantsLayer = true; root.layer?.backgroundColor = NSColor.white.cgColor
        let vc = NSViewController(); vc.view = root; popover.contentViewController = vc
        popover.behavior = .transient; popover.animates = false; popover.delegate = self
        yearField.frame = NSRect(x: 80, y: 12, width: 112, height: 29); yearField.alignment = .center
        yearField.focusRingType = .none; yearField.bezelStyle = .roundedBezel
        yearField.font = .systemFont(ofSize: 17, weight: .semibold); yearField.stringValue = String(year)
        yearField.setAccessibilityLabel("跳转年份"); yearField.delegate = self
        yearField.onScroll = { [weak self] delta in self?.changeYear(delta) }; root.addSubview(yearField)
        for (title, x, delta) in [("上一年", CGFloat(18), -1), ("下一年", CGFloat(222), 1)] {
            let b = ActionButton(title: title, symbol: delta < 0 ? "chevron.left" : "chevron.right") { [weak self] in self?.changeYear(delta) }
            b.hoverBackground = Theme.purple.withAlphaComponent(0.10); b.layer?.cornerRadius = 5
            b.frame = NSRect(x: x, y: 12, width: 32, height: 29); root.addSubview(b)
        }
        for month in 1...12 {
            let b = ActionButton(title: "\(month)月") { [weak self] in self?.choose(month) }
            b.isBordered = false; b.wantsLayer = true; b.layer?.cornerRadius = 5; b.font = .systemFont(ofSize: 14)
            b.frame = NSRect(x: 14 + (month - 1) % 3 * 82, y: 54 + (month - 1) / 3 * 43, width: 80, height: 35)
            root.addSubview(b); buttons.append(b)
        }
        refresh()
    }
    func show(relativeTo view: NSView) { popover.show(relativeTo: view.bounds, of: view, preferredEdge: .maxY) }
    func changeYear(_ delta: Int) { year = min(9998, max(2, (Int(yearField.stringValue) ?? year) + delta)); refresh() }
    func controlTextDidChange(_ obj: Notification) {
        guard let value = Int(yearField.stringValue), (2...9998).contains(value) else { return }; year = value; refreshColors()
    }
    private func refresh() { yearField.stringValue = String(year); refreshColors() }
    private func refreshColors() {
        for (i, b) in buttons.enumerated() {
            let selected = year == selected.year && i + 1 == selected.month
            b.restingBackground = selected ? Theme.purple : NSColor(white: 0.97, alpha: 1)
            b.hoverBackground = selected ? Theme.purple.blended(withFraction: 0.13, of: .black) : Theme.purple.withAlphaComponent(0.12)
            b.contentTintColor = selected ? .white : Theme.ink
        }
    }
    func choose(_ month: Int) {
        guard let value = Int(yearField.stringValue), (2...9998).contains(value) else { NSSound.beep(); return }
        onSelect?(CivilDate(year: value, month: month, day: 1)); popover.performClose(nil)
    }
    func popoverDidClose(_ notification: Notification) { onClose?() }
}

final class DayListWindow: NSObject, NSWindowDelegate {
    let window: CalendarPanel
    let day: CivilDate
    let store: EventStore
    var onEdit: ((CalendarEvent) -> Void)?
    var onNew: (() -> Void)?
    var onDelete: ((CalendarEvent) -> Void)?
    var onClose: (() -> Bool)?
    private let scroll = NSScrollView()
    init(day: CivilDate, store: EventStore) {
        self.day = day; self.store = store
        window = CalendarPanel(contentRect: NSRect(x: 0, y: 0, width: 440, height: 440), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        window.title = "\(day.year)年\(day.month)月\(day.day)日"; window.level = .floating; window.isReleasedWhenClosed = false; window.hidesOnDeactivate = false; window.delegate = self; window.appearance = NSAppearance(named: .aqua)
        window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 440)); window.contentView = view
        scroll.frame = NSRect(x: 18, y: 70, width: 404, height: 350); scroll.hasVerticalScroller = true; scroll.drawsBackground = false; view.addSubview(scroll)
        let add = NSButton(title: "新增事项", target: self, action: #selector(add)); add.bezelStyle = .rounded; add.frame = NSRect(x: 20, y: 20, width: 100, height: 32); view.addSubview(add)
        let done = NSButton(title: "完成", target: self, action: #selector(done)); done.bezelStyle = .rounded; done.keyEquivalent = "\u{1b}"; done.frame = NSRect(x: 330, y: 20, width: 90, height: 32); view.addSubview(done); reload()
    }
    func reload() {
        let items = store.events(on: day)
        let document = FlippedView(frame: NSRect(x: 0, y: 0, width: 388, height: 350)); var y: CGFloat = 0
        for item in items {
            let button = ActionButton(title: item.title) { [weak self] in self?.onEdit?(item) }
            button.contentTintColor = Theme.eventInk(past: item.isPast(today: CivilDate(Date())))
            button.wantsLayer = true; button.layer?.backgroundColor = Theme.eventFill(past: item.isPast(today: CivilDate(Date()))).cgColor; button.layer?.cornerRadius = 4
            let menu = NSMenu()
            menu.addItem(ClosureMenuItem(title: "编辑") { [weak self] in self?.onEdit?(item) })
            menu.addItem(ClosureMenuItem(title: "删除") { [weak self] in self?.onDelete?(item) })
            button.menu = menu
            button.font = .systemFont(ofSize: 15); button.alignment = .left
            button.cell?.wraps = true; button.cell?.lineBreakMode = .byWordWrapping
            let h = max(44, (item.title as NSString).boundingRect(with: NSSize(width: 360, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: NSFont.systemFont(ofSize: 15)]).height + 20)
            button.frame = NSRect(x: 8, y: y, width: 370, height: h); document.addSubview(button); y += h + 4
        }
        if items.isEmpty { let empty = Theme.label("这一天还没有事项", color: Theme.muted); empty.frame = NSRect(x: 12, y: 18, width: 340, height: 24); document.addSubview(empty) }
        document.frame.size.height = max(350, y); scroll.documentView = document
    }
    @objc private func add() { onNew?() }
    @objc private func done() { if onClose?() != false { window.orderOut(nil) } }
    func windowShouldClose(_ sender: NSWindow) -> Bool { done(); return false }
}
final class FlippedView: NSView { override var isFlipped: Bool { true } }
