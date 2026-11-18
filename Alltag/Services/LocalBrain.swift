import Foundation
import FoundationModels

/// Versteht Diktate kostenlos und offline mit Apple Intelligence (Modell direkt auf dem iPhone).
@Generable
enum ActionKind {
    case aufgabe, termin, neuesProjekt, idee, frage
}

@Generable
enum AreaChoice {
    case arbeit, privat
}

@Generable
struct LocalAction {
    @Guide(description: "Art der Aktion")
    var kind: ActionKind
    @Guide(description: "Kurzer Titel auf Deutsch, z. B. 'Steuerberater anrufen' oder Projektname oder der Ideentext")
    var title: String
    @Guide(description: "arbeit für alles rund ums Restaurant, sonst privat")
    var area: AreaChoice
    @Guide(description: "Bei größeren Aufgaben 2 bis 3 kleine erste Schritte, sonst leer", .maximumCount(3))
    var steps: [String]
    @Guide(description: "Nur bei Idee: Name des passenden bestehenden Projekts, sonst leer")
    var projectName: String
    @Guide(description: "Nur bei Termin: Dauer in Minuten, sonst 0")
    var durationMinutes: Int
}

@Generable
struct LocalInterpretation {
    @Guide(description: "Kurze Antwort zum Vorlesen, auf Deutsch in Du-Form. Bei Notizen nur 'Notiert.'")
    var reply: String
    @Guide(description: "Alle Aktionen aus dem Diktat", .maximumCount(5))
    var actions: [LocalAction]
}

struct BrainContext {
    var now: Date
    var projectNames: [String]
    var openTasks: [String]
    var todaysEvents: [String]
    var tomorrowsEvents: [String]
}

enum BrainError: LocalizedError {
    case unavailable(String)
    var errorDescription: String? {
        if case .unavailable(let why) = self { return why }
        return nil
    }
}

@MainActor
enum LocalBrain {
    static var availabilityText: String {
        switch SystemLanguageModel.default.availability {
        case .available: return "Bereit (auf dem iPhone, kostenlos)"
        case .unavailable(.appleIntelligenceNotEnabled): return "Apple Intelligence ist aus. Einstellungen → Apple Intelligence & Siri einschalten."
        case .unavailable(.modelNotReady): return "Apple Intelligence lädt noch, bitte später nochmal."
        case .unavailable(.deviceNotEligible): return "Dieses iPhone unterstützt Apple Intelligence nicht."
        default: return "Apple Intelligence ist gerade nicht verfügbar."
        }
    }

    static func interpret(_ text: String, context c: BrainContext) async throws -> LocalInterpretation {
        guard case .available = SystemLanguageModel.default.availability else {
            throw BrainError.unavailable(availabilityText)
        }
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt(text, c), generating: LocalInterpretation.self)
        return response.content
    }

    private static let instructions = """
    Du bist der persönliche Assistent von Jakob, Gastronom (Restaurant Das Schrei, Salzburg). \
    Jakob diktiert, du sortierst. Keine Rückfragen. Erfinde nichts.
    Aktionen:
    - aufgabe: etwas zu erledigen.
    - termin: etwas mit Tag oder Uhrzeit.
    - neuesProjekt: Jakob sagt "neues Projekt". title = Projektname.
    - idee: ein Einfall. projectName = passendes bestehendes Projekt oder leer.
    - frage: Jakob fragt etwas. Beantworte es kurz in reply, nur aus dem Kontext.
    """

    private static func prompt(_ text: String, _ c: BrainContext) -> String {
        func list(_ items: [String]) -> String { items.isEmpty ? "keine" : items.joined(separator: "; ") }
        return """
        Jetzt: \(c.now.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute().locale(Locale(identifier: "de_AT"))))
        Projekte: \(list(c.projectNames))
        Offene Aufgaben: \(list(c.openTasks))
        Termine heute: \(list(c.todaysEvents))
        Termine morgen: \(list(c.tomorrowsEvents))

        Diktat: \(text)
        """
    }

    /// Datum und Uhrzeit zuverlässig aus dem Originaltext lesen (Apples Datumserkennung, ebenfalls kostenlos).
    static func detectDate(in text: String) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        return detector.firstMatch(in: text, options: [], range: range)?.date
    }
}
