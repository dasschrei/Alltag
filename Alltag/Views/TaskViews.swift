import SwiftUI
import SwiftData

/// Aufgabe per Hand anlegen oder bearbeiten.
struct TaskEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var task: TaskItem?

    @State private var title = ""
    @State private var area: Area = .privat
    @State private var hasDue = false
    @State private var due = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: .now) ?? .now
    @State private var steps = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Was ist zu tun?", text: $title, axis: .vertical)
                    Picker("Bereich", selection: $area) {
                        ForEach(Area.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Toggle("Fällig am", isOn: $hasDue.animation())
                    if hasDue { DatePicker("Wann", selection: $due) }
                }
                Section {
                    TextField("Ein Schritt pro Zeile (optional)", text: $steps, axis: .vertical)
                        .lineLimit(2...6)
                } header: { Text("Kleine Schritte") }
                if task != nil {
                    Section {
                        Button("Aufgabe löschen", role: .destructive) {
                            if let task { context.delete(task); try? context.save() }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(task == nil ? "Neue Aufgabe" : "Aufgabe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save).disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard let task else { return }
                title = task.title
                area = task.area
                hasDue = task.due != nil
                if let d = task.due { due = d }
                steps = task.steps.joined(separator: "\n")
            }
        }
    }

    private func save() {
        let stepList = steps.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let task {
            task.title = name
            task.areaRaw = area.rawValue
            task.due = hasDue ? due : nil
            task.steps = stepList
        } else {
            context.insert(TaskItem(title: name, area: area, steps: stepList, due: hasDue ? due : nil))
        }
        try? context.save()
        dismiss()
    }
}

/// Alle Aufgaben, nach Bereich, mit Erledigt, Bearbeiten und Löschen.
struct TaskListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TaskItem.created) private var all: [TaskItem]
    @State private var area: Area? = nil
    @State private var editing: TaskItem?
    @State private var creating = false
    @State private var showDone = false

    var body: some View {
        let open = all.filter { !$0.done && (area == nil || $0.area == area) }
        let done = all.filter { $0.done && (area == nil || $0.area == area) }.suffix(30)
        List {
            Picker("Bereich", selection: $area) {
                Text("Alle").tag(Area?.none)
                ForEach(Area.allCases) { Text($0.rawValue).tag(Area?.some($0)) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            Section("Offen (\(open.count))") {
                if open.isEmpty { Text("Nichts offen.").foregroundStyle(.secondary) }
                ForEach(open) { task in row(task) }
            }
            if !done.isEmpty {
                Section {
                    DisclosureGroup("Erledigt (\(done.count))", isExpanded: $showDone) {
                        ForEach(Array(done)) { task in row(task) }
                    }
                }
            }
        }
        .navigationTitle("Aufgaben")
        .toolbar {
            Button { creating = true } label: { Image(systemName: "plus") }
                .accessibilityLabel("Neue Aufgabe")
        }
        .sheet(isPresented: $creating) { TaskEditView(task: nil) }
        .sheet(item: $editing) { TaskEditView(task: $0) }
    }

    private func row(_ task: TaskItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                task.done.toggle(); try? context.save()
            } label: {
                Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(task.done ? Theme.deep : .secondary)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title).strikethrough(task.done).foregroundStyle(task.done ? .secondary : .primary)
                HStack(spacing: 6) {
                    Chip(text: task.area.rawValue, color: task.area.color)
                    if let due = task.due {
                        Chip(text: due.formatted(.dateTime.day().month().hour().minute()),
                             color: due < .now && !task.done ? Theme.warn : .secondary)
                    }
                }
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { editing = task }
        .swipeActions {
            Button("Löschen", role: .destructive) { context.delete(task); try? context.save() }
        }
    }
}
