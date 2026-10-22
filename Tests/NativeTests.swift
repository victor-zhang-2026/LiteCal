import AppKit
@main struct NativeTests {
    static func main() throws {
        let app = NSApplication.shared; app.setActivationPolicy(.accessory)
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let store = EventStore(directory: directory.appendingPathComponent("native-data-" + UUID().uuidString))
        let day = CivilDate(Date())
        for n in 1...12 { try store.save(title: n == 4 ? String(repeating: "长标题完整阅读测试", count: 12) : "测试事项 \(n)", date: day) }
        for key in ["2026-03-01", "2021-02-01"] { for n in 1...8 { try store.save(title: "布局测试 \(n)", date: CivilDate(key: key)!) } }
        let defaults = UserDefaults(suiteName: "app.litecal.native-tests")!
        let controller = FloatingController(store: store, defaults: defaults)
        var count = 0
        func check(_ passed: Bool, _ name: String) { count += 1; if !passed { fatalError("FAIL: \(name)") }; print("PASS \(name)") }
        func pump(_ seconds: Double = 0.2) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }
        func allViews(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(allViews) }
        func button(_ window: NSWindow, _ title: String) -> NSButton { allViews(window.contentView!).compactMap { $0 as? NSButton }.first { $0.title == title }! }
        func snapshot(_ view: NSView, _ name: String) throws {
            view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
            let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name + ".png"))
        }
        func dialog(_ title: String) -> NSWindow { app.windows.first { $0.title == title && $0.isVisible }! }
        let entry = NSEvent.mouseEvent(with: .mouseMoved, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: controller.trigger.windowNumber, context: nil, eventNumber: 1, clickCount: 0, pressure: 0)!
        controller.trigger.contentView!.mouseEntered(with: entry); pump()
        check(controller.isOpen && controller.panel.isVisible, "hover handler opens native panel")
        check(controller.trigger.frame.size == NSSize(width: 48, height: 48), "LiteTick-sized 48 pt trigger window")
        for (name, hovering) in [("trigger-rest", false), ("trigger-hover", true)] {
            let view = controller.trigger.contentView!
            if hovering { view.mouseEntered(with: entry) } else { view.mouseExited(with: entry) }
            view.displayIfNeeded()
            let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name + ".png"))
        }
        for _ in 0..<12 { controller.close(); controller.open() }; pump()
        check(controller.isOpen && controller.panel.isVisible && controller.panel.alphaValue == 1, "rapid reopen survives stale animation completions")
        // View-backed native snapshots at five/six/four rows and compact screen size.
        for (name, month, size) in [("month-five", "2026-10-01", NSSize(width: 980,height: 760)), ("month-six", "2026-03-01", NSSize(width: 980,height: 760)), ("month-four", "2021-02-01", NSSize(width: 980,height: 760)), ("month-compact", "2026-03-01", NSSize(width: 936,height: 616))] {
            controller.calendar.month = CivilDate(key: month)!; controller.calendar.reload(); controller.panel.setContentSize(size)
            controller.calendar.layoutSubtreeIfNeeded(); pump(0.02)
            let cells = controller.calendar.subviews.compactMap { $0 as? DayView }
            for cell in cells {
                cell.layoutSubtreeIfNeeded()
                let number = cell.subviews.compactMap { $0 as? NSTextField }.first { $0.stringValue == String(cell.day.day) }!
                check(number.attributedStringValue.size().width + 4 <= number.frame.width, "\(name) date number fits without ellipsis")
            }
            for bar in controller.calendar.bars {
                check(controller.calendar.bounds.contains(bar.frame), "bar stays inside month grid")
                check(bar.segment.lane < 3, "three visible lanes")
            }
            for (day, ids) in controller.calendar.eventLayout.hiddenIDs {
                check(ids.count == store.events(on: day).count - controller.calendar.bars.filter { $0.event.contains(day) && $0.segment.week == cells.firstIndex(where: { $0.day == day })! / 7 }.count, "overflow exact count")
            }
            let view = controller.calendar
            let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name + ".png"))
        }
        button(controller.panel, "今天").performClick(nil); controller.calendar.layoutSubtreeIfNeeded()
        check(controller.calendar.month == day.monthStart, "today button returns current month")
        let initialMonth = controller.calendar.month
        button(controller.panel, "上个月").performClick(nil); check(controller.calendar.month == initialMonth.adding(months: -1), "previous month button")
        button(controller.panel, "下个月").performClick(nil); check(controller.calendar.month == initialMonth, "next month button")
        let targetDay = day.adding(days: 1)
        controller.calendar.month = targetDay.monthStart; controller.calendar.reload(); controller.calendar.layoutSubtreeIfNeeded()
        let targetCell = controller.calendar.subviews.compactMap { $0 as? DayView }.first { $0.day == targetDay }!
        let dbl = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: controller.panel.windowNumber, context: nil, eventNumber: 2, clickCount: 2, pressure: 1)!
        targetCell.mouseDown(with: dbl); pump()
        let editor = dialog("新增事项")
        controller.close(); pump()
        check(controller.isOpen && editor.isVisible, "editor prevents collapse")
        let field = allViews(editor.contentView!).compactMap { $0 as? NSTextField }.first { $0.isEditable }!
        field.stringValue = "原生控件新增测试"
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: field)
        button(editor, "保存").performClick(nil); pump()
        check(store.events(on: targetDay).contains { $0.title == "原生控件新增测试" }, "native save persists selected civil date")
        controller.open(); controller.calendar.layoutSubtreeIfNeeded()
        let row = controller.calendar.bars.first { $0.event.title == "原生控件新增测试" }!
        _ = row.accessibilityPerformPress(); pump()
        let edit = dialog("事项详情")
        let editField = allViews(edit.contentView!).compactMap { $0 as? NSTextField }.first { $0.isEditable }!
        editField.stringValue = "已修改并移到下月"
        controller.editor!.startDate = targetDay.adding(months: 1); controller.editor!.endDate = targetDay.adding(months: 1)
        button(edit, "保存").performClick(nil); pump()
        check(store.events(on: targetDay.adding(months: 1)).contains { $0.title == "已修改并移到下月" }, "native edit moves date")
        controller.open(); controller.showDay(day); pump()
        let list = app.windows.first { $0.title == "\(day.year)年\(day.month)月\(day.day)日" && $0.isVisible }!
        check(allViews(list.contentView!).compactMap { $0 as? NSButton }.contains { $0.title.count > 50 }, "overflow list contains full long title")
        controller.close(); check(controller.isOpen, "day list prevents collapse")
        button(list, "完成").performClick(nil); pump()
        controller.open(); controller.edit(event: store.events(on: day).first!, day: day); pump()
        let deletion = dialog("事项详情"); button(deletion, "删除").performClick(nil); pump()
        let sheet = deletion.attachedSheet!
        check(sheet.isVisible && controller.isOpen, "delete confirmation keeps calendar visible")
        button(sheet, "取消").performClick(nil); pump()
        check(store.events(on: day).count == 12, "cancel deletion preserves event")
        button(deletion, "删除").performClick(nil); pump()
        button(deletion.attachedSheet!, "删除").performClick(nil); pump()
        check(store.events(on: day).count == 11, "confirmed deletion persists")
        check(EventStore(directory: store.directory).events.count == store.events.count, "restart reload after native CRUD")
        // Quick month navigation, compact editor, ranges and dynamic history colors.
        controller.open(); controller.calendar.layoutSubtreeIfNeeded()
        controller.showMonthPicker(anchor: controller.calendar.monthButton); pump()
        check(controller.monthPicker != nil, "month selector opens")
        try snapshot(controller.monthPicker!.popover.contentViewController!.view, "month-picker")
        controller.close(); check(controller.isOpen, "month selector prevents collapse")
        controller.monthPicker!.yearField.stringValue = "2027"; controller.monthPicker!.choose(1); pump()
        check(controller.calendar.month == CivilDate(key: "2027-01-01")!, "year input and month selection jump")
        button(controller.panel, "今天").performClick(nil)
        let rangeDay = CivilDate(key: "2027-03-08")!
        controller.calendar.jump(to: rangeDay); controller.calendar.layoutSubtreeIfNeeded()
        controller.edit(event: nil, day: rangeDay); pump()
        check(controller.editor!.window.styleMask == .borderless && controller.editor!.window.frame.width == 344, "compact borderless anchored editor")
        let rangeEditor = controller.editor!
        try snapshot(rangeEditor.window.contentView!, "compact-editor")
        let dateButton = allViews(rangeEditor.window.contentView!).compactMap { $0 as? NSButton }.first { $0.accessibilityLabel()?.hasPrefix("结束日期") == true }!
        dateButton.performClick(nil); pump()
        check(rangeEditor.dateSelector?.popover.isShown == true, "date button opens compact shared calendar popover")
        try snapshot(rangeEditor.dateSelector!.grid, "date-picker")
        let originalDate = rangeEditor.endDate
        rangeEditor.dateSelector!.grid.navigate(1)
        rangeEditor.dateSelector!.close(); pump()
        check(rangeEditor.endDate == originalDate && rangeEditor.dateSelector == nil, "navigation and outside-close leave date unchanged")
        dateButton.performClick(nil); pump()
        rangeEditor.dateSelector!.grid.cancelOperation(nil); pump()
        check(rangeEditor.endDate == originalDate && controller.editor === rangeEditor, "escape closes picker without cancelling editor")
        let startButton = allViews(rangeEditor.window.contentView!).compactMap { $0 as? NSButton }.first { $0.accessibilityLabel()?.hasPrefix("开始日期") == true }!
        startButton.performClick(nil); pump()
        let oldSelector = rangeEditor.dateSelector!
        dateButton.performClick(nil); pump()
        check(!oldSelector.popover.isShown && rangeEditor.dateSelector?.choosingStart == false, "only one date selector exists when switching fields")
        rangeEditor.dateSelector!.grid.choose(rangeDay.adding(days: -1))
        check(rangeEditor.endDate == rangeDay, "end date before start is rejected")
        rangeEditor.dateSelector!.grid.choose(rangeDay.adding(days: 2)); pump()
        check(rangeEditor.endDate == rangeDay.adding(days: 2) && rangeEditor.dateSelector == nil, "selection immediately updates end and closes")
        startButton.performClick(nil); pump(); rangeEditor.dateSelector!.grid.choose(rangeDay.adding(days: 5)); pump()
        check(rangeEditor.startDate == rangeDay.adding(days: 5) && rangeEditor.endDate == rangeDay.adding(days: 5), "moving start beyond end makes valid single day")
        startButton.performClick(nil); pump(); rangeEditor.dateSelector!.grid.choose(rangeDay); pump()
        check(rangeEditor.startDate == rangeDay && rangeEditor.endDate == rangeDay, "moving single-day start keeps same-day range")
        for key in ["2021-02-01", "2026-10-01", "2026-03-01"] {
            let value = CivilDate(key: key)!, grid = DateSelectionGrid(selected: CivilDate(key: key)!, minimum: nil)
            check(grid.dayButtons.count == value.monthDays.count, "date selector four-to-six rows reuse civil-date grid")
            check(grid.bounds.width == 220 && grid.bounds.height == (grid.dayButtons.last!.frame.maxY + 12), "date selector bounds fit content exactly")
            check(grid.dayButtons.allSatisfy { grid.bounds.contains($0.frame) }, "all date buttons fit")
            try snapshot(grid, "date-picker-" + key)
        }
        // Move the editor itself across the real screen; no synthetic monitors or screen-size assumptions.
        if let screen = rangeEditor.window.screen {
            let visible = screen.visibleFrame
            for (name, origin) in [("top", NSPoint(x: visible.midX - 172, y: visible.maxY - 260)), ("bottom", NSPoint(x: visible.midX - 172, y: visible.minY + 8)), ("left", NSPoint(x: visible.minX + 8, y: visible.midY - 126)), ("right", NSPoint(x: visible.maxX - 352, y: visible.midY - 126))] {
                rangeEditor.window.setFrameOrigin(origin)
                dateButton.performClick(nil); pump()
                let selector = rangeEditor.dateSelector!, popup = selector.grid.window!
                check(visible.contains(popup.frame), "date popover within screen at \(name)")
                let intersection = popup.frame.intersection(rangeEditor.window.frame)
                check(intersection.isNull || intersection.width <= 1 || intersection.height <= 1, "date popover avoids fields and actions at \(name)")
                if name == "top" { check(popup.frame.maxY <= rangeEditor.window.frame.minY + 1, "date popover prefers below editor") }
                if name == "bottom" { check(popup.frame.minY >= rangeEditor.window.frame.maxY - 1, "date popover flips upward when needed") }
                selector.close(); pump()
            }
        }

        rangeEditor.titleField.stringValue = "连续三天测试"; rangeEditor.startDate = rangeDay; rangeEditor.endDate = rangeDay.adding(days: 2)
        rangeEditor.save(); pump()
        let range = store.events.first { $0.title == "连续三天测试" }!
        check(range.duration == 2 && controller.calendar.bars.contains { $0.event.id == range.id }, "editor creates inclusive three-day event")
        controller.calendar.todayProvider = { range.endDate }
        controller.calendar.reload(); controller.calendar.layoutSubtreeIfNeeded()
        check(controller.calendar.bars.filter { $0.event.id == range.id }.allSatisfy { !$0.past }, "ongoing event remains normal on end date")
        controller.calendar.todayProvider = { range.endDate.adding(days: 1) }
        NotificationCenter.default.post(name: .NSCalendarDayChanged, object: nil); pump()
        check(controller.calendar.bars.filter { $0.event.id == range.id }.allSatisfy { $0.past }, "day change notification refreshes history style")
        controller.calendar.todayProvider = { day }
        // Use a sparse month so both single and multi-day bars can be dragged.
        let dragDay = CivilDate(key: "2027-04-08")!
        let single = try store.save(title: "单日拖动", date: dragDay)
        let span = try store.save(title: "三日拖动", startDate: dragDay.adding(days: 4), endDate: dragDay.adding(days: 6))
        controller.open(); controller.calendar.jump(to: dragDay); controller.calendar.layoutSubtreeIfNeeded()
        func point(_ day: CivilDate) -> NSPoint { let r = controller.calendar.anchor(for: day); return NSPoint(x: r.midX, y: r.midY) }
        let singleBar = controller.calendar.bars.first { $0.event.id == single.id }!
        controller.calendar.startEventDrag(singleBar, point: NSPoint(x: singleBar.frame.midX, y: singleBar.frame.midY))
        controller.calendar.updateEventDrag(point: point(dragDay.adding(days: 1)))
        controller.close(); check(controller.isOpen, "drag locks calendar open")
        check(controller.calendar.cells.filter { $0.isDropTarget }.map(\.day) == [dragDay.adding(days: 1)], "drag target highlights")
        check(controller.calendar.finishEventDrag(point: point(dragDay.adding(days: 1))), "single drag succeeds")
        check(store.events.first { $0.id == single.id }!.startDate == dragDay.adding(days: 1), "single drag persisted")
        controller.calendar.layoutSubtreeIfNeeded()
        let spanBar = controller.calendar.bars.first { $0.event.id == span.id }!
        let grabbed = span.startDate.adding(days: 1)
        controller.calendar.startEventDrag(spanBar, point: point(grabbed))
        check(controller.calendar.finishEventDrag(point: point(grabbed.adding(days: 2))), "multi-day drag succeeds from middle date")
        check(store.events.first { $0.id == span.id }!.startDate == span.startDate.adding(days: 2) && store.events.first { $0.id == span.id }!.duration == 2, "multi drag shifts two days with duration intact")
        controller.calendar.layoutSubtreeIfNeeded()
        let cancelBar = controller.calendar.bars.first { $0.event.id == span.id }!
        let dataBeforeCancel = try Data(contentsOf: store.file)
        controller.calendar.startEventDrag(cancelBar, point: NSPoint(x: cancelBar.frame.midX, y: cancelBar.frame.midY))
        check(!controller.calendar.finishEventDrag(point: NSPoint(x: -10, y: -10)), "invalid drop cancels")
        check(try Data(contentsOf: store.file) == dataBeforeCancel, "cancelled drag changes no data")
        controller.calendar.startEventDrag(cancelBar, point: NSPoint(x: cancelBar.frame.midX, y: cancelBar.frame.midY)); controller.calendar.cancelEventDrag()
        check(!controller.calendar.isEventDragging && cancelBar.alphaValue == 1, "escape cancellation restores appearance")
        // Exercise the actual bar mouse handlers, including conversion between flipped views and windows.
        controller.open(); controller.calendar.layoutSubtreeIfNeeded()
        let mouseBar = controller.calendar.bars.first { $0.event.id == single.id }!
        let mouseStartDay = store.events.first { $0.id == single.id }!.startDate
        let startPoint = NSPoint(x: mouseBar.frame.midX, y: mouseBar.frame.midY)
        let endPoint = point(mouseStartDay.adding(days: 2))
        func mouse(_ type: NSEvent.EventType, _ point: NSPoint) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: controller.calendar.convert(point, to: nil), modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: controller.panel.windowNumber, context: nil, eventNumber: 50, clickCount: 1, pressure: 1)!
        }
        mouseBar.mouseDown(with: mouse(.leftMouseDown, startPoint))
        mouseBar.mouseDragged(with: mouse(.leftMouseDragged, endPoint))
        check(controller.calendar.isEventDragging, "mouse gesture crosses threshold and begins drag")
        mouseBar.mouseUp(with: mouse(.leftMouseUp, endPoint))
        check(store.events.first { $0.id == single.id }!.startDate == mouseStartDay.adding(days: 2), "mouse drag handlers persist precise two-day shift")
        check(controller.editor == nil, "drag release does not open editor")
        // Final interaction polish: keyboard scope, pinning, blank-cell creation and shared picker gestures.
        check(controller.makeTriggerMenu().items.map(\.title) == ["退出 LiteCal"], "trigger menu contains only Exit")
        func key(_ code: UInt16, window: NSWindow? = nil, flags: NSEvent.ModifierFlags = []) -> NSEvent {
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: (window ?? controller.panel).windowNumber, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: code)!
        }
        let keyboardMonth = controller.calendar.month
        check(controller.handleCalendarKey(key(123)) && controller.calendar.month == keyboardMonth.adding(months: -1), "plain Left switches previous month")
        check(controller.handleCalendarKey(key(124)) && controller.calendar.month == keyboardMonth, "plain Right switches next month")
        check(!controller.handleCalendarKey(key(124, flags: .command)) && controller.calendar.month == keyboardMonth, "modified arrow leaves month unchanged")
        check(controller.isPinned, "keyboard navigation retains calendar")
        controller.trigger.setFrameOrigin(NSPoint(x: -10000, y: -10000)); controller.panel.setFrameOrigin(NSPoint(x: -12000, y: -12000))
        controller.scheduleClose(); pump(0.5)
        check(controller.isOpen, "pinned calendar remains open outside pointer")
        controller.outsideClicked(); pump()
        check(!controller.isOpen && !controller.isPinned, "outside click closes and clears pinned state")
        controller.open(); check(!controller.isPinned, "reopened hover preview starts unpinned")
        controller.calendar.layoutSubtreeIfNeeded()
        let clickCell = controller.calendar.cells.first!
        let clickPoint = NSPoint(x: clickCell.frame.minX + 6, y: clickCell.frame.maxY - 6)
        app.sendEvent(mouse(.leftMouseDown, clickPoint)); app.sendEvent(mouse(.leftMouseUp, clickPoint))
        check(controller.isPinned, "application mouse monitor pins a real calendar click")
        let outsideWindow = CalendarPanel(contentRect: NSRect(x: 20, y: 20, width: 100, height: 100), styleMask: [.borderless], backing: .buffered, defer: false)
        outsideWindow.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        outsideWindow.orderFront(nil)
        let outsideEvent = NSEvent.mouseEvent(with: .leftMouseDown, location: NSPoint(x: 10, y: 10), modifierFlags: [], timestamp: 0, windowNumber: outsideWindow.windowNumber, context: nil, eventNumber: 51, clickCount: 1, pressure: 1)!
        app.sendEvent(outsideEvent); pump()
        check(!controller.isOpen, "application mouse monitor dismisses on unrelated window click")
        outsideWindow.orderOut(nil); controller.open()
        controller.calendar.jump(to: CivilDate(key: "2027-05-01")!); controller.calendar.layoutSubtreeIfNeeded()
        let creationFirst = CivilDate(key: "2027-05-07")!, creationLast = creationFirst.adding(days: 3)
        let creationCell = controller.calendar.cells.first { $0.day == creationFirst }!
        creationCell.mouseDown(with: mouse(.leftMouseDown, point(creationFirst)))
        creationCell.mouseDragged(with: mouse(.leftMouseDragged, point(creationLast)))
        check(controller.calendar.cells.filter(\.isDropTarget).count == 4, "blank-cell drag highlights four days across week")
        try snapshot(controller.calendar, "blank-range-preview")
        creationCell.mouseUp(with: mouse(.leftMouseUp, point(creationLast))); pump()
        check(controller.editor?.startDate == creationFirst && controller.editor?.endDate == creationLast, "blank-cell mouse drag opens inclusive range editor")
        let draft = controller.editor!
        check(!controller.handleCalendarKey(key(124, window: draft.window)), "editor cursor arrows do not switch month")
        check(!controller.handleCalendarKey(key(124)), "editor lock protects underlying calendar arrows")
        controller.outsideClicked(); check(controller.isOpen && controller.editor === draft, "outside click preserves unsaved editor")
        let starting = allViews(draft.window.contentView!).compactMap { $0 as? NSButton }.first { $0.accessibilityLabel()?.hasPrefix("开始日期") == true }!
        let ending = allViews(draft.window.contentView!).compactMap { $0 as? NSButton }.first { $0.accessibilityLabel()?.hasPrefix("结束日期") == true }!
        starting.performClick(nil); pump()
        let pickerGrid = draft.dateSelector!.grid
        let pickStart = pickerGrid.dayButtons.first { $0.day == creationFirst }!
        let pickEnd = pickerGrid.dayButtons.first { $0.day == creationLast }!
        let normal = pickEnd.layer!.backgroundColor
        pickEnd.mouseEntered(with: entry)
        check(pickEnd.isHovering && pickEnd.layer!.backgroundColor != normal, "date hover has visible background")
        try snapshot(pickerGrid, "date-picker-hover")
        pickEnd.mouseExited(with: entry)
        check(pickEnd.layer!.backgroundColor == normal, "date hover restores original selection appearance")
        check(!controller.handleCalendarKey(key(124, window: pickerGrid.window!)), "picker keyboard does not navigate main month")
        func pickerMouse(_ type: NSEvent.EventType, grid: DateSelectionGrid, point: NSPoint) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: grid.convert(point, to: nil), modifierFlags: [], timestamp: 0, windowNumber: grid.window!.windowNumber, context: nil, eventNumber: 55, clickCount: 1, pressure: 1)!
        }
        func center(_ button: NSView) -> NSPoint { NSPoint(x: button.frame.midX, y: button.frame.midY) }
        pickEnd.mouseDown(with: pickerMouse(.leftMouseDown, grid: pickerGrid, point: center(pickEnd)))
        pickEnd.mouseDragged(with: pickerMouse(.leftMouseDragged, grid: pickerGrid, point: center(pickStart)))
        try snapshot(pickerGrid, "date-picker-range-preview")
        pickEnd.mouseUp(with: pickerMouse(.leftMouseUp, grid: pickerGrid, point: center(pickStart))); pump()
        check(draft.startDate == creationFirst && draft.endDate == creationLast && draft.dateSelector == nil, "reverse picker drag updates both endpoints and closes")
        ending.performClick(nil); pump()
        let endGrid = draft.dateSelector!.grid
        let disabled = endGrid.dayButtons.first { !$0.isEnabled }!
        let disabledColor = disabled.layer!.backgroundColor
        disabled.mouseEntered(with: entry)
        check(disabled.layer!.backgroundColor == disabledColor, "disabled past start dates do not acquire hover feedback")
        let firstButton = endGrid.dayButtons.first { $0.day == creationFirst }!
        let lastButton = endGrid.dayButtons.first { $0.day == creationFirst.adding(days: 2) }!
        firstButton.mouseDown(with: pickerMouse(.leftMouseDown, grid: endGrid, point: center(firstButton)))
        firstButton.mouseDragged(with: pickerMouse(.leftMouseDragged, grid: endGrid, point: center(lastButton)))
        firstButton.mouseUp(with: pickerMouse(.leftMouseUp, grid: endGrid, point: center(lastButton))); pump()
        check(draft.startDate == creationFirst && draft.endDate == creationFirst.adding(days: 2), "end-field picker drag creates same three-day range")
        starting.performClick(nil); pump()
        let invalidGrid = draft.dateSelector!.grid
        let invalidButton = invalidGrid.dayButtons.first { $0.day == creationFirst }!
        invalidButton.mouseDown(with: pickerMouse(.leftMouseDown, grid: invalidGrid, point: center(invalidButton)))
        invalidButton.mouseDragged(with: pickerMouse(.leftMouseDragged, grid: invalidGrid, point: NSPoint(x: -20, y: -20)))
        invalidButton.mouseUp(with: pickerMouse(.leftMouseUp, grid: invalidGrid, point: NSPoint(x: -20, y: -20)))
        check(draft.dateSelector != nil && draft.endDate == creationFirst.adding(days: 2), "invalid picker drop preserves dates and keeps selector")
        invalidGrid.cancelOperation(nil); pump()
        check(draft.dateSelector == nil && controller.editor === draft, "Escape cancels selector while preserving draft")
        draft.titleField.stringValue = "拖选四天改为三天"; draft.save(); pump()
        let createdByRange = store.events.first { $0.title == "拖选四天改为三天" }!
        check(createdByRange.duration == 2 && EventStore(directory: store.directory).events.contains { $0.id == createdByRange.id && $0.startDate == createdByRange.startDate && $0.endDate == createdByRange.endDate }, "drag-selected dates persist and reload")
        controller.edit(event: createdByRange, day: createdByRange.startDate); pump()
        let editingDraft = controller.editor!
        let editStart = allViews(editingDraft.window.contentView!).compactMap { $0 as? NSButton }.first { $0.accessibilityLabel()?.hasPrefix("开始日期") == true }!
        editStart.performClick(nil); pump()
        let editGrid = editingDraft.dateSelector!.grid
        let revised = creationFirst.adding(days: 7)
        editGrid.beginRange(revised)
        editGrid.finishRange(at: center(editGrid.dayButtons.first { $0.day == revised.adding(days: 2) }!)); pump()
        check(editingDraft.startDate == revised && editingDraft.endDate == revised.adding(days: 2), "existing event shares drag-range selector")
        editingDraft.save(); pump()
        check(store.events.first { $0.id == createdByRange.id }?.startDate == revised, "edited range keeps event identity")
        controller.calendar.layoutSubtreeIfNeeded()
        let bytesBefore = try Data(contentsOf: store.file)
        controller.calendar.beginCreationDrag(at: creationFirst); controller.calendar.finishCreationDrag(point: NSPoint(x: -1, y: -1))
        check(controller.editor == nil && !controller.calendar.isEventDragging, "invalid blank drag cancels creation")
        controller.calendar.beginCreationDrag(at: creationFirst)
        check(controller.handleCalendarKey(key(53)) && !controller.calendar.isEventDragging, "Escape cancels blank creation gesture")
        controller.calendar.finishCreationDrag(point: point(creationLast))
        check(try controller.editor == nil && Data(contentsOf: store.file) == bytesBefore, "cancelled creation never writes events")
        controller.calendar.beginCreationDrag(at: creationLast); controller.calendar.finishCreationDrag(point: point(creationFirst)); pump()
        check(controller.editor?.startDate == creationFirst && controller.editor?.endDate == creationLast, "reverse blank drag normalizes dates")
        controller.editor?.cancel(); pump()
        controller.showMonthPicker(anchor: controller.calendar.monthButton); pump()
        let monthPicker = controller.monthPicker!, hoverMonth = monthPicker.buttons.first { $0.title == "1月" }!
        let originalFill = hoverMonth.layer!.backgroundColor
        hoverMonth.mouseEntered(with: entry)
        check(hoverMonth.layer!.backgroundColor != originalFill, "month grid hover indicates target")
        monthPicker.yearField.mouseEntered(with: entry)
        check(monthPicker.yearField.backgroundColor != .white, "year input hover indicates editable target")
        try snapshot(monthPicker.popover.contentViewController!.view, "month-picker-hover")
        hoverMonth.mouseExited(with: entry); monthPicker.yearField.mouseExited(with: entry)
        check(hoverMonth.layer!.backgroundColor == originalFill, "month hover exit restores selection")
        controller.pinCalendar(); controller.outsideClicked(); pump()
        check(!controller.isOpen && controller.monthPicker == nil && !monthPicker.popover.isShown, "outside click closes pinned calendar and month picker together")
        controller.open()
        // Visual regression fixture with overlaps, past/ongoing spans, overflow and clipped edges.
        let visualStart = CivilDate(key: "2026-10-01")!
        for (name, from, through) in [("杭州出差", "2026-10-02", "2026-10-04"), ("出差南京", "2026-10-12", "2026-10-13"), ("跨周项目推进", "2026-10-17", "2026-10-23"), ("跨月上线准备", "2026-10-29", "2026-11-04"), ("月初延续事项", "2026-09-24", "2026-10-02")] {
            try store.save(title: name, startDate: CivilDate(key: from)!, endDate: CivilDate(key: through)!)
        }
        controller.calendar.todayProvider = { CivilDate(key: "2026-10-22")! }
        controller.calendar.jump(to: visualStart); controller.panel.setContentSize(NSSize(width: 980, height: 760))
        try snapshot(controller.calendar, "v1.1-overview")
        controller.open(); controller.close(); pump()
        check(!controller.isOpen && !controller.panel.isVisible && controller.trigger.isVisible, "close hides calendar and retains trigger")
        // Place windows away from the current pointer to exercise the real delayed close work item.
        controller.open()
        controller.trigger.setFrameOrigin(CGPoint(x: -10000, y: -10000)); controller.panel.setFrameOrigin(CGPoint(x: -12000, y: -12000))
        controller.scheduleClose(); pump(0.15); controller.enteredCalendar(); pump(0.45)
        check(controller.isOpen, "cross-window reentry cancels pending collapse")
        controller.scheduleClose(); pump(0.6)
        check(!controller.isOpen && !controller.panel.isVisible, "outside pointer collapses after delay")
        controller.open()
        let original = controller.trigger.frame
        controller.beginDrag(); controller.moveTrigger(to: CGPoint(x: original.minX - 100,y: original.minY - 50)); controller.endDrag()
        check(controller.trigger.frame.origin != original.origin, "drag handler updates origin")
        controller.close(); pump(); controller.trigger.orderOut(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard let window = app.modalWindow else { fatalError("missing quit alert") }
            button(window, "取消").performClick(nil)
        }
        check(!controller.confirmQuit(), "quit confirmation cancel retains application")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard let window = app.modalWindow else { fatalError("missing quit alert") }
            button(window, "退出").performClick(nil)
        }
        check(controller.confirmQuit(), "quit confirmation accepts explicit exit")
        print("PASS: \(count) native assertions. Controller/view-handler tests, not physical mouse or monitor tests.")
    }
}
