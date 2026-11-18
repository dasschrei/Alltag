import SwiftUI
import SwiftData

struct HeuteView: View {
    @Binding var showSettings: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Query(filter: #Predicate<TaskItem> { !$0.done }, sort: \TaskItem.created) private var tasks: [TaskItem]
    @State private var showMiniStep = false
    @State private var newTask = false
    private let calendar = CalendarService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                nextStepCard
                section("Termine heute") {
                    let events = calendar.events(on: .now)
                    if events.isEmpty {
                        Text(calendar.authorized ? "Heute keine Termine." : "Kalender noch nicht freigegeben.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(events, id: \.eventIdentifier) { ev in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(ev.isAllDay ? "ganztg." : ev.startDate.formatted(date: .omitted, time: .shortened))
                                    .font(.body.monospacedDigit().weight(.semibold))
                                    .frame(width: 60, alignment: .leading)
                                Text(ev.title ?? "")
                            }
                        }
                    }
                }
                let birthdays = BirthdayService.shared.upcoming.filter { $0.daysUntil <= 7 }
                if !birthdays.isEmpty {
                    section("Geburtstage") {
                        ForEach(birthdays) { b in
                            HStack {
                                Text("🎂")
                                Text(b.name).font(.body.weight(.medium))
                                Spacer()
                                Text(b.daysUntil == 0 ? "heute" : (b.daysUntil == 1 ? "morgen" : "in \(b.daysUntil) Tagen"))
                                    .foregroundStyle(b.daysUntil == 0 ? Theme.warn : .secondary)
                            }
                        }
                    }
                }
                section("Drei Dinge für heute") {
                    if tasks.isEmpty {
                        Text("Nichts offen. Sag einfach, was ansteht.").foregroundStyle(.secondary)
                    }
                    ForEach(tasks.prefix(3)) { task in
                        HStack(alignment: .top, spacing: 12) {
                            Button {
                                task.done = true
                                try? context.save()
                            } label: {
                                Image(systemName: "circle").font(.title2)
                            }
                            .buttonStyle(.plain)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                HStack {
                                    Chip(text: task.area.rawValue, color: task.area.color)
                                    if task.snoozeCount > 1 { Chip(text: "\(task.snoozeCount)× verschoben", color: Theme.warn) }
                                }
                            }
                        }
                    }
                    if tasks.count > 3 {
                        Text("\(tasks.count - 3) weitere warten im Hintergrund.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                NavigationLink {
                    TaskListView()
                } label: {
                    Label("Alle Aufgaben", systemImage: "list.bullet")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding()
            .padding(.bottom, 80)
        }
        .navigationTitle("Heute")
        .sheet(isPresented: $newTask) { TaskEditView(task: nil) }
        .toolbar {
            Button { newTask = true } label: { Image(systemName: "plus") }
                .accessibilityLabel("Neue Aufgabe")
            Button { AppState.shared.showAbendCheck = true } label: { Image(systemName: "moon.stars") }
                .accessibilityLabel("Abend-Check")
            Button { showSettings = true } label: { Image(systemName: "gearshape") }
        }
    }

    @ViewBuilder
    private var nextStepCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("JETZT ALS NÄCHSTES").font(.caption.weight(.semibold)).opacity(0.75)
            if let task = tasks.first {
                Text(task.title).font(.title.weight(.heavy))
                if task.snoozeCount > 1 {
                    Text("Schon \(task.snoozeCount)× verschoben. Fang einfach klein an.").opacity(0.85)
                }
                if showMiniStep, let step = task.steps.first {
                    Text("Erster Mini-Schritt: \(step)").padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }
                HStack {
                    Button("Erledigt") { task.done = true; showMiniStep = false; try? context.save() }
                        .buttonStyle(.borderedProminent).tint(Theme.accent).foregroundStyle(.black)
                    if !showMiniStep && !task.steps.isEmpty {
                        Button("Zu groß?") { showMiniStep = true }.buttonStyle(.bordered).tint(.white)
                    }
                    Button("Später") {
                        task.snoozeCount += 1
                        task.created = .now
                        showMiniStep = false
                        try? context.save()
                    }
                    .buttonStyle(.bordered).tint(.white)
                }
            } else {
                Text("Alles erledigt.").font(.title.weight(.heavy))
                Text("Drück die Aktionstaste und sag, was als Nächstes ansteht.").opacity(0.85)
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.deep, in: RoundedRectangle(cornerRadius: 22))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
    }
}
