import Foundation

struct CivilDate: Hashable, Comparable, Codable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        c.firstWeekday = 2
        return c
    }
    init(year: Int, month: Int, day: Int) { self.year = year; self.month = month; self.day = day }
    init(_ date: Date, timeZone: TimeZone = .current) {
        var c = Self.calendar; c.timeZone = timeZone
        let p = c.dateComponents([.year, .month, .day], from: date)
        self.init(year: p.year!, month: p.month!, day: p.day!)
    }
    init?(key: String) {
        let p = key.split(separator: "-", omittingEmptySubsequences: false)
        guard p.count == 3, p[0].count == 4, p[1].count == 2, p[2].count == 2,
              let y = Int(p[0]), let m = Int(p[1]), let d = Int(p[2]), (1...9999).contains(y) else { return nil }
        self.init(year: y, month: m, day: d)
        guard let dt = Self.calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12)),
              CivilDate(dt, timeZone: TimeZone(secondsFromGMT: 0)!) == self else { return nil }
    }
    var description: String { String(format: "%04d-%02d-%02d", year, month, day) }
    var date: Date { Self.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))! }
    var localDate: Date {
        var c = Self.calendar; c.timeZone = .current
        return c.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.description < rhs.description }
    func adding(days: Int) -> Self { Self(Self.calendar.date(byAdding: .day, value: days, to: date)!, timeZone: TimeZone(secondsFromGMT: 0)!) }
    func days(until other: Self) -> Int { Self.calendar.dateComponents([.day], from: date, to: other.date).day! }
    var monthStart: Self { Self(year: year, month: month, day: 1) }
    func adding(months: Int) -> Self { Self(Self.calendar.date(byAdding: .month, value: months, to: monthStart.date)!, timeZone: TimeZone(secondsFromGMT: 0)!) }
    var monthDays: [Self] {
        let start = monthStart
        let leading = (Self.calendar.component(.weekday, from: start.date) + 5) % 7
        let count = Self.calendar.range(of: .day, in: .month, for: start.date)!.count
        return (0..<((leading + count + 6) / 7 * 7)).map { start.adding(days: $0 - leading) }
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer(); let key = try c.decode(String.self)
        guard let value = Self(key: key) else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid civil date") }
        self = value
    }
    func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(description) }
}

enum LunarCalendar {
    static func label(for day: CivilDate) -> String {
        var c = Calendar(identifier: .chinese); c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let p = c.dateComponents(in: c.timeZone, from: day.date)
        let names = ["正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "冬月", "腊月"]
        guard let m = p.month, let d = p.day, (1...12).contains(m), (1...30).contains(d) else { return "" }
        if d == 1 { return (p.isLeapMonth == true ? "闰" : "") + names[m - 1] }
        let digits = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
        if d <= 10 { return "初" + digits[d - 1] }
        if d < 20 { return "十" + digits[d - 11] }
        if d == 20 { return "二十" }
        if d < 30 { return "廿" + digits[d - 21] }
        return "三十"
    }
}
