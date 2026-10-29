import AppKit

@main struct WeekViewTests {
    static func main() throws {
        let app = NSApplication.shared; app.setActivationPolicy(.accessory)
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = EventStore(directory: root.appendingPathComponent("data-" + UUID().uuidString))
        let suite = "app.litecal.week-tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let controller = FloatingController(store: store, defaults: defaults), calendar = controller.calendar
        func date(_ key: String) -> CivilDate { CivilDate(key: key)! }
        let today = date("2026-10-29")
        calendar.todayProvider = { today }
        var count = 0
        func check(_ passed: Bool, _ name: String) { count += 1; precondition(passed, "FAIL: " + name); print("PASS " + name) }
        func pump(_ seconds: Double = 0.32) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }
        func views(_ v: NSView) -> [NSView] { [v] + v.subviews.flatMap(views) }
        func button(_ window: NSWindow, _ title: String) -> NSButton { views(window.contentView!).compactMap { $0 as? NSButton }.first { $0.title == title }! }
        func snapshot(_ name: String) throws {
            calendar.layoutSubtreeIfNeeded(); calendar.displayIfNeeded()
            let bitmap = calendar.bitmapImageRepForCachingDisplay(in: calendar.bounds)!
            calendar.cacheDisplay(in: calendar.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent(name + ".png"))
        }
        let fixtures = [("跨周项目", "2026-10-23", "2026-11-04"), ("杭州出差", "2026-10-28", "2026-10-30"), ("已完成复盘", "2026-10-26", "2026-10-27"), ("方案评审", "2026-10-29", "2026-10-29"), ("月度总结", "2026-10-30", "2026-10-30")]
        for (title, start, end) in fixtures { try store.save(title: title, startDate: date(start), endDate: date(end)) }
        try store.save(title: "每日整理", startDate: date("2026-10-01"), endDate: date("2026-10-01"), recurrence: .daily)
        let original = store.events
        let originalBytes = try Data(contentsOf: store.directory.appendingPathComponent("events.json"))
        controller.open()
        check(!controller.isPinned, "hover opening remains unpinned")
        calendar.modeControl.buttons[0].performClick(nil)
        check(controller.isPinned, "accessible mode activation retains existing click-to-pin behavior")
        calendar.jump(to: today); pump()
        check(calendar.displayMode == .month, "fresh preferences default to month")
        let monthFrame = controller.panel.frame, triggerFrame = controller.trigger.frame
        try snapshot("month")
        let sharedCell = calendar.cells.first { $0.day == today }!
        let sharedBar = calendar.bars.first { $0.event.title == "跨周项目" && $0.segment.week == 4 }!
        calendar.setDisplayMode(.week)
        check(calendar.isTransitioning || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, "native transition begins")
        var frameSamples: [[String: Double]] = []
        for _ in 0..<30 {
            pump(0.01)
            let frame = controller.panel.frame
            frameSamples.append(["height": frame.height, "top": frame.maxY, "width": frame.width, "alpha": controller.panel.alphaValue,
                                 "selectionX": calendar.modeControl.selectionView.layer?.presentation()?.frame.minX ?? calendar.modeControl.selectionView.frame.minX,
                                 "targetDateY": sharedCell.layer?.presentation()?.frame.minY ?? sharedCell.frame.minY])
        }
        try JSONSerialization.data(withJSONObject: frameSamples, options: [.prettyPrinted, .sortedKeys]).write(to: root.appendingPathComponent("animation-frame-samples.json"))
        check(frameSamples.allSatisfy { abs($0["top"]! - monthFrame.maxY) <= 1 }, "window top stable throughout animation")
        check(frameSamples.allSatisfy { abs($0["width"]! - monthFrame.width) <= 1 && $0["alpha"]! == 1 }, "window stays opaque and same width throughout animation")
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            check(Set(frameSamples.map { Int($0["height"]!) }).count > 2, "window height passes through intermediate animation frames")
            check(Set(frameSamples.map { Int($0["selectionX"]!) }).count > 2, "selection background slides through intermediate frames")
            check(Set(frameSamples.map { Int($0["targetDateY"]!) }).count > 2, "reused target date moves through intermediate frames")
        }
        check(calendar.displayMode == .week && calendar.cells.count == 7, "week renders exactly seven dates")
        check(calendar.cells.first!.day == date("2026-10-26") && calendar.cells.last!.day == date("2026-11-01"), "Monday through Sunday including month boundary")
        check(calendar.cells.first { $0.day == today } === sharedCell, "target date view reused across switch")
        check(calendar.bars.first { $0.event.title == "跨周项目" } === sharedBar, "weekly spanning bar reused across switch")
        check(calendar.monthButton.title == "10月26日–11月1日", "week range title")
        check(controller.panel.frame.maxY == monthFrame.maxY && controller.panel.frame.width == monthFrame.width, "window top and width stable")
        check(controller.trigger.frame == triggerFrame, "view switch preserves floating trigger")
        check(controller.panel.frame.height >= 220 && controller.panel.frame.height < monthFrame.height, "week height compact and adaptive")
        func verifyLayout() {
            calendar.layoutSubtreeIfNeeded()
            let days = calendar.cells.map(\.day)
            check(Set(days).count == days.count, "unique visible dates")
            let expected = MonthEventLayout.calculate(days: days, events: store.occurrences(from: days.first!, through: days.last!), visibleLanes: calendar.visibleLaneCount)
            check(calendar.eventLayout.segments == expected.segments, "final segments exactly match target date range")
            check(calendar.bars.count == expected.segments.filter { $0.lane < calendar.visibleLaneCount }.count, "no lost or duplicate visible bars")
            check(calendar.subviews.compactMap { $0 as? EventBarView }.count == calendar.bars.count, "retired bars removed after animation")
            check(calendar.subviews.compactMap { $0 as? DayView }.count == days.count, "retired dates removed after animation")
            let col = calendar.bounds.width / 7
            for bar in calendar.bars {
                let s = bar.segment, first = days[s.week * 7], last = days[s.week * 7 + 6]
                check(s.firstColumn == max(0, first.days(until: bar.event.startDate)) && s.lastColumn == min(6, first.days(until: bar.event.endDate)), "bar precisely clipped to current week")
                check(s.continuesBefore == (bar.event.startDate < first) && s.continuesAfter == (bar.event.endDate > last), "continuation flags match original endpoints")
                check(calendar.bounds.contains(bar.frame), "bar within calendar bounds")
                check(abs(bar.frame.minX - (CGFloat(s.firstColumn) * col + 8)) < 0.01 && abs(bar.frame.maxX - (CGFloat(s.lastColumn + 1) * col - 8)) < 0.01, "bar aligns exactly to date columns")
            }
        }
        verifyLayout(); try snapshot("week")
        check(calendar.bars.first { $0.event.title == "已完成复盘" }!.past, "past spans muted")
        check(!calendar.bars.first { $0.event.title == "跨周项目" }!.past, "ongoing spans normal")
        check(calendar.cells.allSatisfy { $0.subviews.compactMap { $0 as? NSTextField }.contains { !$0.stringValue.isEmpty } }, "date and lunar labels retained")
        button(controller.panel, "下一周").performClick(nil)
        check(calendar.week == date("2026-11-02"), "next week advances seven days")
        verifyLayout()
        button(controller.panel, "上一周").performClick(nil)
        check(calendar.week == date("2026-10-26"), "previous week subtracts seven days")
        calendar.jump(to: date("2026-12-31"))
        check(calendar.monthButton.title == "2026年12月28日–2027年1月3日", "cross-year range includes both years")
        verifyLayout(); try snapshot("week-cross-year")
        button(controller.panel, "今天").performClick(nil)
        check(calendar.week == today.weekStart, "today returns to current week")
        calendar.selectDay(date("2026-11-01")); calendar.setDisplayMode(.month); pump()
        check(calendar.month == date("2026-11-01"), "week to month follows selected Sunday")
        check(controller.panel.frame == monthFrame, "restores original month frame")
        verifyLayout()
        calendar.setDisplayMode(.week); pump()
        check(calendar.week == date("2026-10-26"), "selected date bridges month to week")
        calendar.setDisplayMode(.month); pump(); calendar.jump(to: date("2027-02-01"))
        calendar.setDisplayMode(.week); pump()
        check(calendar.week == date("2027-02-01"), "unselected other month opens week containing first day")
        check(controller.panel.frame.height == 220, "empty week minimum height")
        try snapshot("week-empty")
        calendar.jump(to: today)
        for _ in 0..<4 { calendar.setDisplayMode(.month); calendar.setDisplayMode(.week); pump(0.6) }
        check(calendar.displayMode == .week && !calendar.isTransitioning, "rapid switch queues final selection")
        verifyLayout()
        check(store.events == original && (try! Data(contentsOf: store.directory.appendingPathComponent("events.json"))) == originalBytes, "switch and navigation preserve all data bytes")
        controller.close(); pump(); controller.open(); controller.pinCalendar(); pump()
        check(calendar.displayMode == .week && controller.panel.frame.maxY == monthFrame.maxY, "reopen restores week and stable top")
        let restored = FloatingController(store: EventStore(directory: store.directory), defaults: UserDefaults(suiteName: suite)!)
        restored.open(); restored.pinCalendar(); pump()
        check(restored.calendar.displayMode == .week && restored.calendar.cells.count == 7, "new controller restores persisted week preference")
        restored.close(); restored.trigger.orderOut(nil); pump()
        // Large weeks grow to ten lanes, then retain the shared +N list.
        for n in 1...15 { try store.save(title: "拥挤事项 \(n)", date: today) }
        pump(); verifyLayout()
        check(controller.panel.frame.height > 300 && controller.panel.frame.height <= controller.availableCalendarHeight, "crowded week grows within screen")
        check((calendar.eventLayout.hiddenIDs[today]?.count ?? 0) > 0, "crowded week keeps overflow access")
        try snapshot("week-crowded")
        let countBefore = store.events.count
        let dayCell = calendar.cells.first { $0.day == today }!
        let double = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: controller.panel.windowNumber, context: nil, eventNumber: 1, clickCount: 2, pressure: 1)!
        dayCell.mouseDown(with: double); pump()
        check(controller.editor != nil, "week blank double click opens shared editor")
        controller.editor!.titleField.stringValue = "周视图新增验证"; controller.editor!.save(); pump()
        check(store.events.count == countBefore + 1, "week editor saves once")
        let item = store.events.first { $0.title == "杭州出差" }!
        let editBar = calendar.bars.first { $0.event.id == item.id }!
        _ = editBar.accessibilityPerformPress(); pump()
        check(controller.editor?.startDate == item.startDate && controller.editor?.endDate == item.endDate, "week bar opens original span endpoints")
        controller.editor!.titleField.stringValue = "杭州出差已编辑"; controller.editor!.save(); pump()
        let dragBar = calendar.bars.first { $0.event.id == item.id }!
        let start = NSPoint(x: dragBar.frame.minX + 10, y: dragBar.frame.midY)
        let end = NSPoint(x: start.x + calendar.bounds.width / 7, y: start.y)
        calendar.startEventDrag(dragBar, point: start); calendar.updateEventDrag(point: end)
        check(calendar.isEventDragging, "week uses shared drag lifecycle")
        check(calendar.finishEventDrag(point: end), "week drag persists")
        let moved = store.events.first { $0.id == item.id }!
        check(moved.startDate == item.startDate.adding(days: 1) && moved.endDate == item.endDate.adding(days: 1), "drag translates both endpoints equally")
        controller.confirmDelete(moved); pump()
        button(controller.panel.attachedSheet!, "取消").performClick(nil); pump()
        check(store.events.contains { $0.id == item.id }, "week deletion cancel preserves item")
        controller.confirmDelete(moved); pump()
        button(controller.panel.attachedSheet!, "删除").performClick(nil); pump()
        check(!store.events.contains { $0.id == item.id }, "week confirmed deletion uses shared store")
        verifyLayout()
        calendar.setDisplayMode(.month); pump(); verifyLayout()
        check(calendar.visibleLaneCount == 3, "month retains three visible lanes")
        controller.close(); controller.trigger.orderOut(nil); pump()
        print("PASS: \(count) week-view assertions. Isolated native handler/layout tests.")
    }
}
