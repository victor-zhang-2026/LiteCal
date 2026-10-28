import Foundation

enum RepeatFrequency: String, Codable, CaseIterable {
    case none, daily, weekly, monthly, yearly
    var title: String {
        switch self {
        case .none: return "不重复"
        case .daily: return "每天"
        case .weekly: return "每周"
        case .monthly: return "每月"
        case .yearly: return "每年"
        }
    }
}

struct CalendarEvent: Codable, Identifiable, Equatable {
    var id: UUID
    var startDate: CivilDate
    var endDate: CivilDate
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var recurrence: RepeatFrequency = .none
    // A series keeps one persistent ID; each displayed occurrence also has its own start.
    var occurrenceKey: String { id.uuidString + ":" + startDate.description }
    private enum CodingKeys: String, CodingKey { case id, startDate, endDate, title, createdAt, updatedAt, recurrence }
    init(id: UUID, startDate: CivilDate, endDate: CivilDate, title: String, createdAt: Date, updatedAt: Date, recurrence: RepeatFrequency = .none) {
        self.id = id; self.startDate = startDate; self.endDate = endDate; self.title = title
        self.createdAt = createdAt; self.updatedAt = updatedAt; self.recurrence = recurrence
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        startDate = try c.decode(CivilDate.self, forKey: .startDate); endDate = try c.decode(CivilDate.self, forKey: .endDate)
        title = try c.decode(String.self, forKey: .title)
        createdAt = try c.decode(Date.self, forKey: .createdAt); updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        recurrence = try c.decodeIfPresent(RepeatFrequency.self, forKey: .recurrence) ?? .none
    }
    var date: CivilDate { startDate }
    var duration: Int { startDate.days(until: endDate) }
    func contains(_ day: CivilDate) -> Bool { startDate <= day && day <= endDate }
    func isPast(today: CivilDate) -> Bool { endDate < today }

