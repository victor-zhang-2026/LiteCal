import Foundation
import CoreGraphics
@main struct CoreTests {
 static func main() throws {
    var checks = 0
    func check(_ value: Bool, _ label: String) { checks += 1; if !value { fatalError("FAIL: \(label)") } }
    func day(_ key: String) -> CivilDate { CivilDate(key: key)! }
    check(CivilDate(key: "2026-02-29") == nil, "reject invalid date")
    check(CivilDate(key: "2024-02-29") != nil, "leap year")
    check(CivilDate(key: "2026-13-01") == nil, "reject invalid month")
    check(day("2026-12-31").adding(days: 1) == day("2027-01-01"), "cross-year day")
    check(day("2026-12-31").adding(months: 1) == day("2027-01-01"), "month navigation")
    check(day("2021-02-01").monthDays.count == 28, "four week month")
    check(day("2026-10-01").monthDays.count == 35, "five week month")
    check(day("2026-03-01").monthDays.count == 42, "six week month")
    for year in 1900...2100 { for month in 1...12 {
        let target = CivilDate(year: year, month: month, day: 1), days = CivilDate(year: year, month: month, day: 1).monthDays
        check([28,35,42].contains(days.count), "4–6 rows")
        check(CivilDate.calendar.component(.weekday, from: days[0].date) == 2, "Monday start")
        check(days.filter { $0.month == month }.count == CivilDate.calendar.range(of: .day, in: .month, for: target.date)!.count, "all month days exactly once")
        check(Set(days).count == days.count, "no duplicate dates")
    }}
    for offset in 0..<1461 {
        let value = day("2023-01-01").adding(days: offset), week = day("2023-01-01").adding(days: offset).weekDays
        check(week.count == 7 && Set(week).count == 7, "week has seven unique days")
        check(CivilDate.calendar.component(.weekday, from: week[0].date) == 2, "week starts Monday")
        check(week.contains(value) && week[0].days(until: week[6]) == 6, "week contains anchor and six consecutive days")
    }
    check(day("2024-02-29").weekStart == day("2024-02-26"), "leap-day week")
    check(day("2026-11-01").weekStart == day("2026-10-26"), "Sunday belongs to prior-month Monday")
    check(day("2027-01-01").weekTitle == "2026年12月28日–2027年1月3日", "cross-year week title")
    check(LunarCalendar.label(for: day("2024-02-10")) == "正月", "Chinese New Year 2024")
    check(LunarCalendar.label(for: day("2024-02-24")) == "十五", "Lantern Festival 2024")
    check(LunarCalendar.label(for: day("2023-03-22")) == "闰二月", "leap lunar month")
    check(LunarCalendar.label(for: day("2026-02-17")) == "正月", "Chinese New Year 2026")
    for zone in ["Asia/Shanghai", "America/Los_Angeles", "Pacific/Kiritimati"] {
        let d = day("2026-10-21")
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: zone)!
        let date = c.date(from: DateComponents(year: d.year, month: d.month, day: d.day, hour: 12))!
        check(CivilDate(date, timeZone: c.timeZone) == d, "civil date in \(zone)")
        check(String(data: try JSONEncoder().encode(d), encoding: .utf8)! == "\"2026-10-21\"", "timezone independent JSON")
    }
    let root = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(UUID().uuidString)
    let store = EventStore(directory: root)
    let a = try store.save(title: "  产品方案评审  ", date: day("2026-10-21"))
    let b = try store.save(title: "用户访谈", date: day("2026-10-21"))
    check(store.events(on: a.date).map(\.id) == [a.id, b.id], "creation order")
    check(a.title == "产品方案评审", "trim name")
    let moved = try store.save(id: a.id, title: "修改并移动", date: day("2026-11-01"))
    check(moved.id == a.id && moved.createdAt == a.createdAt, "stable identity and creation time")
    let reloaded = EventStore(directory: root)
    check(reloaded.events.count == 2 && reloaded.events(on: day("2026-11-01")).first?.title == "修改并移动", "restart persisted edits")
    try reloaded.delete(id: b.id)
    check(EventStore(directory: root).events.count == 1, "persist delete")
    check(try EventStore.decode(Data(contentsOf: store.backup)).events.count == 2, "previous valid backup")
    do { _ = try reloaded.save(title: " \n ", date: a.date); fatalError("blank accepted") } catch { checks += 1 }
    let valid = try Data(contentsOf: store.file)
    try Data("{broken".utf8).write(to: store.file, options: .atomic)
    let corrupt = EventStore(directory: root)
    check(corrupt.loadError != nil, "corruption surfaced")
    do { _ = try corrupt.save(title: "cannot overwrite", date: a.date); fatalError("overwrote corrupt file") } catch { checks += 1 }
    check(try Data(contentsOf: store.file) == Data("{broken".utf8), "corrupt original preserved")
    try valid.write(to: store.file, options: .atomic)
    var json = try JSONSerialization.jsonObject(with: valid) as! [String: Any]; json["schemaVersion"] = 99
    let future = try JSONSerialization.data(withJSONObject: json); try future.write(to: store.file, options: .atomic)
    let newer = EventStore(directory: root); check(newer.loadError != nil, "future schema blocks load")
    do { try newer.delete(id: a.id); fatalError("future schema overwritten") } catch { checks += 1 }
    check(try Data(contentsOf: store.file) == future, "future file preserved")
    try valid.write(to: store.file, options: .atomic)
    let failure = EventStore(directory: root)
    try FileManager.default.moveItem(at: failure.file, to: root.appendingPathComponent("saved.json"))
    try FileManager.default.createDirectory(at: failure.file, withIntermediateDirectories: false)
    do { _ = try failure.save(title: "fail save", date: a.date); fatalError("write should fail") } catch { checks += 1 }
    check(failure.events.count == 1, "failed write leaves memory unchanged")
    let screens = [CGRect(x: 0,y: 0,width: 1440,height: 900), CGRect(x: -1920,y: -100,width: 1920,height: 1080), CGRect(x: 1440,y: 300,width: 1280,height: 800)]
    check(Placement.screenIndex(window: CGRect(x: -1500,y: 100,width: 60,height: 60),screens: screens) == 1, "saved negative screen")
    check(Placement.screenIndex(window: CGRect(x: 1420,y: 400,width: 60,height: 60),screens: screens,pointer: CGPoint(x: 1450,y: 420)) == 2, "drag chooses pointer screen")
    check(Placement.screenIndex(window: CGRect(x: 3000,y: 500,width: 60,height: 60),screens: screens) == 2, "disconnected nearest screen")
    for frame in screens + [CGRect(x: 0,y: 0,width: 1024,height: 640)] {
        for x in stride(from: frame.minX - 100, through: frame.maxX + 100, by: 100) {
            for y in [frame.minY - 100, frame.midY, frame.maxY + 100] {
                let trigger = Placement.clamp(CGRect(x: x,y: y,width: 60,height: 60),to: frame)
                let panel = Placement.panel(trigger: trigger,visible: frame)
                check(frame.contains(trigger), "trigger in visible frame")
                check(frame.contains(panel), "calendar in visible frame")
            }
        }
    }
    // Schema 1 migration retains all identities, dates, names and timestamps.
    let legacyRoot = root.appendingPathComponent("migration")
    try FileManager.default.createDirectory(at: legacyRoot, withIntermediateDirectories: true)
    let legacy: [String: Any] = ["schemaVersion": 1, "events": [["id": a.id.uuidString, "date": "2026-10-21", "title": "旧版事项", "createdAt": "2026-10-01T08:00:00Z", "updatedAt": "2026-10-20T09:00:00Z"]]]
    let legacyData = try JSONSerialization.data(withJSONObject: legacy, options: .sortedKeys)
    let legacyFile = legacyRoot.appendingPathComponent("events.json")
    try legacyData.write(to: legacyFile)
    let migrated = EventStore(directory: legacyRoot)
    check(migrated.didMigrate && migrated.loadError == nil, "schema 1 migrates successfully")
    check(try Data(contentsOf: migrated.migrationBackup) == legacyData, "byte-for-byte immutable migration backup")
    check(migrated.events == (try EventStore.decode(legacyData)).events, "all legacy fields preserved")
    check(try EventStore.decode(Data(contentsOf: legacyFile)).schemaVersion == 3, "upgraded schema persisted")
    check(!EventStore(directory: legacyRoot).didMigrate, "migration idempotent on restart")
    let multi = try migrated.save(title: "跨年三日", startDate: day("2026-12-31"), endDate: day("2027-01-02"))
    check(multi.duration == 2 && migrated.events(on: day("2027-01-01")).contains(multi), "inclusive three-day membership")
    try migrated.move(id: multi.id, by: 2)
    let shifted = migrated.events.first { $0.id == multi.id }!
    check(shifted.startDate == day("2027-01-02") && shifted.endDate == day("2027-01-04") && shifted.duration == multi.duration, "move across year preserves duration")
    check(shifted.id == multi.id && shifted.createdAt == multi.createdAt, "move preserves identity/order")
    check(!shifted.isPast(today: shifted.endDate), "ending today stays normal")
    check(shifted.isPast(today: shifted.endDate.adding(days: 1)), "entire event weakens day after end")
    check(!shifted.isPast(today: shifted.startDate.adding(days: -1)), "future event stays normal")
    let beforeInvalid = try Data(contentsOf: migrated.file)
    do { try migrated.save(title: "invalid", startDate: day("2026-10-22"), endDate: day("2026-10-21")); fatalError("accepted inverted range") } catch { checks += 1 }
    check(try Data(contentsOf: migrated.file) == beforeInvalid, "invalid range changes no data")
    let stale = EventStore(directory: legacyRoot)
    try migrated.save(title: "newer writer", date: day("2026-10-23"))
    let newerBytes = try Data(contentsOf: migrated.file)
    do { try stale.delete(id: multi.id); fatalError("stale writer overwrote data") } catch { checks += 1 }
    check(try Data(contentsOf: migrated.file) == newerBytes, "external changes protected")
    let blockedRoot = root.appendingPathComponent("blocked-migration")
    try FileManager.default.createDirectory(at: blockedRoot.appendingPathComponent("events.schema1.backup.json"), withIntermediateDirectories: true)
    try legacyData.write(to: blockedRoot.appendingPathComponent("events.json"))
    let blocked = EventStore(directory: blockedRoot)
    check(blocked.loadError != nil && !blocked.didMigrate, "backup failure blocks migration")
    check(try Data(contentsOf: blocked.file) == legacyData, "failed migration preserves original")
    // Fixed-frequency recurrence: original anchors, inclusive spans, bounded expansion.
    let repeatStore = EventStore(directory: root.appendingPathComponent("recurrence"))
    let daily = try repeatStore.save(title: "每日", date: day("2026-12-30"), recurrence: .daily)
    check(daily.occurrences(from: day("2026-12-29"), through: day("2027-01-02")).map(\.startDate) == ["2026-12-30", "2026-12-31", "2027-01-01", "2027-01-02"].map(day), "daily crosses year and never repeats before anchor")
    let weekly = try repeatStore.save(title: "每周跨日", startDate: day("2026-12-30"), endDate: day("2027-01-01"), recurrence: .weekly)
    let weeklyItems = weekly.occurrences(from: day("2027-01-01"), through: day("2027-01-14"))
    check(weeklyItems.map(\.startDate) == ["2026-12-30", "2027-01-06", "2027-01-13"].map(day) && weeklyItems.allSatisfy { $0.duration == 2 }, "weekly retains duration and includes earlier overlapping start")
    let monthly = try repeatStore.save(title: "月末", date: day("2024-01-31"), recurrence: .monthly)
    check(monthly.occurrences(from: day("2024-01-01"), through: day("2024-05-31")).map(\.startDate) == ["2024-01-31", "2024-02-29", "2024-03-31", "2024-04-30", "2024-05-31"].map(day), "month-end clamps without anchor drift")
    check(monthly.occurrences(from: day("2025-02-01"), through: day("2025-02-28")).map(\.startDate) == [day("2025-02-28")], "non-leap month clamps")
    let yearly = try repeatStore.save(title: "闰日", date: day("2024-02-29"), recurrence: .yearly)
    check(yearly.occurrences(from: day("2024-01-01"), through: day("2028-12-31")).map(\.startDate) == ["2024-02-29", "2025-02-28", "2026-02-28", "2027-02-28", "2028-02-29"].map(day), "annual leap-day returns to original anchor")
    check(EventStore(directory: repeatStore.directory).events.map(\.recurrence) == [.daily, .weekly, .monthly, .yearly], "all frequencies persist on restart")
    try repeatStore.move(id: monthly.id, by: 1)
    check(repeatStore.events.first { $0.id == monthly.id }!.startDate == day("2024-02-01") && repeatStore.events.first { $0.id == monthly.id }!.recurrence == .monthly, "drag shifts series anchor and preserves frequency")
    try repeatStore.save(id: yearly.id, title: yearly.title, date: yearly.startDate, recurrence: RepeatFrequency.none)
    check(repeatStore.events(on: day("2028-02-29")).allSatisfy { $0.id != yearly.id }, "turning repetition off removes derived occurrences")
    try repeatStore.delete(id: daily.id)
    check(repeatStore.events(on: day("2027-01-02")).allSatisfy { $0.id != daily.id }, "delete removes entire series")
    var overlapping = daily; overlapping.endDate = daily.startDate.adding(days: 3)
    let overlapDay = day("2027-01-02"), overlapGrid = overlapDay.monthDays
    let overlapItems = overlapping.occurrences(from: overlapGrid.first!, through: overlapGrid.last!)
    check(overlapping.occurrences(from: overlapDay, through: overlapDay).count == 4, "daily multiday occurrences overlap independently")
    check(Set(overlapItems.map(\.occurrenceKey)).count == overlapItems.count, "each occurrence has distinct render identity")
    let overlapLayout = MonthEventLayout.calculate(days: overlapGrid, events: overlapItems)
    let overlapIndex = overlapGrid.firstIndex(of: overlapDay)!
    let overlapSegments = overlapLayout.segments.filter { $0.week == overlapIndex / 7 && $0.firstColumn <= overlapIndex % 7 && $0.lastColumn >= overlapIndex % 7 }
    check(overlapSegments.count == 4 && Set(overlapSegments.map(\.lane)).count == 4 && overlapLayout.hiddenIDs[overlapDay]?.count == 1, "overlapping series renders separate lanes and exact overflow")
    check(overlapItems.first!.isPast(today: day("2027-02-01")), "history styling uses occurrence end")
    for frequency in RepeatFrequency.allCases where frequency != .none {
        var edge = daily; edge.startDate = day("9999-12-30"); edge.endDate = day("9999-12-31"); edge.recurrence = frequency
        check(edge.occurrences(from: day("9999-12-01"), through: day("9999-12-31")).count == 1, "upper date bound terminates safely for \(frequency)")
        var ancient = daily; ancient.startDate = day("0001-01-01"); ancient.endDate = ancient.startDate; ancient.recurrence = frequency
        check(!ancient.occurrences(from: day("9998-01-01"), through: day("9998-12-31")).isEmpty, "distant queries jump to window for \(frequency)")
        check(ancient.occurrences(from: day("0001-01-01"), through: day("0001-01-01")).count == 1, "lower bound safe for \(frequency)")
    }
    // Compare narrow-window expansion with an independently filtered wider expansion.
    for frequency in RepeatFrequency.allCases {
        var fixture = monthly; fixture.recurrence = frequency; fixture.endDate = fixture.startDate.adding(days: 40)
        let wide = fixture.occurrences(from: fixture.startDate, through: day("2028-12-31"))
        for offset in stride(from: 0, through: 1700, by: 17) {
            let first = fixture.startDate.adding(days: offset), last = first.adding(days: 6)
            check(fixture.occurrences(from: first, through: last) == wide.filter { $0.startDate <= last && $0.endDate >= first }, "narrow expansion retains overlapping occurrences for \(frequency)")
        }
    }
    // Schema 2 migrates with an immutable backup; older apps reject schema 3.
    let schema2Root = root.appendingPathComponent("schema2")
    try FileManager.default.createDirectory(at: schema2Root, withIntermediateDirectories: true)
    var oldJSON = try JSONSerialization.jsonObject(with: EventStore.encode([monthly])) as! [String: Any]
    oldJSON["schemaVersion"] = 2
    var oldEvents = oldJSON["events"] as! [[String: Any]]; oldEvents[0].removeValue(forKey: "recurrence"); oldJSON["events"] = oldEvents
    let oldData = try JSONSerialization.data(withJSONObject: oldJSON)
    let oldFile = schema2Root.appendingPathComponent("events.json"), oldBackup = schema2Root.appendingPathComponent("events.schema2.backup.json")
    try oldData.write(to: oldFile)
    let migrated2 = EventStore(directory: schema2Root)
    check(migrated2.didMigrate && migrated2.events.first?.recurrence == RepeatFrequency.none, "old events default to no repetition")
    check(try Data(contentsOf: oldBackup) == oldData, "schema 2 backup exact bytes")
    check(migrated2.events.first?.id == monthly.id && migrated2.events.first?.startDate == monthly.startDate, "schema 2 preserves source fields")
    check(!EventStore(directory: schema2Root).didMigrate, "schema 3 reload does not migrate again")
    oldEvents[0]["title"] = "another source"; oldJSON["events"] = oldEvents
    try JSONSerialization.data(withJSONObject: oldJSON).write(to: oldFile)
    check(EventStore(directory: schema2Root).didMigrate, "different old source still migrates")
    check(try Data(contentsOf: oldBackup) == oldData, "existing schema 2 backup never overwritten")
    let blocked2Root = root.appendingPathComponent("blocked-schema2")
    try FileManager.default.createDirectory(at: blocked2Root.appendingPathComponent("events.schema2.backup.json"), withIntermediateDirectories: true)
    try oldData.write(to: blocked2Root.appendingPathComponent("events.json"))
    let blocked2 = EventStore(directory: blocked2Root)
    check(try blocked2.loadError != nil && Data(contentsOf: blocked2.file) == oldData, "schema 2 backup failure preserves original")
    oldEvents[0]["recurrence"] = "custom"; oldJSON["schemaVersion"] = 3; oldJSON["events"] = oldEvents
    do { _ = try EventStore.decode(JSONSerialization.data(withJSONObject: oldJSON)); fatalError("unknown frequency accepted") } catch { checks += 1 }

