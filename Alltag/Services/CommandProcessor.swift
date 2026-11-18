import Foundation
import SwiftData

/// Nimmt ein Diktat, lässt Apple Intelligence es verstehen und legt alles an der richtigen Stelle ab.
@MainActor
enum CommandProcessor {

    struct Outcome {
        var reply: String
    }

    static func handle(_ text: String, source: String, in context: ModelContext) async -> Outcome {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Outcome(reply: "Ich habe nichts verstanden.") }

        let calendar = CalendarService.shared
        let projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        let openTasks = ((try? context.fetch(FetchDescriptor<TaskItem>())) ?? []).filter { !$0.done }
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now

        let ctx = BrainContext(
            now: .now,
            projectNames: projects.map { "\($0.name) (\($0.area.rawValue))" },
            openTasks: openTasks.prefix(15).map { $0.title },
            todaysEvents: calendar.summary(for: .now),
            tomorrowsEvents: calendar.summary(for: tomorrow)
        )

        let result: LocalInterpretation
        do {
            result = try await LocalBrain.interpret(trimmed, context: ctx)
        } catch {
            // Nichts geht verloren: das Diktat landet als Idee auf dem Parkplatz.
            context.insert(Idea(text: trimmed, area: .privat))
            context.insert(InboxEntry(text: trimmed, source: source, answer: "Auf den Parkplatz gelegt"))
            try? context.save()
            let message = (error as? LocalizedError)?.errorDescription ?? "Konnte es nicht sortieren."
            return Outcome(reply: "Notiert, liegt auf dem Ideen-Parkplatz. \(message)")
        }

        var knownProjects = projects
        var answer = result.reply

        for action in result.actions {
            let area: Area = action.area == .arbeit ? .arbeit : .privat
            let title = action.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty || action.kind == .frage else { continue }
            switch action.kind {
            case .aufgabe:
                context.insert(TaskItem(title: title, area: area, steps: action.steps))
            case .termin:
                if let start = LocalBrain.detectDate(in: trimmed), calendar.addEvent(title: title, start: start,
                                                                                    minutes: action.durationMinutes > 0 ? action.durationMinutes : 60) {
                    answer = "Termin eingetragen: \(start.formatted(.dateTime.weekday(.wide).day().month().hour().minute()))."
                } else {
                    context.insert(TaskItem(title: title, area: area, due: LocalBrain.detectDate(in: trimmed)))
                }
            case .neuesProjekt:
                if !knownProjects.contains(where: { $0.name.caseInsensitiveCompare(title) == .orderedSame }) {
                    let project = Project(name: title, area: area)
                    context.insert(project)
                    knownProjects.append(project)
                }
            case .idee:
                let project = knownProjects.first { !action.projectName.isEmpty && $0.name.localizedCaseInsensitiveContains(action.projectName) }
                context.insert(Idea(text: title, area: project?.area ?? area, project: project))
            case .frage:
                break
            }
        }

        context.insert(InboxEntry(text: trimmed, source: source, answer: answer))
        try? context.save()
        return Outcome(reply: answer.isEmpty ? "Notiert." : answer)
    }
}
