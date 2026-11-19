import Foundation
import EventKit
import SwiftData

/// Holt neue Apple-Erinnerungen (z. B. von Pocket) als Aufgaben in die App
/// und gleicht „erledigt“ in beide Richtungen ab.
@MainActor
final class ReminderSync {
    static let shared = ReminderSync()
    private var store: EKEventStore { CalendarService.shared.store }
    private let d = UserDefaults.standard

    /// Nur Erinnerungen ab dem ersten Start übernehmen, damit alte Listen nicht hereinfluten.
    private var since: Date {
        if let s = d.object(forKey: "reminderSyncSince") as? Date { return s }
        let now = Date.now
        d.set(now, forKey: "reminderSyncSince")
        return now
    }
    private var seen: Set<String> {
        get { Set(d.stringArray(forKey: "reminderSeen") ?? []) }
        set { d.set(Array(newValue.suffix(500)), forKey: "reminderSeen") }
    }

    func sync(context: ModelContext) async {
        guard (try? await store.requestFullAccessToReminders()) == true else { return }
        let start = since
        let reminders = await fetch(store.predicateForReminders(in: nil))
        let byID = Dictionary(reminders.map { ($0.calendarItemIdentifier, $0) }, uniquingKeysWith: { a, _ in a })

        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        var known = seen
        for task in tasks { if let id = task.reminderID { known.insert(id) } }

        // Erledigt abgleichen
        for task in tasks {
            guard let id = task.reminderID, let r = byID[id] else { continue }
            if task.done && !r.isCompleted {
                r.isCompleted = true
                try? store.save(r, commit: false)
            } else if r.isCompleted && !task.done {
                task.done = true
            }
        }
        try? store.commit()

        // Neue offene Erinnerungen übernehmen
        for r in reminders where !r.isCompleted && !known.contains(r.calendarItemIdentifier) {
            guard let created = r.creationDate, created >= start else { continue }
            let title = (r.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            let due = r.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
            let task = TaskItem(title: title, area: guessArea(title + " " + (r.notes ?? "")), due: due)
            task.reminderID = r.calendarItemIdentifier
            context.insert(task)
            known.insert(r.calendarItemIdentifier)
        }
        seen = known
        try? context.save()
    }

    private func fetch(_ predicate: NSPredicate) async -> [EKReminder] {
        await withCheckedContinuation { cont in
            store.fetchReminders(matching: predicate) { result in
                nonisolated(unsafe) let list = result ?? []
                cont.resume(returning: list)
            }
        }
    }

    private func guessArea(_ text: String) -> Area {
        let t = text.lowercased()
        let work = ["restaurant", "schrei", "transgourmet", "lieferant", "küche", "service", "gäste", "reservierung",
                    "wein", "personal", "dienstplan", "speisekarte", "kassa", "kasse", "bestell", "steuerberater", "rechnung"]
        return work.contains { t.contains($0) } ? .arbeit : .privat
    }
}
