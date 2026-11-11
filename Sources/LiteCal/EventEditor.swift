import AppKit

/// One compact, borderless editor shared by create and edit. Its parent owns its lifetime.
final class EventEditor: NSObject, NSWindowDelegate, NSTextFieldDelegate {
    let window: CalendarPanel
    let store: EventStore
    let event: CalendarEvent?
    var onClose: (() -> Void)?
    var onDelete: (() -> Void)?
    let titleField = NSTextField()
    let recurrenceButton = NSPopUpButton(frame: .zero, pullsDown: false)
    private let recurrenceNote = Theme.label("", size: 11, color: Theme.muted)
    private let errorLabel = Theme.label("", size: 11, color: .systemRed)
    private var saveButton: NSButton!
    private var finished = false
    private(set) var dateSelector: DateSelectionPopover?
    private var startButton: ActionButton!
    private var endButton: ActionButton!
    var startDate: CivilDate { didSet { refreshDates() } }
    var endDate: CivilDate { didSet { refreshDates() } }
    init(event: CalendarEvent?, day: CivilDate, store: EventStore) {
        let event = event.flatMap { selected in store.events.first { $0.id == selected.id } }
        self.event = event; self.store = store
        startDate = event?.startDate ?? day; endDate = event?.endDate ?? day
        window = CalendarPanel(contentRect: NSRect(x: 0, y: 0, width: 344, height: 376), styleMask: [.borderless], backing: .buffered, defer: false)
        super.init()
        window.title = event == nil ? "新增事项" : "事项详情"
        window.level = .floating; window.isReleasedWhenClosed = false; window.hidesOnDeactivate = false
        window.delegate = self; window.appearance = NSAppearance(named: Theme.isDark ? .darkAqua : .aqua)
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = true
        window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        let view = FlippedView(frame: NSRect(x: 0, y: 0, width: 344, height: 376))
        view.wantsLayer = true; view.layer?.backgroundColor = Theme.background.cgColor; view.layer?.cornerRadius = 14
        view.layer?.borderColor = Theme.line.cgColor; view.layer?.borderWidth = 0.5; window.contentView = view
        let mark = NSImageView(frame: NSRect(x: 18, y: 12, width: 32, height: 32))
        mark.image = BrandArtwork.floatingGlyph(size: 32)
        mark.wantsLayer = true; mark.layer?.backgroundColor = Theme.purple.cgColor; mark.layer?.cornerRadius = 7
        view.addSubview(mark)
        let heading = Theme.label(window.title, size: 16, weight: .semibold)
        heading.frame = NSRect(x: 60, y: 17, width: 234, height: 23); view.addSubview(heading)
        let close = ActionButton(title: "关闭", symbol: "xmark") { [weak self] in self?.cancel() }
        close.frame = NSRect(x: 300, y: 13, width: 28, height: 28); close.hoverBackground = Theme.purple.withAlphaComponent(0.08); close.layer?.cornerRadius = 7; view.addSubview(close)
        let divider = NSView(frame: NSRect(x: 0, y: 55, width: 344, height: 0.5))
        divider.wantsLayer = true; divider.layer?.backgroundColor = Theme.line.cgColor; view.addSubview(divider)
        titleField.frame = NSRect(x: 18, y: 66, width: 308, height: 40); titleField.font = .systemFont(ofSize: 15)
        titleField.focusRingType = .none; titleField.textColor = Theme.ink
        titleField.bezelStyle = .roundedBezel; titleField.stringValue = event?.title ?? ""
        titleField.placeholderString = "事项名称"; titleField.delegate = self
        titleField.target = self; titleField.action = #selector(save); titleField.setAccessibilityLabel("事项名称"); view.addSubview(titleField)
        for index in 0...1 {
            let label = Theme.label(index == 0 ? "开始" : "结束", size: 13, color: Theme.muted)
            label.frame = NSRect(x: 18, y: 125 + index * 45, width: 42, height: 25); view.addSubview(label)
            let button = ActionButton(title: "") { [weak self] in self?.chooseDate(start: index == 0) }
            button.frame = NSRect(x: 68, y: 118 + index * 45, width: 258, height: 38)
            button.font = .systemFont(ofSize: 14); button.alignment = .left
            button.image = Theme.symbol("calendar", size: 15); button.imagePosition = .imageLeading
            button.restingBackground = Theme.fieldFill; button.hoverBackground = Theme.purple.withAlphaComponent(0.10); button.layer?.cornerRadius = 8
            button.layer?.borderWidth = 0.5; button.layer?.borderColor = Theme.line.cgColor
            if index == 0 { startButton = button } else { endButton = button }; view.addSubview(button)
        }
        let repeatLabel = Theme.label("重复", size: 13, color: Theme.muted)
        repeatLabel.frame = NSRect(x: 18, y: 215, width: 42, height: 25); view.addSubview(repeatLabel)
        recurrenceButton.frame = NSRect(x: 68, y: 208, width: 258, height: 38)
        recurrenceButton.addItems(withTitles: RepeatFrequency.allCases.map(\.title))
        recurrenceButton.selectItem(at: RepeatFrequency.allCases.firstIndex(of: event?.recurrence ?? .none)!)
        recurrenceButton.font = .systemFont(ofSize: 14); recurrenceButton.controlSize = .large
        recurrenceButton.isBordered = false; recurrenceButton.wantsLayer = true
        recurrenceButton.layer?.backgroundColor = Theme.fieldFill.cgColor
        recurrenceButton.layer?.cornerRadius = 8; recurrenceButton.layer?.borderWidth = 0.5; recurrenceButton.layer?.borderColor = Theme.line.cgColor
        recurrenceButton.setAccessibilityLabel("重复频率")
        recurrenceButton.target = self; recurrenceButton.action = #selector(recurrenceChanged)
        view.addSubview(recurrenceButton)
        recurrenceNote.frame = NSRect(x: 18, y: 253, width: 308, height: 20); view.addSubview(recurrenceNote)
        recurrenceChanged()
        refreshDates()
        errorLabel.frame = NSRect(x: 18, y: 278, width: 308, height: 32)
        errorLabel.maximumNumberOfLines = 2; errorLabel.lineBreakMode = .byWordWrapping; view.addSubview(errorLabel)
        let footerLine = NSView(frame: NSRect(x: 0, y: 321, width: 344, height: 0.5))
        footerLine.wantsLayer = true; footerLine.layer?.backgroundColor = Theme.line.cgColor; view.addSubview(footerLine)
        let cancel = ActionButton(title: "取消") { [weak self] in self?.cancel() }
        cancel.restingBackground = Theme.controlFill; cancel.hoverBackground = Theme.purple.withAlphaComponent(0.10); cancel.layer?.cornerRadius = 8
        cancel.keyEquivalent = "\u{1b}"; cancel.frame = NSRect(x: 164, y: 333, width: 76, height: 32); view.addSubview(cancel)
        saveButton = ActionButton(title: "保存") { [weak self] in self?.save() }
        (saveButton as? ActionButton)?.restingBackground = Theme.purple
        (saveButton as? ActionButton)?.hoverBackground = Theme.purple.blended(withFraction: 0.13, of: .black)
        saveButton.wantsLayer = true; saveButton.layer?.cornerRadius = 8
        saveButton.keyEquivalent = "\r"; saveButton.contentTintColor = .white
        saveButton.frame = NSRect(x: 244, y: 333, width: 82, height: 32); view.addSubview(saveButton)
        if event != nil {
            let delete = ActionButton(title: "删除") { [weak self] in self?.deleteEvent() }
            delete.restingBackground = Theme.controlFill; delete.hoverBackground = NSColor.systemRed.withAlphaComponent(0.10); delete.layer?.cornerRadius = 8
            delete.contentTintColor = .systemRed; delete.frame = NSRect(x: 18, y: 333, width: 76, height: 32); view.addSubview(delete)
        }
        window.initialFirstResponder = titleField; updateSave()
    }
    func applyAppearance() {
        guard let root = window.contentView else { return }
        root.layer?.backgroundColor = Theme.background.cgColor
        root.layer?.borderColor = Theme.line.cgColor
        titleField.textColor = Theme.ink
        recurrenceButton.layer?.backgroundColor = Theme.fieldFill.cgColor
        recurrenceButton.layer?.borderColor = Theme.line.cgColor
        recurrenceButton.contentTintColor = Theme.ink
        for subview in root.subviews {
            if let mark = subview as? NSImageView { mark.layer?.backgroundColor = Theme.purple.cgColor }
            if subview.frame.height <= 1 { subview.layer?.backgroundColor = Theme.line.cgColor }
            if let label = subview as? NSTextField, label !== titleField, label !== errorLabel {
                label.textColor = label.stringValue == window.title ? Theme.ink : Theme.muted
            }
            guard let button = subview as? ActionButton else { continue }
            if button === startButton || button === endButton {
                button.restingBackground = Theme.fieldFill
                button.hoverBackground = Theme.purple.withAlphaComponent(0.10)
                button.layer?.borderColor = Theme.line.cgColor
                button.contentTintColor = Theme.ink
            } else if button === saveButton {
                button.restingBackground = Theme.purple
                button.hoverBackground = Theme.purple.blended(withFraction: 0.13, of: .black)
                button.contentTintColor = .white
            } else if button.title == "删除" {
                button.restingBackground = Theme.controlFill
            } else if button.title == "取消" {
                button.restingBackground = Theme.controlFill
                button.hoverBackground = Theme.purple.withAlphaComponent(0.10)
                button.contentTintColor = Theme.ink
            } else { button.contentTintColor = Theme.ink }
        }
        window.displayIfNeeded()
    }
    @objc func recurrenceChanged() {
        let frequency = RepeatFrequency.allCases[recurrenceButton.indexOfSelectedItem]
        recurrenceNote.stringValue = frequency == .none && (event?.recurrence ?? .none) != .none ? "保存将更新整组日程，并停止后续重复" :
            (frequency == .none ? "" : "从开始日期重复；编辑、拖动、删除作用于整组")
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
    private func updateSave() {
        saveButton.isEnabled = !titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && startDate <= endDate
        saveButton.alphaValue = saveButton.isEnabled ? 1 : 0.55
    }
    @objc func save() {
        guard window.attachedSheet == nil, !finished else { return }
        window.makeFirstResponder(nil)
        do { try store.save(id: event?.id, title: titleField.stringValue, startDate: startDate, endDate: endDate, recurrence: RepeatFrequency.allCases[recurrenceButton.indexOfSelectedItem]); finish() }
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
    override func mouseExited(with event: NSEvent) { backgroundColor = Theme.background }
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
    private var hoverHints: HoverHintPresenter?
    init(month: CivilDate) {
        year = month.year; selected = month; super.init()
        let root = FlippedView(frame: NSRect(x: 0, y: 0, width: 272, height: 236))
        root.wantsLayer = true; root.layer?.backgroundColor = Theme.background.cgColor
        hoverHints = HoverHintPresenter(root: root)
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
            hoverHints?.attach(button: b) { title }
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
            b.restingBackground = selected ? Theme.purple : Theme.fieldFill
            b.hoverBackground = selected ? Theme.purple.blended(withFraction: 0.13, of: .black) : Theme.purple.withAlphaComponent(0.12)
            b.contentTintColor = selected ? .white : Theme.ink
        }
    }
    func choose(_ month: Int) {
        guard let value = Int(yearField.stringValue), (2...9998).contains(value) else { NSSound.beep(); return }
        onSelect?(CivilDate(year: value, month: month, day: 1)); popover.performClose(nil)
    }
    func popoverDidClose(_ notification: Notification) { hoverHints?.clear(); onClose?() }
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
        window.title = "\(day.year)年\(day.month)月\(day.day)日"; window.level = .floating; window.isReleasedWhenClosed = false; window.hidesOnDeactivate = false; window.delegate = self; window.appearance = NSAppearance(named: Theme.isDark ? .darkAqua : .aqua)
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
            menu.addItem(ClosureMenuItem(title: item.recurrence == .none ? "编辑" : "编辑整组") { [weak self] in self?.onEdit?(item) })
            menu.addItem(ClosureMenuItem(title: item.recurrence == .none ? "删除" : "删除整组") { [weak self] in self?.onDelete?(item) })
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
