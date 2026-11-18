import Foundation
import SwiftData

/// Nimmt ein Diktat, lässt Claude es verstehen und legt alles an der richtigen Stelle ab.
@MainActor
enum CommandProcessor {

    struct Outcome {
        var reply: String
        var draftsToSend: [ReplyItem]
    }

    static func handle(_ text: String, source: String, incoming: String = "", in context: ModelContext) async -> Outcome {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Outcome(reply: "Ich habe nichts verstanden.", draftsToSend: []) }

        let calendar = CalendarService.shared
        let projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        let openReplies = ((try? context.fetch(FetchDescriptor<ReplyItem>())) ?? []).filter { !$0.done }
        let openTasks = ((try? context.fetch(FetchDescriptor<TaskItem>())) ?? []).filter { !$0.done }
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now

        let ctx = AssistantContext(
            now: .now,
            projectNames: projects.map { "\($0.name) (\($0.area.rawValue))" },
            openReplies: openReplies.map { "\($0.person) über \($0.channel), seit \($0.received.formatted(.relative(presentation: .named)))" },
            openTasks: openTasks.map { $0.title },
            todaysEvents: calendar.summary(for: .now),
            tomorrowsEvents: calendar.summary(for: tomorrow)
        )

        let interpretation: Interpretation
        do {
            interpretation = try await ClaudeService.shared.interpret(trimmed, context: ctx)
        } catch {
            // Nichts geht verloren: das Diktat landet als Idee auf dem Parkplatz.
            context.insert(Idea(text: trimmed, area: .privat))
            context.insert(InboxEntry(text: trimmed, source: source, answer: "Offline gespeichert"))
            try? context.save()
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return Outcome(reply: "Notiert, aber noch nicht sortiert. \(message)", draftsToSend: [])
        }

        var drafts: [ReplyItem] = []
        var knownProjects = projects

        for action in interpretation.actions {
            let area = Area(rawValue: action.area) ?? .privat
            switch action.type {
            case "task":
                context.insert(TaskItem(title: action.title, area: area, steps: action.steps))
            case "event":
                if let start = parseDate(action.start) {
                    calendar.addEvent(title: action.title, start: start, minutes: action.durationMinutes)
                } else {
                    context.insert(TaskItem(title: action.title, area: area))
                }
            case "reply_draft":
                let item = ReplyItem(person: action.person, channel: action.channel.isEmpty ? "WhatsApp" : action.channel,
                                     incoming: incoming, draft: action.message)
                context.insert(item)
                drafts.append(item)
            case "new_project":
                if !knownProjects.contains(where: { $0.name.caseInsensitiveCompare(action.title) == .orderedSame }) {
                    let project = Project(name: action.title, area: area)
                    context.insert(project)
                    knownProjects.append(project)
                }
            case "idea":
                let project = knownProjects.first { $0.name.caseInsensitiveCompare(action.projectName) == .orderedSame }
                context.insert(Idea(text: action.title, area: project?.area ?? area, project: project))
            default:
                break
            }
        }

        context.insert(InboxEntry(text: trimmed, source: source, answer: interpretation.reply))
        try? context.save()
        return Outcome(reply: interpretation.reply, draftsToSend: drafts.filter { !$0.draft.isEmpty })
    }

    private static func parseDate(_ string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        let full = ISO8601DateFormatter()
        if let d = full.date(from: string) { return d }
        let noZone = DateFormatter()
        noZone.locale = Locale(identifier: "en_US_POSIX")
        noZone.timeZone = TimeZone(identifier: "Europe/Vienna")
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd"] {
            noZone.dateFormat = format
            if let d = noZone.date(from: string) { return d }
        }
        return nil
    }
}

/// Öffnet WhatsApp oder Mail mit fertigem Text. Gesendet wird erst nach Jakobs Tipp.
enum Sender {
    static func url(for reply: ReplyItem) -> URL? {
        let text = reply.draft.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if reply.isWhatsApp {
            return URL(string: "whatsapp://send?text=\(text)")
        }
        return URL(string: "mailto:?body=\(text)")
    }
}