    /// Expand only occurrences overlapping the requested civil-date window. Always
    /// calculate from the original anchor so February never shifts later months.
    func occurrences(from first: CivilDate, through last: CivilDate) -> [CalendarEvent] {
        guard first <= last, startDate <= last else { return [] }
        guard recurrence != .none else { return endDate >= first ? [self] : [] }
        let span = duration
        let minimum = CivilDate(year: 1, month: 1, day: 1)
        let earliest = span >= minimum.days(until: first) ? startDate : max(startDate, first.adding(days: -span))
        var index: Int
        switch recurrence {
        case .daily: index = startDate.days(until: earliest)
        case .weekly: index = startDate.days(until: earliest) / 7
        case .monthly: index = (earliest.year - startDate.year) * 12 + earliest.month - startDate.month
        case .yearly: index = earliest.year - startDate.year
        case .none: return []
        }
        var result: [CalendarEvent] = []
        let maximum = CivilDate(year: 9999, month: 12, day: 31)
        while let start = occurrenceStart(at: index), start <= last {
            guard span <= start.days(until: maximum) else { break }
            let end = start.adding(days: span)
            if end >= first {
                var occurrence = self; occurrence.startDate = start; occurrence.endDate = end
                result.append(occurrence)
            }
            index += 1
        }
        return result
    }
    private func occurrenceStart(at index: Int) -> CivilDate? {
        switch recurrence {
        case .none: return index == 0 ? startDate : nil
        case .daily, .weekly:
            let offset = index * (recurrence == .weekly ? 7 : 1)
            guard offset <= startDate.days(until: CivilDate(year: 9999, month: 12, day: 31)) else { return nil }
            return startDate.adding(days: offset)
        case .monthly, .yearly:
            let total = (startDate.year - 1) * 12 + startDate.month - 1 + index * (recurrence == .yearly ? 12 : 1)
            let year = total / 12 + 1, month = total % 12 + 1
            guard (1...9999).contains(year) else { return nil }
            let first = CivilDate(year: year, month: month, day: 1)
            let length = CivilDate.calendar.range(of: .day, in: .month, for: first.date)!.count
            return CivilDate(year: year, month: month, day: min(startDate.day, length))
        }
    }
}
struct EventDocument: Codable {
    var schemaVersion = 3
    var events: [CalendarEvent] = []
    init(schemaVersion: Int = 3, events: [CalendarEvent] = []) { self.schemaVersion = schemaVersion; self.events = events }
    private enum CodingKeys: String, CodingKey { case schemaVersion, events }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        switch schemaVersion {
        case 1:
            struct Legacy: Decodable { let id: UUID; let date: CivilDate; let title: String; let createdAt: Date; let updatedAt: Date }
            events = try c.decode([Legacy].self, forKey: .events).map {
                CalendarEvent(id: $0.id, startDate: $0.date, endDate: $0.date, title: $0.title, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            }
        case 2, 3: events = try c.decode([CalendarEvent].self, forKey: .events)
        default: throw StoreError.invalid("数据版本不受支持。原文件已保留，请使用兼容版本打开。")
        }
    }
}
enum StoreError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}
final class EventStore {
    let directory: URL
    var file: URL { directory.appendingPathComponent("events.json") }
    var backup: URL { directory.appendingPathComponent("events.backup.json") }
    var migrationBackup: URL { directory.appendingPathComponent("events.schema1.backup.json") }
    private(set) var events: [CalendarEvent] = []
    private(set) var loadError: Error?
    private(set) var didMigrate = false
    private var lastWrittenData: Data?
    var onChange: (() -> Void)?
    init(directory: URL) {
        self.directory = directory
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            if FileManager.default.fileExists(atPath: file.path) {
                let original = try Data(contentsOf: file)
                let document = try Self.decode(original)
                if document.schemaVersion < 3 {
                    // A pre-existing migration backup is immutable. A different legacy source
                    // gets its own backup rather than destroying any prior recovery point.
                    var destination = directory.appendingPathComponent("events.schema\(document.schemaVersion).backup.json")
                    if FileManager.default.fileExists(atPath: destination.path), try Data(contentsOf: destination) != original {
                        destination = directory.appendingPathComponent("events.schema\(document.schemaVersion).\(UUID().uuidString).backup.json")
                    }
                    if !FileManager.default.fileExists(atPath: destination.path) { try original.write(to: destination, options: .atomic) }
                    guard try Data(contentsOf: destination) == original else { throw StoreError.invalid("迁移备份校验失败，已保留原数据。") }
                    let upgraded = try Self.encode(document.events)
                    try upgraded.write(to: file, options: .atomic)
                    lastWrittenData = upgraded; didMigrate = true
                    NSLog("LiteCal migrated %ld events to schema 3; source backup retained", document.events.count)
                } else { lastWrittenData = original }
                events = document.events
            }
        } catch { loadError = error; NSLog("LiteCal load error: %@", error.localizedDescription) }
    }
    static func decode(_ data: Data) throws -> EventDocument {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(EventDocument.self, from: data)
        guard Set(document.events.map(\.id)).count == document.events.count,
              document.events.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.updatedAt >= $0.createdAt && $0.startDate <= $0.endDate }) else {
            throw StoreError.invalid("日程数据校验失败，原文件已保留。")
        }
        return document
    }
    static func encode(_ events: [CalendarEvent]) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(EventDocument(events: events)); _ = try decode(data); return data
    }
    func events(on day: CivilDate) -> [CalendarEvent] { occurrences(from: day, through: day) }
    func occurrences(from first: CivilDate, through last: CivilDate) -> [CalendarEvent] {
        orderedEvents.flatMap { $0.occurrences(from: first, through: last) }
    }
    var orderedEvents: [CalendarEvent] {
        events.enumerated().sorted {
            $0.element.createdAt == $1.element.createdAt ? $0.offset < $1.offset : $0.element.createdAt < $1.element.createdAt
        }.map(\.element)
    }
    @discardableResult func save(id: UUID? = nil, title: String, date: CivilDate, recurrence: RepeatFrequency? = nil) throws -> CalendarEvent {
        try save(id: id, title: title, startDate: date, endDate: date, recurrence: recurrence)
    }
    @discardableResult func save(id: UUID? = nil, title: String, startDate: CivilDate, endDate: CivilDate, recurrence: RepeatFrequency? = nil) throws -> CalendarEvent {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw StoreError.invalid("请输入事项名称。") }
        guard startDate <= endDate else { throw StoreError.invalid("结束日期不能早于开始日期。") }
        guard startDate.year >= 1, endDate.year <= 9999 else { throw StoreError.invalid("日期超出支持范围。") }
        var next = events
        let result: CalendarEvent
        if let id {
            guard let i = next.firstIndex(where: { $0.id == id }) else { throw StoreError.invalid("该事项已不存在，请重新打开。") }
            if let recurrence { next[i].recurrence = recurrence }
            next[i].title = clean; next[i].startDate = startDate; next[i].endDate = endDate; next[i].updatedAt = max(Date(), next[i].createdAt); result = next[i]
        } else {
            let now = Date()
            result = CalendarEvent(id: UUID(), startDate: startDate, endDate: endDate, title: clean, createdAt: now, updatedAt: now, recurrence: recurrence ?? .none)
            next.append(result)
        }
        try commit(next); return result
    }
    func move(id: UUID, by days: Int) throws {
        guard let item = events.first(where: { $0.id == id }) else { throw StoreError.invalid("该事项已不存在。") }
        if days == 0 { return }
        try save(id: item.id, title: item.title, startDate: item.startDate.adding(days: days), endDate: item.endDate.adding(days: days))
    }
    func delete(id: UUID) throws { try commit(events.filter { $0.id != id }) }
    private func commit(_ next: [CalendarEvent]) throws {
        if let loadError { throw loadError }
        let data = try Self.encode(next)
        if FileManager.default.fileExists(atPath: file.path) {
            let old = try Data(contentsOf: file)
            guard old == lastWrittenData else { throw StoreError.invalid("数据文件已被其他程序修改，请重启 LiteCal 后再保存。") }
            _ = try Self.decode(old); try old.write(to: backup, options: .atomic)
        } else if lastWrittenData != nil { throw StoreError.invalid("数据文件已被移动，请恢复文件或重启后再保存。") }
        try data.write(to: file, options: .atomic)
        lastWrittenData = data; events = next; onChange?()
    }
}
