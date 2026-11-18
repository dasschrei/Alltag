import Foundation
import EventKit

/// Eigener Kalender der App, im Hintergrund synchron mit dem iPhone-Kalender.
@MainActor
@Observable
final class CalendarService {
    static let shared = CalendarService()

    let store = EKEventStore()
    var authorized = false
    var revision = 0

    private init() {
        authorized = EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    func requestAccess() async {
        do {
            authorized = try await store.requestFullAccessToEvents()
        } catch {
            authorized = false
        }
    }

    func events(on day: Date) -> [EKEvent] {
        guard authorized else { return [] }
        let start = Calendar.current.startOfDay(for: day)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }

    func events(from start: Date, to end: Date) -> [EKEvent] {
        guard authorized else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }

    func changed() { revision += 1 }

    @discardableResult
    func addEvent(title: String, start: Date, minutes: Int, notes: String? = nil) -> Bool {
        guard authorized else { return false }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = start.addingTimeInterval(TimeInterval(max(minutes, 15) * 60))
        event.notes = notes
        event.calendar = store.defaultCalendarForNewEvents
        do {
            try store.save(event, span: .thisEvent)
            revision += 1
            return true
        } catch {
            return false
        }
    }

    func summary(for day: Date) -> [String] {
        let tf = DateFormatter()
        tf.dateFormat = "HH:mm"
        return events(on: day).map { ev in
            ev.isAllDay ? "ganztägig: \(ev.title ?? "")" : "\(tf.string(from: ev.startDate)) \(ev.title ?? "")"
        }
    }
}
