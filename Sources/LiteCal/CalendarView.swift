import AppKit

enum Theme {
    static let purple = BrandArtwork.purple
    static let ink = NSColor(srgbRed: 0.12, green: 0.13, blue: 0.18, alpha: 1)
    static let muted = NSColor(srgbRed: 0.52, green: 0.52, blue: 0.58, alpha: 1)
    static let line = NSColor(srgbRed: 0.90, green: 0.90, blue: 0.92, alpha: 1)
    static let weekdayFill = NSColor(srgbRed: 240/255, green: 239/255, blue: 242/255, alpha: 1)
    static let weekendFill = NSColor.white
    static let weekendInk = NSColor(srgbRed: 80/255, green: 56/255, blue: 75/255, alpha: 1)
    static let weekendDivider = NSColor(srgbRed: 195/255, green: 169/255, blue: 188/255, alpha: 1)
    static func label(_ title: String, size: CGFloat = 14, weight: NSFont.Weight = .regular, color: NSColor = ink) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: size, weight: weight); label.textColor = color
        label.lineBreakMode = .byTruncatingTail; label.maximumNumberOfLines = 1
        return label
    }
    static func symbol(_ name: String, size: CGFloat) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: size, weight: .medium))
    }
}
class ActionButton: NSButton {
    var restingBackground: NSColor? { didSet { refreshBackground() } }
    var hoverBackground: NSColor? { didSet { wantsLayer = true; updateTrackingAreas(); refreshBackground() } }
    private(set) var isHovering = false
    private var hoverTracking: NSTrackingArea?
    func refreshBackground() {
        guard hoverBackground != nil || restingBackground != nil else { return }
        layer?.backgroundColor = ((isHovering && isEnabled ? hoverBackground : restingBackground) ?? .clear).cgColor
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking { removeTrackingArea(hoverTracking) }; hoverTracking = nil
        guard hoverBackground != nil else { return }
        let area = NSTrackingArea(rect: .zero, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited], owner: self)
        hoverTracking = area; addTrackingArea(area)
    }
    override func mouseEntered(with event: NSEvent) { isHovering = true; refreshBackground() }
    override func mouseExited(with event: NSEvent) { isHovering = false; refreshBackground() }
    var actionHandler: (() -> Void)?
    init(title: String = "", symbol: String? = nil, action: @escaping () -> Void) {
        super.init(frame: .zero)
        self.title = title; self.actionHandler = action; target = self; self.action = #selector(invoke)
        isBordered = false; bezelStyle = .regularSquare; font = .systemFont(ofSize: 16)
        contentTintColor = Theme.ink
        if let symbol { image = Theme.symbol(symbol, size: 18); imagePosition = .imageOnly }
        setAccessibilityLabel(title)
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func invoke() { actionHandler?() }
}

extension Theme {
    static func eventFill(past: Bool) -> NSColor { past ? NSColor(srgbRed: 0.96, green: 0.94, blue: 0.96, alpha: 1) : NSColor(srgbRed: 0.90, green: 0.83, blue: 0.93, alpha: 1) }
    static func eventInk(past: Bool) -> NSColor { past ? NSColor(srgbRed: 0.57, green: 0.51, blue: 0.59, alpha: 1) : NSColor(srgbRed: 0.29, green: 0.16, blue: 0.34, alpha: 1) }
}
enum CalendarDisplayMode: String { case month, week }
private final class FlippedWeekDocument: NSView { override var isFlipped: Bool { true } }

private final class ModeSegmentButton: ActionButton {
    var onTrack: ((NSPoint) -> Void)?
    var onRelease: ((NSPoint, Bool) -> Void)?
    override func mouseDown(with event: NSEvent) {
        guard isEnabled, let parent = superview else { return }
        let origin = parent.convert(event.locationInWindow, from: nil)
        var dragged = false
        while let next = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            let point = parent.convert(next.locationInWindow, from: nil)
            if next.type == .leftMouseDragged {
                if hypot(point.x - origin.x, point.y - origin.y) > 3 { dragged = true }
                if dragged { onTrack?(point) }
            } else {
                onRelease?(point, dragged)
                break
            }
        }
    }
}

