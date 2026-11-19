import SwiftUI
import EventKit

/// Eigener Kalender: Monatsansicht zum Durchblättern (ganzes Jahr und weiter),
/// Termine mit allen Details, anlegen, bearbeiten, löschen. Synchron mit dem iPhone-Kalender.
struct KalenderView: View {
    private let calendar = CalendarService.shared
    private let cal = Calendar.current

    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)!.start
    @State private var selected = Calendar.current.startOfDay(for: .now)
    @State private var newEvent = false
    @State private var shownEvent: EKEvent?

    var body: some View {
        let _ = calendar.revision
        let monthEvents = eventsInMonth()
        List {
            Section {
                header
                weekdayRow
                grid(monthEvents)
            }
            .listRowSeparator(.hidden)

            Section(selected.formatted(.dateTime.weekday(.wide).day().month(.wide))) {
                if !calendar.authorized {
                    Text("Kein Zugriff auf den Kalender. Bitte in den iPhone-Einstellungen unter Datenschutz > Kalender erlauben.")
                        .foregroundStyle(.secondary)
                } else {
                    let events = calendar.events(on: selected)
                    if events.isEmpty {
                        Text("Keine Termine.").foregroundStyle(.secondary)
                    }
                    ForEach(events) { ev in
                        Button { shownEvent = ev } label: { EventRow(event: ev) }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button("Löschen", role: .destructive) { delete(ev) }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Kalender")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Heute") {
                    selected = cal.startOfDay(for: .now)
                    month = cal.dateInterval(of: .month, for: .now)!.start
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { newEvent = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Neuer Termin")
            }
        }
        .sheet(isPresented: $newEvent) {
            EventEditor(event: nil, day: selected) { newEvent = false }
                .ignoresSafeArea()
        }
        .sheet(item: $shownEvent) { ev in
            EventDetail(event: ev) { shownEvent = nil }
                .ignoresSafeArea()
        }
    }

    // MARK: Monat

    private var header: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year())).font(.title3.weight(.semibold))
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
        }
        .buttonStyle(.borderless)
        .padding(.vertical, 4)
    }

    private var weekdayRow: some View {
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let first = cal.firstWeekday - 1
        let ordered = Array(symbols[first...] + symbols[..<first])
        return HStack {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, s in
                Text(s).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
        }
    }

    private func grid(_ monthEvents: [EKEvent]) -> some View {
        let days = daysInGrid()
        let busy = Set(monthEvents.flatMap { ev -> [Date] in
            var out: [Date] = []
            let begin: Date = ev.startDate ?? .now
            var d = cal.startOfDay(for: begin)
            let end: Date = ev.endDate ?? begin
            while d < end || out.isEmpty { out.append(d); d = cal.date(byAdding: .day, value: 1, to: d)!; if out.count > 31 { break } }
            return out
        })
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
            ForEach(days, id: \.self) { day in
                let inMonth = cal.isDate(day, equalTo: month, toGranularity: .month)
                let isSel = cal.isDate(day, inSameDayAs: selected)
                let isToday = cal.isDateInToday(day)
                Button { selected = day; if !inMonth { month = cal.dateInterval(of: .month, for: day)!.start } } label: {
                    VStack(spacing: 3) {
                        Text(day.formatted(.dateTime.day()))
                            .font(.body.weight(isToday || isSel ? .bold : .regular))
                            .foregroundStyle(isSel ? .white : (isToday ? Theme.deep : (inMonth ? .primary : .secondary)))
                            .frame(width: 34, height: 34)
                            .background(isSel ? Theme.deep : .clear, in: Circle())
                        Circle().fill(busy.contains(day) ? Theme.accent : .clear).frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(inMonth ? 1 : 0.45)
                }
                .buttonStyle(.plain)
            }
        }
        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
            if v.translation.width < -40 { shift(1) } else if v.translation.width > 40 { shift(-1) }
        })
    }

    private func daysInGrid() -> [Date] {
        let start = month
        let weekday = cal.component(.weekday, from: start)
        let lead = (weekday - cal.firstWeekday + 7) % 7
        let gridStart = cal.date(byAdding: .day, value: -lead, to: start)!
        let count = cal.range(of: .day, in: .month, for: start)!.count
        let cells = Int(ceil(Double(lead + count) / 7.0)) * 7
        return (0..<cells).map { cal.date(byAdding: .day, value: $0, to: gridStart)! }
    }

    private func eventsInMonth() -> [EKEvent] {
        let start = cal.date(byAdding: .day, value: -7, to: month)!
        let end = cal.date(byAdding: .day, value: 45, to: month)!
        return calendar.events(from: start, to: end)
    }

    private func shift(_ months: Int) {
        month = cal.date(byAdding: .month, value: months, to: month)!
        selected = month
    }

    private func delete(_ ev: EKEvent) {
        try? calendar.store.remove(ev, span: .thisEvent)
        calendar.changed()
    }
}

struct EventRow: View {
    var event: EKEvent
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(cgColor: event.calendar?.cgColor ?? UIColor.systemTeal.cgColor))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title ?? "Termin").font(.body.weight(.semibold))
                Text(event.isAllDay ? "ganztägig"
                     : "\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline).foregroundStyle(.secondary)
                if let loc = event.location, !loc.isEmpty {
                    Label(loc, systemImage: "mappin").font(.caption).foregroundStyle(.secondary)
                }
                if let notes = event.notes, !notes.isEmpty {
                    Text(notes).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
