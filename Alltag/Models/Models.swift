import Foundation
import SwiftData

enum Area: String, CaseIterable, Codable, Identifiable {
    case arbeit = "Arbeit"
    case privat = "Privat"
    var id: String { rawValue }
}

@Model
final class TaskItem {
    var title: String
    var areaRaw: String
    var done: Bool
    var snoozeCount: Int
    var steps: [String]
    var created: Date
    var due: Date?

    init(title: String, area: Area, steps: [String] = [], due: Date? = nil) {
        self.title = title
        self.areaRaw = area.rawValue
        self.done = false
        self.snoozeCount = 0
        self.steps = steps
        self.created = .now
        self.due = due
    }

    var area: Area { Area(rawValue: areaRaw) ?? .privat }
}

@Model
final class ReplyItem {
    var person: String
    var channel: String   // "WhatsApp" oder "Mail"
    var incoming: String  // Nachricht, auf die geantwortet wird (falls bekannt)
    var draft: String
    var received: Date
    var done: Bool

    init(person: String, channel: String, incoming: String, draft: String) {
        self.person = person
        self.channel = channel
        self.incoming = incoming
        self.draft = draft
        self.received = .now
        self.done = false
    }

    var isWhatsApp: Bool { channel.lowercased().contains("whatsapp") }
}

@Model
final class Project {
    var name: String
    var areaRaw: String
    var created: Date
    @Relationship(deleteRule: .cascade, inverse: \Idea.project)
    var ideas: [Idea] = []

    init(name: String, area: Area) {
        self.name = name
        self.areaRaw = area.rawValue
        self.created = .now
    }

    var area: Area { Area(rawValue: areaRaw) ?? .privat }
}

@Model
final class Idea {
    var text: String
    var areaRaw: String
    var created: Date
    var project: Project?

    init(text: String, area: Area, project: Project? = nil) {
        self.text = text
        self.areaRaw = area.rawValue
        self.created = .now
        self.project = project
    }

    var area: Area { Area(rawValue: areaRaw) ?? .privat }
}

/// Jedes Diktat wird gespeichert, damit die App sich alles merkt.
@Model
final class InboxEntry {
    var text: String
    var source: String
    var answer: String
    var created: Date

    init(text: String, source: String, answer: String) {
        self.text = text
        self.source = source
        self.answer = answer
        self.created = .now
    }
}
