import AppKit

final class CalendarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
final class FloatingController: NSObject {
    let store: EventStore
    let trigger: CalendarPanel
    let panel: CalendarPanel
    let calendar: MonthView
    let defaults: UserDefaults
    private(set) var isOpen = false
    private(set) var isPinned = false
    private(set) var isDragging = false
    private var transition: UInt = 0
    private var closeWork: DispatchWorkItem?
    private(set) var editor: EventEditor?
    private var editorAnchor: NSRect?
    private(set) var monthPicker: MonthJumpPicker?
    private var eventDragActive = false
    private var confirmationActive = false
    private var keyMonitor: Any?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?
    private var dayList: DayListWindow?
    private var dateTimer: Timer?
    private var menuActive = false
    private var interactionLocked: Bool { editor != nil || dayList != nil || menuActive || monthPicker != nil || eventDragActive || confirmationActive }
    var allowsEventInteraction: Bool { editor == nil && monthPicker == nil && !confirmationActive }
    init(store: EventStore, defaults: UserDefaults) {
        self.store = store; self.defaults = defaults
        trigger = CalendarPanel(contentRect: NSRect(x: 0, y: 0, width: 48, height: 48), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel = CalendarPanel(contentRect: NSRect(x: 0, y: 0, width: 980, height: 760), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        calendar = MonthView(store: store)
        super.init()
        for window in [trigger, panel] {
            window.isOpaque = false; window.backgroundColor = .clear; window.hidesOnDeactivate = false
            window.isReleasedWhenClosed = false; window.level = .floating; window.animationBehavior = .none
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.appearance = NSAppearance(named: .aqua)
        }
        trigger.hasShadow = false; trigger.becomesKeyOnlyIfNeeded = true
        let ball = TriggerView(frame: NSRect(x: 0, y: 0, width: 48, height: 48)); ball.controller = self; trigger.contentView = ball
        panel.hasShadow = true; calendar.controller = self; panel.contentView = calendar
        store.onChange = { [weak self] in self?.calendar.reload(); self?.dayList?.reload() }
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dayChanged), name: .NSCalendarDayChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dayChanged), name: .NSSystemTimeZoneDidChange, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(dayChanged), name: NSWorkspace.didWakeNotification, object: nil)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleCalendarKey(event) == true ? nil : event
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            guard let self else { return event }
            if event.window === self.panel { self.pinCalendar() }
            else if event.window !== self.trigger && event.window !== self.editor?.window && event.window !== self.dayList?.window && event.window !== self.monthPicker?.popover.contentViewController?.view.window && event.window !== self.editor?.dateSelector?.grid.window {
                // Let transient popovers process the outside click before checking locks.
                DispatchQueue.main.async { [weak self] in self?.outsideClicked() }
            }
            return event
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in self?.outsideClicked() }
        }
        positionTrigger(); trigger.orderFrontRegardless(); scheduleMidnight()
    }
    deinit {
        for monitor in [keyMonitor, localMouseMonitor, globalMouseMonitor].compactMap({ $0 }) { NSEvent.removeMonitor(monitor) }
        dateTimer?.invalidate()
    }
    func pinCalendar() { guard isOpen else { return }; isPinned = true; closeWork?.cancel() }
    func outsideClicked() {
        guard !isDragging, editor == nil, dayList == nil, !menuActive, !eventDragActive, !confirmationActive else { return }
        // A month selector has no unsaved draft. Close it explicitly so dismissal
        // does not depend on the ordering of global mouse and popover callbacks.
        let picker = monthPicker; monthPicker = nil; picker?.popover.performClose(nil)
        close()
    }
    func handleCalendarKey(_ event: NSEvent) -> Bool {
        if event.keyCode == 53 && calendar.isEventDragging { calendar.cancelEventDrag(); return true }
        guard isOpen, event.window === panel, !interactionLocked, !isDragging,
              event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
              event.keyCode == 123 || event.keyCode == 124 else { return false }
        pinCalendar(); calendar.changeMonth(event.keyCode == 123 ? -1 : 1); return true
    }
    func setEventDragActive(_ active: Bool) { eventDragActive = active; if active { closeWork?.cancel() } else { scheduleClose() } }
    func showMonthPicker(anchor: NSView) {
        guard editor == nil, !eventDragActive else { return }
        if let monthPicker { monthPicker.popover.performClose(nil); return }
        closeWork?.cancel()
        let picker = MonthJumpPicker(month: calendar.month); monthPicker = picker
        picker.onSelect = { [weak self] in self?.calendar.jump(to: $0) }
        picker.onClose = { [weak self] in self?.monthPicker = nil; self?.scheduleClose() }
        picker.show(relativeTo: anchor)
    }
    func eventMenu(_ item: CalendarEvent, event: NSEvent, view: NSView) {
        guard allowsEventInteraction, !eventDragActive else { return }
        closeWork?.cancel(); menuActive = true
        let menu = NSMenu()
        menu.addItem(ClosureMenuItem(title: "编辑") { [weak self] in self?.edit(event: item, day: item.startDate) })
        menu.addItem(ClosureMenuItem(title: "删除") { [weak self] in self?.confirmDelete(item) })
        NSMenu.popUpContextMenu(menu, with: event, for: view)
        menuActive = false; scheduleClose()
    }
    func confirmDelete(_ item: CalendarEvent) {
        guard !confirmationActive else { return }; confirmationActive = true; closeWork?.cancel()
        let alert = NSAlert(); alert.messageText = "删除这条事项？"; alert.informativeText = item.title
        alert.alertStyle = .warning; alert.addButton(withTitle: "取消"); alert.addButton(withTitle: "删除")
        alert.buttons[1].hasDestructiveAction = true
        alert.beginSheetModal(for: editor?.window ?? dayList?.window ?? panel) { [weak self] response in
            guard let self else { return }; self.confirmationActive = false
            if response == .alertSecondButtonReturn {
                do { try self.store.delete(id: item.id); if self.editor?.event?.id == item.id { self.editor?.finish() } }
                catch { self.showError(error) }
            }
            self.scheduleClose()
        }
    }
    private func screen(pointer: CGPoint? = nil) -> NSScreen? {
        let screens = NSScreen.screens
        guard let index = Placement.screenIndex(window: trigger.frame, screens: screens.map(\.frame), pointer: pointer) else { return nil }
        return screens[index]
    }
    private func positionTrigger() {
        guard let main = NSScreen.main ?? NSScreen.screens.first else { return }
        let origin: CGPoint
        if defaults.object(forKey: "triggerX") != nil {
            origin = CGPoint(x: defaults.double(forKey: "triggerX"), y: defaults.double(forKey: "triggerY"))
        } else { origin = CGPoint(x: main.visibleFrame.maxX - 58, y: main.visibleFrame.midY - 24) }
        let saved = CGRect(origin: origin, size: CGSize(width: 48, height: 48))
        let screens = NSScreen.screens
        let target = Placement.screenIndex(window: saved, screens: screens.map(\.frame)).map { screens[$0] } ?? main
        trigger.setFrame(Placement.clamp(saved, to: target.visibleFrame), display: true)
    }
    private func positionPanel() {
        guard let screen = screen() else { return }
        panel.setFrame(Placement.panel(trigger: trigger.frame, visible: screen.visibleFrame), display: true)
        trigger.orderFrontRegardless()
        repositionChildren()
    }
    func open() {
        closeWork?.cancel()
        guard !isDragging else { return }
        guard !isOpen else { return }
        transition &+= 1; isOpen = true; isPinned = false; calendar.reload(); positionPanel()
        panel.alphaValue = 0; panel.orderFrontRegardless(); trigger.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true); panel.makeKey(); panel.makeFirstResponder(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 1
        }
    }
    func close() {
        guard isOpen, !interactionLocked else { return }
        closeWork?.cancel(); isOpen = false; isPinned = false; transition &+= 1
        let token = transition
        panel.makeFirstResponder(nil)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            DispatchQueue.main.async {
                guard let self, self.transition == token, !self.isOpen else { return }
                self.panel.orderOut(nil); self.panel.alphaValue = 1
            }
        })
    }
    func enteredCalendar() { closeWork?.cancel() }
    func scheduleClose() {
        closeWork?.cancel()
        guard isOpen, !isPinned, !interactionLocked, !isDragging else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.isPinned, !self.interactionLocked, !self.isDragging else { return }
            let p = NSEvent.mouseLocation
            if self.trigger.frame.contains(p) || self.panel.frame.contains(p) { return }
            self.close()
        }
        closeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
    func beginDrag() { closeWork?.cancel(); close(); isDragging = true }
    func moveTrigger(to point: CGPoint) { trigger.setFrameOrigin(point) }
    func endDrag() {
        if let screen = screen(pointer: NSEvent.mouseLocation) { trigger.setFrame(Placement.clamp(trigger.frame, to: screen.visibleFrame), display: true) }
        defaults.set(trigger.frame.minX, forKey: "triggerX"); defaults.set(trigger.frame.minY, forKey: "triggerY")
        isDragging = false
        if isOpen { positionPanel() }
        if trigger.frame.contains(NSEvent.mouseLocation) { open() }
    }
    func edit(event: CalendarEvent?, day: CivilDate, endDay: CivilDate? = nil, anchor: NSRect? = nil) {
        guard !eventDragActive, !confirmationActive else { return }
        monthPicker?.popover.performClose(nil)
        guard editor == nil else { editor?.window.makeKeyAndOrderFront(nil); return }
        if let error = store.loadError { showError(error); return }
        closeWork?.cancel()
        let editor = EventEditor(event: event, day: day, store: store)
        if event == nil, let endDay { editor.endDate = max(day, endDay) }
        self.editor = editor
        editorAnchor = anchor ?? calendar.anchor(for: day)
        editor.onDelete = { [weak self] in if let event { self?.confirmDelete(event) } }
        editor.onClose = { [weak self] in
            guard let self else { return }
            if let window = self.editor?.window { self.panel.removeChildWindow(window) }
            self.editor = nil; self.editorAnchor = nil
            if let list = self.dayList { list.window.makeKeyAndOrderFront(nil) }
            self.scheduleClose()
        }
        panel.addChildWindow(editor.window, ordered: .above)
        positionEditor(); NSApp.activate(ignoringOtherApps: true); editor.show()
    }
    func showDay(_ day: CivilDate) {
        guard dayList == nil else { return }
        closeWork?.cancel()
        let list = DayListWindow(day: day, store: store); dayList = list
        list.onEdit = { [weak self] in self?.edit(event: $0, day: $0.date) }
        list.onDelete = { [weak self] in self?.confirmDelete($0) }
        list.onNew = { [weak self] in self?.edit(event: nil, day: day) }
        list.onClose = { [weak self, weak list] in
            guard let self, let list, self.editor == nil else { return false }
            self.panel.removeChildWindow(list.window); self.dayList = nil; self.scheduleClose(); return true
        }
        panel.addChildWindow(list.window, ordered: .above); positionChild(list.window)
        NSApp.activate(ignoringOtherApps: true); list.window.makeKeyAndOrderFront(nil)
    }
    private func positionChild(_ window: NSWindow) {
        guard let screen = screen() else { return }
        window.setFrame(Placement.clamp(CGRect(x: panel.frame.midX - window.frame.width / 2, y: panel.frame.midY - window.frame.height / 2, width: window.frame.width, height: window.frame.height), to: screen.visibleFrame, margin: 16), display: true)
    }
    private func positionEditor() {
        guard let editor, let screen = screen() else { return }
        let anchor = panel.convertToScreen(calendar.convert(editorAnchor ?? calendar.anchor(for: editor.startDate), to: nil))
        editor.window.setFrame(Placement.overlay(anchor: anchor, size: editor.window.frame.size, visible: screen.visibleFrame), display: true)
    }
    private func repositionChildren() { if let list = dayList { positionChild(list.window) }; positionEditor() }
    @objc private func screensChanged() {
        guard let screen = screen() else { return }
        trigger.setFrame(Placement.clamp(trigger.frame, to: screen.visibleFrame), display: true)
        if isOpen { positionPanel() }; trigger.orderFrontRegardless()
    }
    @objc private func dayChanged() { calendar.reload(); dayList?.reload(); scheduleMidnight() }
    private func scheduleMidnight() {
        dateTimer?.invalidate()
        var c = Calendar(identifier: .gregorian); c.timeZone = .current
        guard let next = c.date(byAdding: .day, value: 1, to: c.startOfDay(for: Date())) else { return }
        dateTimer = Timer(fire: next, interval: 0, repeats: false) { [weak self] _ in self?.dayChanged() }
        RunLoop.main.add(dateTimer!, forMode: .common)
    }
    func showError(_ error: Error) {
        NSLog("LiteCal error: %@", error.localizedDescription)
        menuActive = true; closeWork?.cancel()
        let alert = NSAlert(); alert.messageText = "暂时无法保存日程"; alert.informativeText = error.localizedDescription + "\n原有数据已保留。"; alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true); alert.runModal(); menuActive = false; scheduleClose()
    }
    func makeTriggerMenu() -> NSMenu {
        let menu = NSMenu()
        let quit = NSMenuItem(title: "退出 LiteCal", action: #selector(quit), keyEquivalent: "q")
        quit.target = self; menu.addItem(quit); return menu
    }
    func contextMenu(event: NSEvent, view: NSView) {
        menuActive = true; closeWork?.cancel()
        NSMenu.popUpContextMenu(makeTriggerMenu(), with: event, for: view)
        menuActive = false; scheduleClose()
    }
    func confirmQuit() -> Bool {
        let previousLock = menuActive
        menuActive = true; closeWork?.cancel()
        defer { menuActive = previousLock; scheduleClose() }
        let alert = NSAlert(); alert.alertStyle = .warning
        alert.icon = NSApp.applicationIconImage
        alert.messageText = "退出 LiteCal？"
        alert.informativeText = editor == nil
            ? "退出后，悬浮日历将关闭。已保存的事项会保留在本机。"
            : "当前编辑尚未保存，退出将放弃本次编辑。已保存的事项会保留在本机。"
        alert.addButton(withTitle: "退出"); alert.addButton(withTitle: "取消")
        alert.window.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
final class TriggerView: NSView {
    weak var controller: FloatingController?
    private var tracking: NSTrackingArea?
    private var startPoint: CGPoint?
    private var startOrigin: CGPoint?
    private var dragged = false
    private var isHovering = false
    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true); setAccessibilityRole(.button); setAccessibilityLabel("LiteCal 悬浮日历")
        toolTip = "移入展开日历 · 拖动调整位置 · 右键退出"
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill(); dirtyRect.fill()
        let outer = NSBezierPath(ovalIn: bounds.insetBy(dx: 3, dy: 3))
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(isHovering ? 0.20 : 0.14)
        shadow.shadowBlurRadius = isHovering ? 5 : 4; shadow.shadowOffset = NSSize(width: 0, height: -1); shadow.set()
        NSColor.white.setFill(); outer.fill(); NSGraphicsContext.restoreGraphicsState()
        let inset: CGFloat = isHovering ? 6 : 7
        let fill = isHovering ? Theme.purple.blended(withFraction: 0.15, of: .black)! : Theme.purple
        fill.setFill(); NSBezierPath(ovalIn: bounds.insetBy(dx: inset, dy: inset)).fill()
        BrandArtwork.floatingGlyph(size: 26).draw(in: NSRect(x: bounds.midX - 13, y: bounds.midY - 13, width: 26, height: 26))
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas(); if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: .zero, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited], owner: self); addTrackingArea(tracking!)
    }
    override func mouseEntered(with event: NSEvent) { isHovering = true; needsDisplay = true; controller?.open() }
    override func mouseExited(with event: NSEvent) { isHovering = false; needsDisplay = true; controller?.scheduleClose() }
    override func mouseDown(with event: NSEvent) { startPoint = NSEvent.mouseLocation; startOrigin = window?.frame.origin; dragged = false }
    override func mouseDragged(with event: NSEvent) {
        guard let startPoint, let startOrigin else { return }
        let current = NSEvent.mouseLocation
        if !dragged && hypot(current.x - startPoint.x, current.y - startPoint.y) > 0.5 { dragged = true; controller?.beginDrag() }
        if dragged { controller?.moveTrigger(to: CGPoint(x: startOrigin.x + current.x - startPoint.x, y: startOrigin.y + current.y - startPoint.y)) }
    }
    override func mouseUp(with event: NSEvent) { if dragged { controller?.endDrag() } else { controller?.open() }; startPoint = nil; startOrigin = nil }
    override func rightMouseDown(with event: NSEvent) { controller?.contextMenu(event: event, view: self) }
    override func accessibilityPerformPress() -> Bool { controller?.open(); return true }
}

final class ClosureMenuItem: NSMenuItem {
    private let invoke: () -> Void
    init(title: String, invoke: @escaping () -> Void) {
        self.invoke = invoke; super.init(title: title, action: #selector(run), keyEquivalent: ""); target = self
    }
    required init(coder: NSCoder) { fatalError() }
    @objc private func run() { invoke() }
}