/// A frosted selection that follows the pointer and settles on release.
final class CalendarModeControl: NSView {
    private let selection = NSView()
    private let glass = NSVisualEffectView()
    private let tint = NSView()
    private(set) var buttons: [ActionButton] = []
    private(set) var mode: CalendarDisplayMode = .month
    private var trackingDrag = false
    private var selectionAnimating = false
    private var selectionToken = 0
    var onSelect: ((CalendarDisplayMode) -> Void)?
    override var isFlipped: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.7).cgColor
        layer?.cornerRadius = 16
        layer?.borderWidth = 0.75
        layer?.borderColor = Theme.line.withAlphaComponent(0.8).cgColor
        selection.wantsLayer = true; selection.layer?.cornerRadius = 14; selection.layer?.masksToBounds = true
        selection.layer?.borderWidth = 0.75
        selection.layer?.borderColor = NSColor.white.withAlphaComponent(0.8).cgColor
        glass.material = .popover; glass.blendingMode = .withinWindow; glass.state = .active
        glass.autoresizingMask = [.width, .height]; selection.addSubview(glass)
        tint.wantsLayer = true; tint.layer?.backgroundColor = NSColor(white: 0.78, alpha: 0.4).cgColor
        tint.autoresizingMask = [.width, .height]; selection.addSubview(tint)
        addSubview(selection)
        for (title, value) in [("月", CalendarDisplayMode.month), ("周", .week)] {
            let button = ModeSegmentButton(title: title) { [weak self] in self?.choose(value) }
            button.font = .systemFont(ofSize: 13, weight: .medium)
            button.onTrack = { [weak self] point in self?.preview(at: point) }
            button.onRelease = { [weak self] point, dragged in
                guard let self else { return }
                self.trackingDrag = false
                if dragged {
                    self.choose(point.x >= self.bounds.midX ? .week : .month)
                } else if self.bounds.contains(point) {
                    self.choose(value)
                } else {
                    self.settleSelection()
                }
            }
            button.setAccessibilityLabel(title + "视图"); buttons.append(button); addSubview(button)
        }
    }
    required init?(coder: NSCoder) { fatalError() }
    private func choose(_ value: CalendarDisplayMode) {
        if value == mode { settleSelection(); return }
        settleSelection(to: value) { [weak self] in self?.onSelect?(value) }
    }
    private func preview(at point: NSPoint) {
        trackingDrag = true
        selection.layer?.removeAllAnimations()
        let width = (bounds.width - 4) / 2
        selection.frame.origin.x = min(2 + width, max(2, point.x - width / 2))
    }
    private func settleSelection() {
        settleSelection(to: mode)
    }
    private func settleSelection(to value: CalendarDisplayMode, completion: (() -> Void)? = nil) {
        selectionToken += 1
        let token = selectionToken
        selectionAnimating = true
        let width = (bounds.width - 4) / 2
        let target = NSRect(x: 2 + (value == .week ? width : 0), y: 2, width: width, height: bounds.height - 4)
        guard window?.isVisible == true, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            selection.frame = target; selectionAnimating = false; completion?(); return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18; context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            selection.animator().frame = target
        }, completionHandler: { [weak self] in
            guard let self, self.selectionToken == token else { return }
            self.selectionAnimating = false
            completion?()
        })
    }
    func select(_ value: CalendarDisplayMode) {
        let changed = mode != value
        if changed { selectionToken += 1; selectionAnimating = false }
        mode = value
        needsLayout = true
        if changed && !trackingDrag {
            let width = (bounds.width - 4) / 2
            selection.frame = NSRect(x: 2 + (value == .week ? width : 0), y: 2, width: width, height: bounds.height - 4)
        }
    }
    override func layout() {
        super.layout()
        let width = (bounds.width - 4) / 2
        glass.frame = selection.bounds; tint.frame = selection.bounds
        if !trackingDrag && !selectionAnimating && mode == (selection.frame.midX >= bounds.midX ? .week : .month) {
            selection.frame = NSRect(x: 2 + (mode == .week ? width : 0), y: 2, width: width, height: bounds.height - 4)
        }
        for (index, button) in buttons.enumerated() {
            button.frame = NSRect(x: 2 + CGFloat(index) * width, y: 2, width: width, height: bounds.height - 4)
            let selected = (index == 0) == (mode == .month)
            button.contentTintColor = selected ? Theme.purple : Theme.muted
            button.font = .systemFont(ofSize: 13, weight: selected ? .semibold : .medium)
            button.setAccessibilityValue(selected ? "已选中" : "未选中")
        }
    }
    var selectionView: NSView { selection }
}

