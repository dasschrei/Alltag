import SwiftUI
import EventKit

/// Eigene Kalenderansicht: eine Woche zum Durchblättern, Termine aus dem iPhone-Kalender.
struct KalenderView: View {
    @State private var selected = Calendar.current.startOfDay(for: .now)
    private let calendar = CalendarService.shared

    private var days: [Date] {
        (0..<14).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: .now)) }
    }

    var body: some View {
        let _ = calendar.revision
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        let isSel = Calendar.current.isDate(day, inSameDayAs: selected)
                        Button { selected = day } label: {
                            VStack(spacing: 2) {
                                Text(day.formatted(.dateTime.weekday(.abbreviated)))
                                    .font(.caption2)
                                Text(day.formatted(.dateTime.day()))
                                    .font(.headline)
                            }
                            .frame(width: 46, height: 56)
                            .background(isSel ? Theme.deep : Color(.secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(isSel ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            List {
                if !calendar.authorized {
                    Text("Kein Zugriff auf den Kalender. Bitte in den iPhone-Einstellungen unter Datenschutz > Kalender erlauben.")
                        .foregroundStyle(.secondary)
                } else {
                    let events = calendar.events(on: selected)
                    if events.isEmpty {
                        Text("Keine Termine. Sag einfach: „Termin morgen um 10 beim Steuerberater.“")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(events, id: \.eventIdentifier) { ev in
                        HStack(alignment: .top, spacing: 12) {
                            Text(ev.isAllDay ? "ganzt." : ev.startDate.formatted(date: .omitted, time: .shortened))
                                .font(.subheadline.monospacedDigit())
                                .frame(width: 54, alignment: .leading)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ev.title ?? "Termin").font(.body.weight(.medium))
                                if let loc = ev.location, !loc.isEmpty {
                                    Label(loc, systemImage: "mappin").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle(selected.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .navigationBarTitleDisplayMode(.inline)
    }
}