    // Deterministic overlapping spans, including events crossing the whole visible grid.
    for monthKey in ["2021-02-01", "2026-03-01", "2026-10-01", "2026-12-01", "2027-01-01"] {
        let days = day(monthKey).monthDays
        var fixtures: [CalendarEvent] = []
        for i in 0..<80 {
            let start = days[0].adding(days: (i * 17) % 66 - 15)
            fixtures.append(CalendarEvent(id: UUID(), startDate: start, endDate: start.adding(days: (i * 7) % 23), title: "Overlap \(i)", createdAt: Date(timeIntervalSince1970: Double(i)), updatedAt: Date(timeIntervalSince1970: Double(i))))
        }
        let result = MonthEventLayout.calculate(days: days, events: fixtures)
        check(result.segments == MonthEventLayout.calculate(days: days, events: fixtures).segments, "stable weekly lanes")
        for (index, d) in days.enumerated() {
            let spans = result.segments.filter { $0.week == index / 7 && $0.firstColumn <= index % 7 && $0.lastColumn >= index % 7 }
            check(Set(spans.map(\.eventID)) == Set(fixtures.filter { $0.contains(d) }.map(\.id)), "every event/date covered exactly")
            check(Set(spans.map(\.lane)).count == spans.count, "no overlapping lanes")
            check(Set(result.hiddenIDs[d] ?? []) == Set(spans.filter { $0.lane >= 3 }.map(\.eventID)), "overflow count matches hidden events")
        }
        for segment in result.segments {
            let item = fixtures.first { $0.id == segment.eventID }!
            check(segment.continuesBefore == (item.startDate < days[segment.week * 7]), "leading continuation correct")
            check(segment.continuesAfter == (item.endDate > days[segment.week * 7 + 6]), "trailing continuation correct")
        }
    }
    let busyDay = day("2026-10-22"), spanStart = day("2026-10-19")
    var busyFixtures = (0..<12).map { i in CalendarEvent(id: UUID(), startDate: busyDay, endDate: busyDay, title: "single", createdAt: Date(timeIntervalSince1970: Double(i)), updatedAt: Date(timeIntervalSince1970: Double(i))) }
    let longSpan = CalendarEvent(id: UUID(), startDate: spanStart, endDate: spanStart.adding(days: 4), title: "span", createdAt: Date(timeIntervalSince1970: 100), updatedAt: Date(timeIntervalSince1970: 100))
    busyFixtures.append(longSpan)
    let busyLayout = MonthEventLayout.calculate(days: busyDay.monthDays, events: busyFixtures)
    check(busyLayout.segments.first { $0.eventID == longSpan.id }!.lane == 0, "multi-day row remains visible despite crowded single day")
    check(busyLayout.hiddenIDs[spanStart] == nil, "empty day does not unnecessarily hide spanning event")
    for visible in screens { for x in [visible.minX, visible.midX, visible.maxX - 1] { for y in [visible.minY, visible.midY, visible.maxY - 1] {
        let anchor = CGRect(x: x, y: y, width: 1, height: 1)
        check(visible.contains(Placement.overlay(anchor: anchor, size: CGSize(width: 344, height: 314), visible: visible)), "anchored editor stays on screen")
    } } }
    print("PASS: \(checks) assertions; 2412 months; lunar fixtures; civil dates; persistence and failures; display geometry. Isolated data: \(root.path)")
 }
}