final class MonthView: NSView {
    let store: EventStore
    weak var controller: FloatingController?
    var month = CivilDate(Date()).monthStart
    var todayProvider: () -> CivilDate = { CivilDate(Date()) }
    private(set) var displayMode: CalendarDisplayMode = .month
    private var lastReloadMode: CalendarDisplayMode = .month
    private(set) var week = CivilDate(Date()).weekStart
    private(set) var selectedDay: CivilDate?
    let modeControl = CalendarModeControl(frame: .zero)
    private(set) var isTransitioning = false
    private var deferModeFrame = false
    private var pendingMode: CalendarDisplayMode?
    private var pendingReload = false
    private var pendingWeekCreation: CivilDate?
    private(set) var visibleLaneCount = 3
    static let weekWidth: CGFloat = 480
    private let weekScroll = NSScrollView()
    private let weekDocument = FlippedWeekDocument()
    private var weekHeights: [CGFloat] = Array(repeating: 64, count: 7)
    private var weekBars: [(Int, EventBarView)] = []
    var preferredWeekHeight: CGFloat {
        138 + weekHeights.reduce(0, +)
    }
    func selectDay(_ day: CivilDate) { selectedDay = day }
    func queueWeekCreation(_ day: CivilDate) {
        guard displayMode == .week, isTransitioning, cells.contains(where: { $0.day == day }) else { return }
        pendingWeekCreation = day
    }
    private var tracking: NSTrackingArea?
    private let titleLabel = Theme.label("LiteCal", size: 20, weight: .semibold)
    private(set) var monthButton: ActionButton!
    private let logo = NSImageView()
    private let monthLogo = BrandArtwork.glyph(size: 25)
    private var previous: ActionButton!, next: ActionButton!, today: ActionButton!, close: ActionButton!
    private var weekdays: [NSTextField] = []
    private(set) var cells: [DayView] = []
    private(set) var bars: [EventBarView] = []
    private var moreButtons: [(CivilDate, ActionButton)] = []
    private(set) var eventLayout = MonthEventLayout(segments: [], hiddenIDs: [:])
    private struct DragState { let event: CalendarEvent; let grabbedDay: CivilDate; let source: EventBarView; let offset: NSPoint; var target: CivilDate? }
    private var dragState: DragState?
    private var preview: NSImageView?
    private var creationStart: CivilDate?
    var isEventDragging: Bool { dragState != nil || creationStart != nil }
    func beginCreationDrag(at day: CivilDate) {
        guard !isEventDragging, controller?.allowsEventInteraction != false else { return }
        creationStart = day; controller?.setEventDragActive(true)
    }
    func updateCreationDrag(point: NSPoint) {
        guard let start = creationStart else { return }
        let target = day(at: point)
        for cell in cells { cell.isDropTarget = target.map { min(start, $0) <= cell.day && cell.day <= max(start, $0) } ?? false }
    }
    func finishCreationDrag(point: NSPoint) {
        guard let start = creationStart else { return }
        let target = day(at: point); cancelEventDrag()
        guard let target else { return }
        let first = min(start, target), last = max(start, target)
        selectDay(first)
        controller?.edit(event: nil, day: first, endDay: last, anchor: anchor(for: first))
    }
    override var isFlipped: Bool { true }
    init(store: EventStore) {
        self.store = store
        super.init(frame: NSRect(x: 0, y: 0, width: 980, height: 760))
        wantsLayer = true; layer?.cornerRadius = 20; layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.white.cgColor; layer?.borderWidth = 0.5; layer?.borderColor = Theme.line.cgColor
        logo.image = monthLogo; logo.wantsLayer = true; logo.layer?.backgroundColor = Theme.purple.cgColor; logo.layer?.cornerRadius = 8; logo.imageScaling = .scaleNone
        [logo, titleLabel].forEach(addSubview)
        monthButton = ActionButton { [weak self] in
            guard let self else { return }
            if self.displayMode == .month { self.controller?.showMonthPicker(anchor: self.monthButton) }
            else { self.controller?.showWeekPicker(anchor: self.monthButton) }
        }
        monthButton.hoverBackground = Theme.purple.withAlphaComponent(0.09); monthButton.layer?.cornerRadius = 6
        monthButton.toolTip = "点击选择年份和月份"
        previous = ActionButton(title: "上个月", symbol: "chevron.left") { [weak self] in self?.changeMonth(-1) }
        next = ActionButton(title: "下个月", symbol: "chevron.right") { [weak self] in self?.changeMonth(1) }
        today = ActionButton(title: "今天") { [weak self] in guard let self else { return }; self.jump(to: self.todayProvider()) }
        today.wantsLayer = true; today.layer?.cornerRadius = 15; today.layer?.borderWidth = 1; today.layer?.borderColor = Theme.line.cgColor
        close = ActionButton(title: "收起日历", symbol: "xmark") { [weak self] in self?.controller?.close() }
        [monthButton!, previous!, next!, today!, close!].forEach(addSubview)
        addSubview(modeControl)
        weekScroll.drawsBackground = false; weekScroll.hasVerticalScroller = true
        weekScroll.autohidesScrollers = true; weekScroll.contentView.drawsBackground = false
        weekScroll.wantsLayer = true; weekScroll.layer?.cornerRadius = 18
        weekScroll.layer?.masksToBounds = true; weekScroll.layer?.borderWidth = 0.5
        weekScroll.layer?.borderColor = Theme.line.cgColor
        weekDocument.frame = NSRect(x: 0, y: 0, width: Self.weekWidth - 24, height: 490)
        weekScroll.documentView = weekDocument; addSubview(weekScroll)
        weekScroll.isHidden = true
        modeControl.onSelect = { [weak self] in
            // Accessibility activation has no mouse-down event for the existing
            // click-to-pin monitor. It is still an explicit calendar interaction.
            self?.controller?.pinCalendar(); self?.setDisplayMode($0)
        }
        for (index, name) in ["一", "二", "三", "四", "五", "六", "日"].enumerated() {
            let label = Theme.label(name, size: 14, weight: index >= 5 ? .semibold : .regular, color: index >= 5 ? Theme.purple : Theme.muted); label.alignment = .center; weekdays.append(label); addSubview(label)
        }
        reload()
    }
    required init?(coder: NSCoder) { fatalError() }
    func jump(to value: CivilDate) {
        guard (2...9998).contains(value.year), !isEventDragging, !isTransitioning else { return }
        selectedDay = nil; month = value.monthStart; week = value.weekStart; reload()
    }
    func changeMonth(_ delta: Int) { jump(to: displayMode == .month ? month.adding(months: delta) : week.adding(days: delta * 7)) }
    func setDisplayMode(_ mode: CalendarDisplayMode, animated: Bool = true) {
        if isTransitioning { pendingMode = mode; return }
        guard mode != displayMode, !isEventDragging, controller?.allowsEventInteraction != false else { return }
        guard animated, window?.isVisible == true, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            window?.disableScreenUpdatesUntilFlush()
            applyDisplayMode(mode)
            return
        }
        guard let bitmap = bitmapImageRepForCachingDisplay(in: bounds) else {
            window?.disableScreenUpdatesUntilFlush()
            applyDisplayMode(mode)
            return
        }
        cacheDisplay(in: bounds, to: bitmap)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(bitmap)
        let snapshot = NSImageView(frame: bounds)
        snapshot.image = image
        snapshot.imageScaling = .scaleNone
        snapshot.imageAlignment = .alignCenter
        let oldFrame = window?.frame ?? .zero
        deferModeFrame = true
        applyDisplayMode(mode)
        deferModeFrame = false
        let target = controller?.calendarFrameForCurrentMode() ?? oldFrame
        arrange(size: target.size)
        let anchoredRight = abs(target.maxX - oldFrame.maxX) < abs(target.minX - oldFrame.minX)
        snapshot.autoresizingMask = anchoredRight ? [.minXMargin, .minYMargin, .maxYMargin] : [.maxXMargin, .minYMargin, .maxYMargin]
        addSubview(snapshot, positioned: .above, relativeTo: nil)
        isTransitioning = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window?.animator().setFrame(target, display: true)
            snapshot.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            snapshot.removeFromSuperview()
            self?.completeTransition()
        })
    }
    private func applyDisplayMode(_ mode: CalendarDisplayMode) {
        if mode == .week {
            let current = todayProvider()
            week = (selectedDay ?? (current.monthStart == month ? current : month)).weekStart
        } else { month = (selectedDay ?? week).monthStart }
        displayMode = mode; controller?.defaults.set(mode.rawValue, forKey: "calendarDisplayMode")
        reload()
    }
    private func completeTransition() {
        isTransitioning = false; needsLayout = true; layoutSubtreeIfNeeded()
        if pendingReload { pendingReload = false; reload() }
        if let mode = pendingMode { pendingMode = nil; setDisplayMode(mode) }
        if !isTransitioning, let day = pendingWeekCreation {
            pendingWeekCreation = nil
            if displayMode == .week, cells.contains(where: { $0.day == day }), controller?.allowsEventInteraction != false {
                selectDay(day)
                controller?.edit(event: nil, day: day, anchor: anchor(for: day))
            }
        }
        controller?.scheduleClose()
    }
    func restoreDisplayMode(_ mode: CalendarDisplayMode) {
        displayMode = mode; week = todayProvider().weekStart; reload()
    }
    func reload(animated: Bool = false) {
        if isTransitioning { pendingReload = true; return }
        let changingMode = lastReloadMode != displayMode
        lastReloadMode = displayMode
        cancelEventDrag()
        layoutSubtreeIfNeeded()
        let oldViews: [NSView] = cells + bars + moreButtons.map { $0.1 }
        let oldFrames = Dictionary(uniqueKeysWithValues: (oldViews + [monthButton, previous, next, modeControl.selectionView]).map { (ObjectIdentifier($0), $0.frame) })
        let oldCells = Dictionary(uniqueKeysWithValues: cells.map { ($0.day, $0) })
        let sourceWeekMidY = oldCells[week]?.frame.midY ?? 100
        let oldBars = Dictionary(uniqueKeysWithValues: bars.map { (barKey($0), $0) })
        let oldMore = Dictionary(uniqueKeysWithValues: moreButtons)
        let weekEnd = week.adding(days: 6)
        monthButton.title = displayMode == .month ? "\(month.year)年\(month.month)月" : (week.year != weekEnd.year
            ? "\(week.year)年\(week.month)月\(week.day)日–\(weekEnd.year)年\(weekEnd.month)月\(weekEnd.day)日"
            : week.month != weekEnd.month
                ? "\(week.year)年\(week.month)月\(week.day)日–\(weekEnd.month)月\(weekEnd.day)日"
                : "\(week.year)年\(week.month)月\(week.day)日–\(weekEnd.day)日")
        monthButton.setAccessibilityLabel("\(displayMode == .month ? "选择年月" : "选择周")，\(monthButton.title)")
        monthButton.toolTip = displayMode == .month ? "点击选择年份和月份" : "点击选择具体周"
        previous.title = displayMode == .month ? "上个月" : "上一周"; previous.setAccessibilityLabel(previous.title)
        next.title = displayMode == .month ? "下个月" : "下一周"; next.setAccessibilityLabel(next.title)
        previous.imagePosition = .imageOnly; next.imagePosition = .imageOnly
        let days = displayMode == .month ? month.monthDays : week.weekDays, current = todayProvider()
        cells = days.map { day in
            let cell = oldCells[day].flatMap { $0.today == current ? $0 : nil } ?? DayView(day: day, isCurrentMonth: day.month == month.month, today: current)
            cell.isCurrentMonth = displayMode == .week || day.month == month.month
            cell.monthView = self
            cell.onNew = { [weak self] in guard let self else { return }; self.controller?.edit(event: nil, day: day, anchor: self.anchor(for: day)) }
            let parent = displayMode == .week ? weekDocument : self
            if cell.superview !== parent { cell.removeFromSuperview(); parent.addSubview(cell) }; return cell
        }
        let occurrences = store.occurrences(from: days.first!, through: days.last!)
        visibleLaneCount = 3
        eventLayout = MonthEventLayout.calculate(days: days, events: occurrences, visibleLanes: visibleLaneCount)
        let byID = Dictionary(uniqueKeysWithValues: occurrences.map { ($0.occurrenceKey, $0) })
        weekBars = []
        if displayMode == .week {
            let eventWidth = max(100, (controller?.weekCalendarWidth ?? Self.weekWidth) - 205)
            weekHeights = days.map { day in
                let daily = occurrences.filter { $0.startDate <= day && day <= $0.endDate }
                let barHeights = daily.map { WeekEventBarView.height(for: $0.title, width: eventWidth) }
                return max(64, 20 + barHeights.reduce(0, +) + CGFloat(max(0, daily.count - 1)) * 6)
            }
            for (index, day) in days.enumerated() {
                for event in occurrences where event.startDate <= day && day <= event.endDate {
                    let segment = EventSegment(eventID: event.id, occurrenceKey: event.occurrenceKey, week: 0, firstColumn: index, lastColumn: index, lane: 0, continuesBefore: false, continuesAfter: false)
                    let key = event.occurrenceKey + ":" + day.description
                    let bar = oldBars[key].flatMap { $0 is WeekEventBarView && $0.event == event && $0.today == current ? $0 : nil } ?? WeekEventBarView(event: event, segment: segment, today: current)
                    bar.segment = segment; bar.monthView = self
                    if bar.superview !== weekDocument { bar.removeFromSuperview() }
                    weekDocument.addSubview(bar, positioned: .above, relativeTo: nil)
                    weekBars.append((index, bar))
                }
            }
            bars = weekBars.map(\.1)
        } else {
        bars = eventLayout.segments.filter { $0.lane < visibleLaneCount }.compactMap { segment in
            guard let event = byID[segment.occurrenceKey] else { return nil }
            let key = event.occurrenceKey + ":" + days[segment.week * 7].description
            let bar = oldBars[key].flatMap { !($0 is WeekEventBarView) && $0.event == event && $0.today == current ? $0 : nil } ?? EventBarView(event: event, segment: segment, today: current)
            bar.segment = segment; bar.monthView = self
            // Bars must stay above newly inserted date cells.
            addSubview(bar, positioned: .above, relativeTo: nil); return bar
        }
        }
        moreButtons = displayMode == .week ? [] : days.compactMap { day in
            let count = eventLayout.hiddenIDs[day]?.count ?? 0
            guard count > 0 else { return nil }
            let button = oldMore[day] ?? ActionButton(title: "+\(count)") { [weak self] in self?.controller?.showDay(day) }
            button.title = "+\(count)"
            button.contentTintColor = Theme.purple; button.alignment = .left
            button.setAccessibilityLabel("查看 \(day.description) 其余 \(count) 条事项")
            addSubview(button); return (day, button)
        }
        let active: [NSView] = cells + bars + moreButtons.map { $0.1 }
        let activeIDs = Set(active.map(ObjectIdentifier.init))
        let retired = oldViews.filter { !activeIDs.contains(ObjectIdentifier($0)) }
        modeControl.select(displayMode)
        let target = controller?.calendarFrameForCurrentMode() ?? NSRect(origin: .zero, size: NSSize(width: bounds.width, height: displayMode == .week ? preferredWeekHeight : 760))
        let animate = animated && window?.isVisible == true && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        weekScroll.isHidden = displayMode != .week
        if !animate {
            retired.forEach { $0.removeFromSuperview() }
            if !deferModeFrame && (displayMode == .week || animated || changingMode) { window?.setFrame(target, display: true) }
            needsLayout = true; layoutSubtreeIfNeeded(); needsDisplay = true; return
        }
        // Reuse surviving days and weekly event segments. Outgoing weeks collapse
        // around the target row; no snapshot or replacement window is involved.
        isTransitioning = true
        arrange(size: target.size); modeControl.layoutSubtreeIfNeeded()
        let moving = (changingMode ? [] : active) + [monthButton!, previous!, next!, modeControl.selectionView]
        let destinations = moving.map { ($0, $0.frame) }
        func collapsed(_ frame: NSRect, before: Bool) -> NSRect {
            NSRect(x: frame.minX, y: before ? 100 : target.height, width: frame.width, height: 0)
        }
        for view in moving {
            if let old = oldFrames[ObjectIdentifier(view)] { view.frame = old }
            else { view.frame = collapsed(view.frame, before: (view as? DayView).map { $0.day < week } ?? false); view.alphaValue = 0 }
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.23; context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.window?.animator().setFrame(target, display: true)
            for (view, frame) in destinations { view.animator().frame = frame; view.animator().alphaValue = 1 }
            for view in retired {
                view.animator().frame = collapsed(view.frame, before: (view as? DayView).map { $0.day < week } ?? (view.frame.midY < sourceWeekMidY))
                view.animator().alphaValue = 0
            }
        }, completionHandler: { [weak self] in
            guard let self else { return }
            retired.forEach { $0.removeFromSuperview() }
            self.completeTransition()
        })
        needsDisplay = true
    }
    private func barKey(_ bar: EventBarView) -> String {
        bar.event.occurrenceKey + ":" + (bar is WeekEventBarView ? cells[bar.segment.firstColumn].day.description : cells[bar.segment.week * 7].day.description)
    }
    override func layout() {
        super.layout()
        guard !isTransitioning, !deferModeFrame else { return }
        arrange(size: bounds.size)
    }
    private func arrange(size: NSSize) {
        let w = size.width, center = w * 0.51
        logo.frame = NSRect(x: 22, y: 14, width: 34, height: 34)
        titleLabel.frame = NSRect(x: 70, y: 19, width: 110, height: 26)
        titleLabel.font = .systemFont(ofSize: w < 800 ? 18 : 20, weight: .semibold)
        monthButton.frame = NSRect(x: center - 85, y: 17, width: 170, height: 30); monthButton.font = .systemFont(ofSize: w < 800 ? 18 : 20, weight: .semibold)
        previous.frame = NSRect(x: center - 119, y: 17, width: 30, height: 30); next.frame = NSRect(x: center + 89, y: 17, width: 30, height: 30)
        modeControl.frame = NSRect(x: w - 234, y: 17, width: 78, height: 30)
        today.frame = NSRect(x: w - 148, y: 17, width: 72, height: 30); today.font = .systemFont(ofSize: 14)
        close.frame = NSRect(x: w - 52, y: 17, width: 30, height: 30)
        if displayMode == .week {
            logo.image = monthLogo; logo.contentTintColor = nil
            logo.layer?.backgroundColor = Theme.purple.cgColor
            logo.frame = NSRect(x: 20, y: 17, width: 34, height: 34)
            titleLabel.frame = NSRect(x: 65, y: 21, width: 130, height: 27)
            titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
            modeControl.frame = NSRect(x: w - 196, y: 18, width: 100, height: 32)
            today.frame = NSRect(x: w - 84, y: 18, width: 68, height: 32)
            today.font = .systemFont(ofSize: 13, weight: .medium)
            previous.frame = NSRect(x: (w - 244) / 2 - 38, y: 71, width: 30, height: 30)
            monthButton.frame = NSRect(x: (w - 244) / 2, y: 69, width: 244, height: 34)
            next.frame = NSRect(x: (w + 244) / 2 + 8, y: 71, width: 30, height: 30)
            let weekEnd = week.adding(days: 6)
            monthButton.font = .systemFont(ofSize: week.year != weekEnd.year ? 12 : week.month != weekEnd.month ? 14 : 16, weight: .semibold)
            close.isHidden = true
            weekScroll.frame = NSRect(x: 12, y: 120, width: max(0, w - 24), height: max(0, size.height - 138))
            let tableWidth = max(0, w - 24)
            weekDocument.frame = NSRect(x: 0, y: 0, width: tableWidth, height: weekHeights.reduce(0, +))
            var y: CGFloat = 0
            for (index, cell) in cells.enumerated() {
                let rowHeight = weekHeights[index]
                cell.weekRow = true
                cell.frame = NSRect(x: 0, y: y, width: tableWidth, height: rowHeight)
                let daily = weekBars.filter { $0.0 == index }.map(\.1)
                cell.showsWeekEmpty = daily.isEmpty
                let barWidth = max(100, w - 205)
                let barHeights = daily.map { WeekEventBarView.height(for: $0.event.title, width: barWidth) }
                let contentHeight = barHeights.reduce(0, +) + CGFloat(max(0, daily.count - 1)) * 6
                var eventY = y + max(10, (rowHeight - contentHeight) / 2)
                for (bar, barHeight) in zip(daily, barHeights) {
                    bar.frame = NSRect(x: 169, y: eventY, width: barWidth, height: barHeight)
                    eventY += barHeight + 6
                }
                y += rowHeight
            }
            weekdays.forEach { $0.isHidden = true }
            return
        }
        logo.image = monthLogo; logo.contentTintColor = nil
        logo.layer?.backgroundColor = Theme.purple.cgColor
        close.isHidden = false
        let col = w / 7, height = (size.height - 100) / CGFloat(max(1, cells.count / 7))
        for (i, label) in weekdays.enumerated() {
            if label.superview !== self { label.removeFromSuperview(); addSubview(label) }
            label.isHidden = false
            label.stringValue = ["一", "二", "三", "四", "五", "六", "日"][i]
            label.alignment = .center
            label.frame = NSRect(x: CGFloat(i) * col, y: 72, width: col, height: 20)
        }
        for (i, cell) in cells.enumerated() { cell.weekRow = false; cell.showsWeekEmpty = false; cell.frame = NSRect(x: CGFloat(i % 7) * col, y: 100 + CGFloat(i / 7) * height, width: col, height: height) }
        let metrics = displayMode == .week ? (start: CGFloat(48), step: CGFloat(22)) : DayView.metrics(height: height)
        let monthRowHeight = ((controller?.availableCalendarHeight ?? 760) - 100) / CGFloat(month.monthDays.count / 7)
        let eventFontStep = displayMode == .week ? DayView.metrics(height: monthRowHeight).step : metrics.step
        for bar in bars {
            let s = bar.segment
            bar.fontSize = eventFontStep >= 19 ? 13 : 12
            bar.frame = NSRect(x: CGFloat(s.firstColumn) * col + 8, y: 100 + CGFloat(s.week) * height + metrics.start + CGFloat(s.lane) * metrics.step,
                width: CGFloat(s.lastColumn - s.firstColumn + 1) * col - 16, height: metrics.step - 2)
        }
        for (day, button) in moreButtons {
            guard let i = cells.firstIndex(where: { $0.day == day }) else { continue }
            button.font = .systemFont(ofSize: metrics.step >= 19 ? 12 : 11, weight: .medium)
            button.frame = NSRect(x: CGFloat(i % 7) * col + 10, y: 100 + CGFloat(i / 7) * height + metrics.start + CGFloat(visibleLaneCount) * metrics.step, width: col - 20, height: metrics.step)
        }
    }
    func anchor(for day: CivilDate) -> NSRect {
        guard let cell = cells.first(where: { $0.day == day }) else { return NSRect(x: bounds.midX, y: bounds.midY, width: 1, height: 1) }
        return convert(cell.bounds, from: cell)
    }
    func day(at point: NSPoint) -> CivilDate? {
        if displayMode == .week {
            guard weekScroll.frame.contains(point) else { return nil }
            let documentPoint = weekDocument.convert(point, from: self)
            var y: CGFloat = 0
            for (index, height) in weekHeights.enumerated() {
                if documentPoint.y >= y && documentPoint.y < y + height { return cells[index].day }
                y += height
            }
            return nil
        }
        guard point.x >= 0, point.x < bounds.width, point.y >= 100, point.y < bounds.height, !cells.isEmpty else { return nil }
        let col = min(6, Int(point.x / (bounds.width / 7)))
        let row = Int((point.y - 100) / ((bounds.height - 100) / CGFloat(cells.count / 7)))
        let i = row * 7 + col
        return cells.indices.contains(i) ? cells[i].day : nil
    }
    func edit(_ bar: EventBarView) {
        selectDay(displayMode == .week ? cells[bar.segment.firstColumn].day : max(bar.event.startDate, cells[bar.segment.week * 7].day))
        controller?.edit(event: bar.event, day: bar.event.startDate, anchor: convert(bar.bounds, from: bar))
    }
    func startEventDrag(_ bar: EventBarView, point: NSPoint) {
        guard !isEventDragging, let grabbed = day(at: point), controller?.allowsEventInteraction != false else { return }
        controller?.setEventDragActive(true)
        let barFrame = convert(bar.bounds, from: bar)
        dragState = DragState(event: bar.event, grabbedDay: grabbed, source: bar, offset: NSPoint(x: point.x - barFrame.minX, y: point.y - barFrame.minY), target: grabbed)
        if let bitmap = bar.bitmapImageRepForCachingDisplay(in: bar.bounds) {
            bar.cacheDisplay(in: bar.bounds, to: bitmap)
            let image = NSImage(size: bar.bounds.size); image.addRepresentation(bitmap)
            let ghost = NSImageView(frame: barFrame); ghost.image = image; ghost.alphaValue = 0.65; ghost.imageScaling = .scaleAxesIndependently; preview = ghost; addSubview(ghost)
        }
        for view in bars where view.event.id == bar.event.id { view.alphaValue = 0.35 }
        updateEventDrag(point: point)
    }
    func updateEventDrag(point: NSPoint) {
        guard var drag = dragState else { return }
        drag.target = day(at: point); dragState = drag
        preview?.setFrameOrigin(NSPoint(x: point.x - drag.offset.x, y: point.y - drag.offset.y))
        for cell in cells {
            if let target = drag.target {
                let shift = drag.grabbedDay.days(until: target)
                cell.isDropTarget = drag.event.startDate.adding(days: shift) <= cell.day && cell.day <= drag.event.endDate.adding(days: shift)
            } else { cell.isDropTarget = false }
        }
    }
    @discardableResult func finishEventDrag(point: NSPoint) -> Bool {
        guard let drag = dragState else { return false }
        let target = day(at: point)
        cancelEventDrag()
        guard let target else { return false }
        do { try store.move(id: drag.event.id, by: drag.grabbedDay.days(until: target)); selectDay(target); return true }
        catch { controller?.showError(error); return false }
    }
    func cancelEventDrag() {
        guard isEventDragging else { return }
        creationStart = nil; dragState = nil; preview?.removeFromSuperview(); preview = nil
        for bar in bars { bar.alphaValue = 1 }
        for cell in cells { cell.isDropTarget = false }
        controller?.setEventDragActive(false)
    }
    override func draw(_ dirtyRect: NSRect) {
        if displayMode == .week {
            return
        }
        let weekendX = bounds.width / 7 * 5
        Theme.weekdayFill.setFill(); NSRect(x: 0, y: 64, width: weekendX, height: 36).fill()
        Theme.weekendFill.setFill(); NSRect(x: weekendX, y: 64, width: bounds.width - weekendX, height: 36).fill()
        Theme.line.setStroke(); let line = NSBezierPath(); line.lineWidth = 0.5
        for y: CGFloat in [64, 100] { line.move(to: NSPoint(x: 0, y: y)); line.line(to: NSPoint(x: bounds.width, y: y)) }; line.stroke()
        Theme.weekendDivider.setFill(); NSRect(x: weekendX, y: 64, width: 2, height: 36).fill()
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas(); if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect], owner: self); addTrackingArea(tracking!)
    }
    override func mouseEntered(with event: NSEvent) { controller?.enteredCalendar() }
    override func mouseExited(with event: NSEvent) { controller?.scheduleClose() }
}
final class DayView: NSView {
    let day: CivilDate, today: CivilDate
    private var weekday: Int { CivilDate.calendar.component(.weekday, from: day.date) }
    private var isWeekend: Bool { weekday == 7 || weekday == 1 }
    var isCurrentMonth: Bool { didSet {
        dateLabel.textColor = day == today ? .white : (!isCurrentMonth ? Theme.muted : (isWeekend ? Theme.weekendInk : (day < today ? NSColor(srgbRed: 0.45, green: 0.43, blue: 0.48, alpha: 1) : Theme.ink)))
        needsLayout = true; needsDisplay = true
    } }
    var onNew: (() -> Void)?
    var weekRow = false { didSet { needsLayout = true; needsDisplay = true } }
    var showsWeekEmpty = false { didSet { needsDisplay = true } }
    var isDropTarget = false { didSet { needsDisplay = true } }
    private let dateLabel: NSTextField, lunarLabel: NSTextField
    override var isFlipped: Bool { true }
    static func metrics(height: CGFloat) -> (start: CGFloat, step: CGFloat) {
        let start: CGFloat = height < 102 ? 26 : (height < 126 ? 34 : 48)
        return (start, min(22, max(14, floor((height - start - 4) / 4))))
    }
    init(day: CivilDate, isCurrentMonth: Bool, today: CivilDate) {
        self.day = day; self.today = today; self.isCurrentMonth = isCurrentMonth
        let past = day < today
        let annotation = CalendarAnnotation.name(for: day)
        dateLabel = Theme.label(String(day.day), size: 19, weight: .medium, color: !isCurrentMonth ? Theme.muted : (past ? NSColor(srgbRed: 0.45, green: 0.43, blue: 0.48, alpha: 1) : Theme.ink))
        lunarLabel = Theme.label(annotation ?? LunarCalendar.label(for: day), size: 12, color: annotation == nil ? Theme.muted : Theme.purple)
        super.init(frame: .zero); addSubview(dateLabel); addSubview(lunarLabel)
        if day == today { dateLabel.textColor = .white }
        else if isCurrentMonth && isWeekend { dateLabel.textColor = Theme.weekendInk }
        toolTip = "\(day.description) · 双击空白处新增事项"
        setAccessibilityElement(true); setAccessibilityRole(.group); setAccessibilityLabel(day.description)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() {
        super.layout()
        if weekRow {
            let groupTop = (bounds.height - 50) / 2
            dateLabel.font = .systemFont(ofSize: 20, weight: .medium)
            dateLabel.textColor = day == today ? .white : (isWeekend ? Theme.weekendInk : day < today ? NSColor(srgbRed: 0.45, green: 0.43, blue: 0.48, alpha: 1) : Theme.ink)
            dateLabel.alignment = .center
            dateLabel.frame = NSRect(x: 82, y: groupTop + 1, width: 52, height: 30)
            lunarLabel.font = .systemFont(ofSize: 12)
            lunarLabel.textColor = Theme.muted
            lunarLabel.alignment = .center
            lunarLabel.frame = NSRect(x: 67, y: groupTop + 33, width: 82, height: 17)
            return
        }
        lunarLabel.textColor = CalendarAnnotation.name(for: day) == nil ? Theme.muted : Theme.purple
        let compact = bounds.height < 126, small = bounds.height < 102, current = day == today
        dateLabel.font = .systemFont(ofSize: small ? 17 : 19, weight: isWeekend && isCurrentMonth && !current ? .semibold : .medium)
        dateLabel.alignment = current ? .center : .left; if current { dateLabel.textColor = .white }
        dateLabel.frame = NSRect(x: current && small ? 9 : 12, y: small ? 2 : 6, width: 32, height: small ? 22 : 24)
        lunarLabel.frame = NSRect(x: current || compact ? 48 : 13, y: current || compact ? (small ? 7 : 12) : 29, width: bounds.width - (current || compact ? 53 : 22), height: 17)
    }
    override func draw(_ dirtyRect: NSRect) {
        if weekRow {
            (day == today ? Theme.purple.withAlphaComponent(0.045) : isWeekend ? Theme.weekendFill : Theme.weekdayFill).setFill(); bounds.fill()
            Theme.line.setStroke(); let line = NSBezierPath(); line.lineWidth = 0.5
            for x: CGFloat in [64, 152] { line.move(to: NSPoint(x: x, y: 0)); line.line(to: NSPoint(x: x, y: bounds.maxY)) }
            line.move(to: NSPoint(x: 0, y: bounds.maxY - 0.5)); line.line(to: NSPoint(x: bounds.maxX, y: bounds.maxY - 0.5)); line.stroke()
            let weekdayName = ["日", "一", "二", "三", "四", "五", "六"][weekday - 1]
            let weekdayText = "周" + weekdayName
            let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
            (weekdayText as NSString).draw(in: NSRect(x: 0, y: (bounds.height - 22) / 2, width: 64, height: 22), withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: isWeekend ? .semibold : .medium), .foregroundColor: isWeekend ? Theme.purple : Theme.muted, .paragraphStyle: paragraph])
            if showsWeekEmpty {
                ("无安排" as NSString).draw(in: NSRect(x: 169, y: (bounds.height - 20) / 2, width: 100, height: 20), withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: Theme.muted])
            }
            if day == today { Theme.purple.setFill(); NSBezierPath(ovalIn: NSRect(x: 92, y: (bounds.height - 50) / 2, width: 32, height: 32)).fill() }
            if isDropTarget { Theme.purple.withAlphaComponent(0.09).setFill(); bounds.fill(); Theme.purple.withAlphaComponent(0.65).setStroke(); let p = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1)); p.lineWidth = 2; p.stroke() }
            return
        }
        (day == today ? Theme.purple.withAlphaComponent(0.045) : (isWeekend ? Theme.weekendFill : (isCurrentMonth ? Theme.weekdayFill : NSColor(srgbRed: 233/255, green: 232/255, blue: 236/255, alpha: 1)))).setFill(); bounds.fill()
        Theme.line.setStroke(); let grid = NSBezierPath(); grid.lineWidth = 0.5; grid.move(to: NSPoint(x: bounds.maxX, y: 0)); grid.line(to: NSPoint(x: bounds.maxX, y: bounds.maxY)); grid.line(to: NSPoint(x: 0, y: bounds.maxY)); grid.stroke()
        if weekday == 7 { Theme.weekendDivider.setFill(); NSRect(x: 0, y: 0, width: 2, height: bounds.height).fill() }
        if day == today { let d: CGFloat = bounds.height < 102 ? 24 : 30; Theme.purple.setFill(); NSBezierPath(ovalIn: NSRect(x: 12, y: 2, width: d, height: d)).fill() }
        if isDropTarget { Theme.purple.withAlphaComponent(0.09).setFill(); bounds.fill(); Theme.purple.withAlphaComponent(0.65).setStroke(); let p = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1)); p.lineWidth = 2; p.stroke() }
    }
    weak var monthView: MonthView?
    private var pressPoint: NSPoint?
    private var creating = false
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2, monthView?.isTransitioning == true {
            monthView?.queueWeekCreation(day)
            return
        }
        guard monthView?.controller?.allowsEventInteraction != false else { return }
        monthView?.selectDay(day)
        creating = false; pressPoint = nil
        if event.clickCount == 2 { onNew?() }
        else { pressPoint = monthView?.convert(event.locationInWindow, from: nil) }
    }
    override func mouseDragged(with event: NSEvent) {
        guard let monthView, let pressPoint else { return }
        let point = monthView.convert(event.locationInWindow, from: nil)
        if !creating && hypot(point.x - pressPoint.x, point.y - pressPoint.y) >= 4 {
            creating = true; monthView.beginCreationDrag(at: day)
        }
        if creating { monthView.updateCreationDrag(point: point) }
    }
    override func mouseUp(with event: NSEvent) {
        defer { pressPoint = nil; creating = false }
        guard creating, let monthView else { return }
        monthView.finishCreationDrag(point: monthView.convert(event.locationInWindow, from: nil))
    }
    override func hitTest(_ point: NSPoint) -> NSView? { let hit = super.hitTest(point); return hit === dateLabel || hit === lunarLabel ? self : hit }
}

