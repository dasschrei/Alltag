import Foundation
import CoreLocation
import UserNotifications
import AlarmKit
import SwiftUI

/// Abend-Check: 5 Minuten nach dem Heimkommen fragen, wann Jakob morgen wo sein will,
/// dann Losgeh-Zeit berechnen, Wecker stellen und rechtzeitig erinnern.
@MainActor
@Observable
final class AbendCheckService: NSObject, CLLocationManagerDelegate {
    static let shared = AbendCheckService()

    private let manager = CLLocationManager()
    private var monitor: CLMonitor?
    var locationStatus: CLAuthorizationStatus = .notDetermined
    var homeSet: Bool { Places.home != nil }

    struct Plan: Equatable {
        var arrival: Date
        var destination: String
        var transgourmet: Bool
        var travelMinutes: Int
        var departure: Date
        var wakeUp: Date
    }

    private override init() {
        super.init()
        manager.delegate = self
        locationStatus = manager.authorizationStatus
    }

    // MARK: Zuhause und Standort

    func requestLocation() {
        manager.requestAlwaysAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.locationStatus = status }
    }

    /// Den aktuellen Standort als Zuhause speichern.
    func setHomeHere() async -> Bool {
        manager.requestAlwaysAuthorization()
        let updates = CLLocationUpdate.liveUpdates()
        do {
            for try await update in updates {
                if let loc = update.location, loc.horizontalAccuracy < 100 {
                    Places.home = loc.coordinate
                    await startMonitoring()
                    return true
                }
            }
        } catch {}
        return false
    }

    /// Beim App-Start aufrufen: beobachtet, wann Jakob nach Hause kommt.
    func startMonitoring() async {
        guard let home = Places.home else { return }
        let monitor = await CLMonitor("abendcheck")
        self.monitor = monitor
        for id in await monitor.identifiers { await monitor.remove(id) }
        await monitor.add(CLMonitor.CircularGeographicCondition(center: home, radius: 150),
                          identifier: "home", assuming: .satisfied)
        Task {
            do {
                for try await event in await monitor.events where event.state == .satisfied {
                    await self.arrivedHome()
                }
            } catch {}
        }
    }

    private func arrivedHome() async {
        let now = Date.now
        let hour = Calendar.current.component(.hour, from: now)
        // Nur abends/nachts und höchstens einmal pro Abend.
        guard hour >= 14 || hour < 5 else { return }
        if let last = Places.lastCheck, now.timeIntervalSince(last) < 10 * 3600 { return }
        Places.lastCheck = now

        let content = UNMutableNotificationContent()
        content.title = "Abend-Check"
        content.body = Places.asksTransgourmet()
            ? "Kurz für morgen planen: Wann willst du in der Arbeit sein? Und zu Transgourmet?"
            : "Kurz für morgen planen: Wann willst du in der Arbeit sein?"
        content.sound = .default
        content.userInfo = ["open": "abendcheck"]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5 * 60, repeats: false)
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "abendcheck", content: content, trigger: trigger))
    }

    // MARK: Planen

    /// Die Morgen-Situation: erster Termin (mit Uhrzeit) oder Arbeitsbeginn.
    func tomorrowFirstEvent() -> (title: String, start: Date, location: String?)? {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        guard let ev = CalendarService.shared.events(on: tomorrow).first(where: { !$0.isAllDay }) else { return nil }
        return (ev.title ?? "Termin", ev.startDate, ev.location)
    }

    func calculate(arrival: Date, destination: String, transgourmet: Bool) async -> Plan {
        let home = Travel.homeItem()
        var travel = 25 // Annahme, falls Karten nicht erreichbar
        if let dest = await Travel.mapItem(for: destination) {
            if transgourmet, let shop = await Travel.mapItem(for: Places.transgourmet) {
                let shopArrival = arrival.addingTimeInterval(-Double(Places.shoppingMinutes + 20) * 60)
                let a = await Travel.minutes(from: home, to: shop, arrival: shopArrival) ?? 15
                let b = await Travel.minutes(from: shop, to: dest, arrival: arrival) ?? 15
                travel = a + b
            } else if let t = await Travel.minutes(from: home, to: dest, arrival: arrival) {
                travel = t
            }
        }
        let total = travel + Places.bufferMinutes + (transgourmet ? Places.shoppingMinutes : 0)
        let departure = arrival.addingTimeInterval(-Double(total) * 60)
        let wake = departure.addingTimeInterval(-Double(Places.getReadyMinutes) * 60)
        return Plan(arrival: arrival, destination: destination, transgourmet: transgourmet,
                    travelMinutes: travel, departure: departure, wakeUp: wake)
    }

    // MARK: Umsetzen

    /// Wecker stellen und Losgeh-Erinnerungen planen. Ergebnis: Text für die Bestätigung.
    func apply(_ plan: Plan) async -> String {
        var parts: [String] = []
        if await scheduleAlarm(at: plan.wakeUp) {
            parts.append("Wecker \(plan.wakeUp.formatted(date: .omitted, time: .shortened))")
        } else {
            parts.append("Wecker konnte nicht gestellt werden")
        }
        await scheduleReminders(for: plan)
        parts.append("los um \(plan.departure.formatted(date: .omitted, time: .shortened))")
        return parts.joined(separator: ", ") + "."
    }

    private func scheduleAlarm(at date: Date) async -> Bool {
        let alarms = AlarmManager.shared
        do {
            let state = try await alarms.requestAuthorization()
            guard state == .authorized else { return false }
            for alarm in (try? alarms.alarms) ?? [] { try? alarms.cancel(id: alarm.id) }
            let alert = AlarmPresentation.Alert(title: "Guten Morgen", stopButton: .stopButton)
            let attributes = AlarmAttributes<WakeMetadata>(presentation: AlarmPresentation(alert: alert),
                                                           tintColor: Theme.deep)
            let config = AlarmManager.AlarmConfiguration<WakeMetadata>.alarm(schedule: .fixed(date),
                                                                             attributes: attributes)
            _ = try await alarms.schedule(id: UUID(), configuration: config)
            return true
        } catch {
            return false
        }
    }

    private func scheduleReminders(for plan: Plan) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["los10", "los0"])
        let where_ = plan.transgourmet ? "Transgourmet, dann \(plan.destination)" : plan.destination
        for (id, minutes, title) in [("los10", 10, "In 10 Min los"), ("los0", 0, "Jetzt los")] {
            let date = plan.departure.addingTimeInterval(-Double(minutes) * 60)
            guard date > .now else { continue }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = "\(where_). Ankunft \(plan.arrival.formatted(date: .omitted, time: .shortened))."
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            try? await center.add(UNNotificationRequest(identifier: id, content: content,
                                                        trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
    }
}

struct WakeMetadata: AlarmMetadata {}

extension AlarmButton {
    static var stopButton: AlarmButton {
        AlarmButton(text: "Aus", textColor: .white, systemImageName: "stop.circle")
    }
}
