import Foundation
import Contacts
import SwiftData
import UserNotifications

/// Geburtstage aus den Kontakten: Erinnerung 3 Tage vorher und am Tag, mit fertigem Glückwunsch.
@MainActor
@Observable
final class BirthdayService {
    static let shared = BirthdayService()

    struct Birthday: Identifiable {
        var id: String
        var name: String
        var firstName: String
        var next: Date
        var daysUntil: Int
    }

    private let store = CNContactStore()
    var upcoming: [Birthday] = []

    func refresh(context: ModelContext) async {
        guard (try? await store.requestAccess(for: .contacts)) == true else { return }
        let all = await Task.detached { Self.loadBirthdays() }.value
        upcoming = all.filter { $0.daysUntil <= 30 }.sorted { $0.next < $1.next }
        await scheduleNotifications()
        createGreetingsForToday(context: context)
    }

    nonisolated private static func loadBirthdays() -> [Birthday] {
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactBirthdayKey, CNContactIdentifierKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var result: [Birthday] = []
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        try? CNContactStore().enumerateContacts(with: request) { contact, _ in
            guard let b = contact.birthday, let month = b.month, let day = b.day else { return }
            var comps = DateComponents(month: month, day: day)
            comps.year = cal.component(.year, from: today)
            guard var next = cal.date(from: comps) else { return }
            if next < today { next = cal.date(byAdding: .year, value: 1, to: next) ?? next }
            let days = cal.dateComponents([.day], from: today, to: next).day ?? 0
            let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            result.append(Birthday(id: contact.identifier, name: name, firstName: contact.givenName.isEmpty ? name : contact.givenName,
                                   next: next, daysUntil: days))
        }
        return result
    }

    private func scheduleNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("bday-") }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        for b in upcoming.prefix(20) {
            for (offset, hour, text) in [(-3, 10, "In 3 Tagen hat \(b.name) Geburtstag."),
                                         (0, 9, "Heute hat \(b.name) Geburtstag. Der Glückwunsch ist fertig.")] {
                guard let day = Calendar.current.date(byAdding: .day, value: offset, to: b.next),
                      let fire = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day),
                      fire > .now else { continue }
                let content = UNMutableNotificationContent()
                content.title = "Geburtstag"
                content.body = text
                content.sound = .default
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                try? await center.add(UNNotificationRequest(identifier: "bday-\(b.id)-\(offset)", content: content,
                                                            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
            }
        }
    }

    /// Am Geburtstag liegt der Glückwunsch fertig unter „Antworten“, Senden mit einem Tipp.
    private func createGreetingsForToday(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<ReplyItem>())) ?? []
        for b in upcoming where b.daysUntil == 0 {
            let already = existing.contains { $0.person == b.name && Calendar.current.isDateInToday($0.received) }
            guard !already else { continue }
            let draft = "Alles Gute zum Geburtstag, \(b.firstName)! 🎉 Ich wünsch dir einen richtig schönen Tag und ein super neues Lebensjahr. Lass dich feiern!"
            context.insert(ReplyItem(person: b.name, channel: "WhatsApp", incoming: "Geburtstag heute", draft: draft))
        }
        try? context.save()
    }
}
