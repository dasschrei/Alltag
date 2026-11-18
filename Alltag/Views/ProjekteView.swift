import SwiftUI
import SwiftData

/// Projekte mit Ideenlisten, getrennt nach Arbeit und Privat. Plus Ideen-Parkplatz.
struct ProjekteView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Project.created, order: .reverse) private var projects: [Project]
    @Query(filter: #Predicate<Idea> { $0.project == nil }, sort: \Idea.created, order: .reverse)
    private var parked: [Idea]
    @State private var area: Area = .arbeit
    @State private var newProjectName = ""
    @State private var showNew = false

    var body: some View {
        List {
            Section {
                Picker("Bereich", selection: $area) {
                    ForEach(Area.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section("Projekte") {
                let mine = projects.filter { $0.area == area }
                if mine.isEmpty {
                    Text("Noch keine Projekte. Sag: „Neues Projekt: Sommerkarte.“").foregroundStyle(.secondary)
                }
                ForEach(mine) { project in
                    NavigationLink(value: project) {
                        HStack {
                            Text(project.name)
                            Spacer()
                            Text("\(project.ideas.count)").foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { idx in
                    for i in idx { context.delete(mine[i]) }
                    try? context.save()
                }
            }
            let parkedHere = parked.filter { $0.area == area }
            if !parkedHere.isEmpty {
                Section("Ideen-Parkplatz") {
                    ForEach(parkedHere) { idea in
                        IdeaRow(idea: idea, projects: projects.filter { $0.area == area })
                    }
                    .onDelete { idx in
                        for i in idx { context.delete(parkedHere[i]) }
                        try? context.save()
                    }
                }
            }
        }
        .navigationTitle("Projekte")
        .navigationDestination(for: Project.self) { ProjectDetailView(project: $0) }
        .toolbar {
            Button { showNew = true } label: { Image(systemName: "plus") }
        }
        .alert("Neues Projekt", isPresented: $showNew) {
            TextField("Name", text: $newProjectName)
            Button("Anlegen") {
                let name = newProjectName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { context.insert(Project(name: name, area: area)); try? context.save() }
                newProjectName = ""
            }
            Button("Abbrechen", role: .cancel) { newProjectName = "" }
        }
    }
}

struct IdeaRow: View {
    @Environment(\.modelContext) private var context
    var idea: Idea
    var projects: [Project]

    var body: some View {
        HStack {
            Text(idea.text)
            Spacer()
            Menu {
                ForEach(projects) { project in
                    Button(project.name) { idea.project = project; try? context.save() }
                }
                Button("Als Aufgabe") {
                    context.insert(TaskItem(title: idea.text, area: idea.area))
                    context.delete(idea)
                    try? context.save()
                }
            } label: {
                Image(systemName: "arrow.turn.down.right")
            }
        }
    }
}

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var context
    var project: Project
    @State private var newIdea = ""

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Idee hinzufügen", text: $newIdea)
                        .onSubmit(add)
                    Button("Hinzufügen", action: add).disabled(newIdea.isEmpty)
                }
            }
            Section("Ideen") {
                let ideas = project.ideas.sorted { $0.created > $1.created }
                ForEach(ideas) { idea in
                    Text(idea.text)
                        .swipeActions {
                            Button("Aufgabe") {
                                context.insert(TaskItem(title: idea.text, area: project.area))
                                context.delete(idea)
                                try? context.save()
                            }.tint(Theme.deep)
                            Button("Löschen", role: .destructive) { context.delete(idea); try? context.save() }
                        }
                }
            }
        }
        .navigationTitle(project.name)
    }

    private func add() {
        let text = newIdea.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        context.insert(Idea(text: text, area: project.area, project: project))
        try? context.save()
        newIdea = ""
    }
}
