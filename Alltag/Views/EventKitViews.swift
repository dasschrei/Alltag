import SwiftUI
import EventKit
import EventKitUI

/// Apples eigener Termin-Editor: Titel, Ort, Uhrzeit, Wiederholung, Erinnerung, Notiz.
struct EventEditor: UIViewControllerRepresentable {
    var event: EKEvent?
    var day: Date
    var onDone: () -> Void

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = CalendarService.shared.store
        let vc = EKEventEditViewController()
        vc.eventStore = store
        if let event {
            vc.event = event
        } else {
            let ev = EKEvent(eventStore: store)
            let cal = Calendar.current
            let hour = cal.isDateInToday(day) ? min(cal.component(.hour, from: .now) + 1, 22) : 10
            ev.startDate = cal.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
            ev.endDate = ev.startDate.addingTimeInterval(3600)
            ev.calendar = store.defaultCalendarForNewEvents
            vc.event = ev
        }
        vc.editViewDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: EKEventEditViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            Task { @MainActor in CalendarService.shared.changed() }
            onDone()
        }
    }
}

/// Apples Termin-Detailansicht mit Bearbeiten und Löschen.
struct EventDetail: UIViewControllerRepresentable {
    var event: EKEvent
    var onDone: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let vc = EKEventViewController()
        vc.event = event
        vc.allowsEditing = true
        vc.allowsCalendarPreview = true
        vc.delegate = context.coordinator
        vc.navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { _ in
            onDone()
        })
        return UINavigationController(rootViewController: vc)
    }

    func updateUIViewController(_ vc: UINavigationController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    final class Coordinator: NSObject, EKEventViewDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }
        func eventViewController(_ controller: EKEventViewController, didCompleteWith action: EKEventViewAction) {
            Task { @MainActor in CalendarService.shared.changed() }
            onDone()
        }
    }
}

extension EKEvent: @retroactive Identifiable {
    public var id: String { (eventIdentifier ?? "") + "\(startDate.timeIntervalSince1970)" }
}