class EventBarView: NSView {
    let event: CalendarEvent
    var segment: EventSegment { didSet { needsDisplay = true } }
    let today: CivilDate
    weak var monthView: MonthView?
    var fontSize: CGFloat = 13 { didSet { needsDisplay = true } }
    private var pressPoint: NSPoint?
    private var dragging = false
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    var past: Bool { event.isPast(today: today) }
    init(event: CalendarEvent, segment: EventSegment, today: CivilDate) {
        self.event = event; self.segment = segment; self.today = today
        super.init(frame: .zero)
        toolTip = "\(event.title)\n\(event.startDate) — \(event.endDate)" + (event.recurrence == .none ? "" : "\n\(event.recurrence.title)重复 · 拖动会移动整组日程")
        setAccessibilityElement(true); setAccessibilityRole(.button); setAccessibilityLabel(event.title + "，" + event.startDate.description + " 至 " + event.endDate.description)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        Theme.eventFill(past: past).setFill(); NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill()
        let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byTruncatingTail
        let leading: CGFloat = segment.continuesBefore ? 14 : 7
        let trailing: CGFloat = segment.continuesAfter ? 15 : 7
        let font = NSFont.systemFont(ofSize: fontSize)
        let text = NSAttributedString(string: event.title, attributes: [.font: font, .foregroundColor: Theme.eventInk(past: past), .paragraphStyle: paragraph])
        text.draw(in: NSRect(x: leading, y: max(0, (bounds.height - fontSize - 3) / 2), width: max(0, bounds.width - leading - trailing), height: bounds.height))
        Theme.eventInk(past: past).withAlphaComponent(0.75).setStroke()
        for (show, x, direction): (Bool, CGFloat, CGFloat) in [(segment.continuesBefore, 7, -1), (segment.continuesAfter, bounds.width - 7, 1)] where show {
            let p = NSBezierPath(); p.lineWidth = 1; p.move(to: NSPoint(x: x - direction * 2, y: bounds.midY - 3)); p.line(to: NSPoint(x: x + direction, y: bounds.midY)); p.line(to: NSPoint(x: x - direction * 2, y: bounds.midY + 3)); p.stroke()
        }
    }
    override func mouseDown(with event: NSEvent) {
        guard monthView?.controller?.allowsEventInteraction != false else { return }
        pressPoint = monthView?.convert(event.locationInWindow, from: nil); dragging = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard let monthView, let start = pressPoint else { return }
        let point = monthView.convert(event.locationInWindow, from: nil)
        if !dragging && hypot(point.x - start.x, point.y - start.y) >= 4 { dragging = true; monthView.startEventDrag(self, point: start) }
        if dragging { monthView.updateEventDrag(point: point) }
    }
    override func mouseUp(with event: NSEvent) {
        defer { pressPoint = nil; dragging = false }
        guard pressPoint != nil, let monthView else { return }
        if dragging { _ = monthView.finishEventDrag(point: monthView.convert(event.locationInWindow, from: nil)) }
        else if bounds.contains(convert(event.locationInWindow, from: nil)) { monthView.edit(self) }
    }
    override func rightMouseDown(with event: NSEvent) { monthView?.controller?.eventMenu(self.event, event: event, view: self) }
    override func accessibilityPerformPress() -> Bool { monthView?.edit(self); return true }
}

final class WeekEventBarView: EventBarView {
    private static func textSize(_ title: String, width: CGFloat) -> NSSize {
        let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byWordWrapping
        return (title as NSString).boundingRect(with: NSSize(width: max(1, width - 28), height: 10_000), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .paragraphStyle: paragraph]).size
    }
    static func height(for title: String, width: CGFloat) -> CGFloat { max(26, ceil(textSize(title, width: width).height) + 10) }
    override func draw(_ dirtyRect: NSRect) {
        Theme.eventFill(past: past).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
        let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byWordWrapping
        let text = NSAttributedString(string: event.title, attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: Theme.eventInk(past: past), .paragraphStyle: paragraph])
        text.draw(in: bounds.insetBy(dx: 14, dy: 5))
    }
}
