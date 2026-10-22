import Foundation

struct CalendarEvent: Codable, Identifiable, Equatable {
    var id: UUID
    var startDate: CivilDate
    var endDate: CivilDate
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var date: CivilDate { startDate }
    var duration: Int { startDate.days(until: endDate) }
    func contains(_ day: CivilDate) -> Bool { startDate <= day && day <= endDate }
    func isPast(today: CivilDate) -> Bool { endDate < today }
}
struct EventDocument: Codable {
    var schemaVersion = 2
    var events: [CalendarEvent] = []
    init(schemaVersion: Int = 2, events: [CalendarEvent] = []) { self.schemaVersion = schemaVersion; self.events = events }
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
        case 2: events = try c.decode([CalendarEvent].self, forKey: .events)
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
                if document.schemaVersion == 1 {
                    // A pre-existing migration backup is immutable. A different legacy source
                    // gets its own backup rather than destroying any prior recovery point.
                    var destination = migrationBackup
                    if FileManager.default.fileExists(atPath: destination.path), try Data(contentsOf: destination) != original {
                        destination = directory.appendingPathComponent("events.schema1.\(UUID().uuidString).backup.json")
                    }
                    if !FileManager.default.fileExists(atPath: destination.path) { try original.write(to: destination, options: .atomic) }
                    guard try Data(contentsOf: destination) == original else { throw StoreError.invalid("迁移备份校验失败，已保留原数据。") }
                    let upgraded = try Self.encode(document.events)
                    try upgraded.write(to: file, options: .atomic)
                    lastWrittenData = upgraded; didMigrate = true
                    NSLog("LiteCal migrated %ld events to schema 2; source backup retained", document.events.count)
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
    func events(on day: CivilDate) -> [CalendarEvent] { orderedEvents.filter { $0.contains(day) } }
    var orderedEvents: [CalendarEvent] {
        events.enumerated().sorted {
            $0.element.createdAt == $1.element.createdAt ? $0.offset < $1.offset : $0.element.createdAt < $1.element.createdAt
        }.map(\.element)
    }
    @discardableResult func save(id: UUID? = nil, title: String, date: CivilDate) throws -> CalendarEvent {
        try save(id: id, title: title, startDate: date, endDate: date)
    }
    @discardableResult func save(id: UUID? = nil, title: String, startDate: CivilDate, endDate: CivilDate) throws -> CalendarEvent {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw StoreError.invalid("请输入事项名称。") }
        guard startDate <= endDate else { throw StoreError.invalid("结束日期不能早于开始日期。") }
        guard startDate.year >= 1, endDate.year <= 9999 else { throw StoreError.invalid("日期超出支持范围。") }
        var next = events
        let result: CalendarEvent
        if let id {
            guard let i = next.firstIndex(where: { $0.id == id }) else { throw StoreError.invalid("该事项已不存在，请重新打开。") }
            next[i].title = clean; next[i].startDate = startDate; next[i].endDate = endDate; next[i].updatedAt = max(Date(), next[i].createdAt); result = next[i]
        } else {
            let now = Date()
            result = CalendarEvent(id: UUID(), startDate: startDate, endDate: endDate, title: clean, createdAt: now, updatedAt: now)
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
