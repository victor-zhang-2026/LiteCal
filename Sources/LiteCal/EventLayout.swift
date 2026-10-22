import Foundation

struct EventSegment: Equatable {
    let eventID: UUID
    let week: Int
    let firstColumn: Int
    let lastColumn: Int
    let lane: Int
    let continuesBefore: Bool
    let continuesAfter: Bool
}
struct MonthEventLayout {
    let segments: [EventSegment]
    let hiddenIDs: [CivilDate: [UUID]]
    static let visibleLanes = 3
    static func calculate(days: [CivilDate], events: [CalendarEvent]) -> Self {
        guard let first = days.first, let last = days.last, days.count % 7 == 0 else { return Self(segments: [], hiddenIDs: [:]) }
        let ordered = events.enumerated().filter { $0.element.endDate >= first && $0.element.startDate <= last }.sorted {
            // Reserve continuous rows for spans before filling individual date slots.
            // This prevents a crowded Thursday from hiding an otherwise empty Monday–Friday bar.
            if ($0.element.duration > 0) != ($1.element.duration > 0) { return $0.element.duration > 0 }
            return $0.element.createdAt == $1.element.createdAt ? $0.offset < $1.offset : $0.element.createdAt < $1.element.createdAt
        }.map(\.element)
        var result: [EventSegment] = [], hidden: [CivilDate: [UUID]] = [:], previousLanes: [UUID: Int] = [:]
        for week in 0..<(days.count / 7) {
            let weekStart = days[week * 7], weekEnd = days[week * 7 + 6]
            var occupied: [Set<Int>] = []
            var currentLanes: [UUID: Int] = [:]
            for event in ordered where event.startDate <= weekEnd && event.endDate >= weekStart {
                let from = max(0, weekStart.days(until: event.startDate))
                let through = min(6, weekStart.days(until: event.endDate))
                let columns = Set(from...through)
                var lane = occupied.firstIndex { $0.isDisjoint(with: columns) } ?? occupied.count
                // Keep a visible continuation on its prior row when it is available.
                if let previous = previousLanes[event.id], previous < visibleLanes,
                   previous <= occupied.count, (previous == occupied.count || occupied[previous].isDisjoint(with: columns)) { lane = previous }
                while occupied.count <= lane { occupied.append([]) }
                occupied[lane].formUnion(columns); currentLanes[event.id] = lane
                let segment = EventSegment(eventID: event.id, week: week, firstColumn: from, lastColumn: through, lane: lane,
                    continuesBefore: event.startDate < weekStart, continuesAfter: event.endDate > weekEnd)
                result.append(segment)
                if lane >= visibleLanes { for column in from...through { hidden[days[week * 7 + column], default: []].append(event.id) } }
            }
            previousLanes = currentLanes
        }
        return Self(segments: result, hiddenIDs: hidden)
    }
}
