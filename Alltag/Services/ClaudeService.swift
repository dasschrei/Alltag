import Foundation

/// Was Claude aus einem Diktat macht.
struct Interpretation: Codable {
    /// Kurze gesprochene Antwort, meist nur "Notiert".
    var reply: String
    var actions: [AssistantAction]
}

struct AssistantAction: Codable {
    /// task | event | reply_draft | new_project | idea | none
    var type: String
    var title: String
    var area: String
    var steps: [String]
    /// ISO-8601 Datum mit Uhrzeit, leer wenn nicht nötig
    var start: String
    var durationMinutes: Int
    var person: String
    var channel: String
    var message: String
    var projectName: String
}

/// Kontext, den Claude für Fragen braucht.
struct AssistantContext {
    var now: Date
    var projectNames: [String]
    var openReplies: [String]
    var openTasks: [String]
    var todaysEvents: [String]
    var tomorrowsEvents: [String]
}

enum ClaudeError: LocalizedError {
    case missingKey
    case http(Int, String)
    case refused
    case badResponse

    var errorDescription: String? {
        switch self {
        case .missingKey: return "Bitte zuerst in den Einstellungen den Claude-Schlüssel eintragen."
        case .http(let code, let body): return "Claude antwortet mit Fehler \(code): \(body.prefix(200))"
        case .refused: return "Claude hat diese Anfrage abgelehnt."
        case .badResponse: return "Die Antwort von Claude war nicht lesbar."
        }
    }
}

/// Spricht über die Messages-Schnittstelle mit Claude (Swift hat kein offizielles SDK).
actor ClaudeService {
    static let shared = ClaudeService()

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-opus-5-5"

    func interpret(_ text: String, context: AssistantContext) async throws -> Interpretation {
        guard let key = KeychainStore.get("anthropic_api_key"), !key.isEmpty else {
            throw ClaudeError.missingKey
        }

        let format: [String: Any] = ["type": "json_schema", "schema": Self.schema]
        let outputConfig: [String: Any] = ["effort": "low", "format": format]
        let messages: [[String: String]] = [
            ["role": "user", "content": Self.userMessage(text, context: context)]
        ]
        var body: [String: Any] = [:]
        body["model"] = model
        body["max_tokens"] = 8000
        // Schnelle Antworten für den Sprachassistenten.
        body["output_config"] = outputConfig
        // Falls das Modell eine Anfrage ablehnt, springt automatisch ein anderes ein.
        body["fallbacks"] = "default"
        body["system"] = Self.systemPrompt
        body["messages"] = messages

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw ClaudeError.http(status, String(data: data, encoding: .utf8) ?? "")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeError.badResponse
        }
        if (json["stop_reason"] as? String) == "refusal" { throw ClaudeError.refused }

        let blocks = json["content"] as? [[String: Any]] ?? []
        let text = blocks
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
        guard let textData = text.data(using: .utf8) else { throw ClaudeError.badResponse }
        do {
            return try JSONDecoder().decode(Interpretation.self, from: textData)
        } catch {
            throw ClaudeError.badResponse
        }
    }

    // MARK: - Prompt

    private static let systemPrompt = """
    Du bist der persönliche Assistent von Jakob, Gastronom (Restaurant Das Schrei in Salzburg). \
    Jakob diktiert dir per Sprache. Dein Ziel: Er soll organisiert sein, ohne sich organisieren zu müssen. \
    Er will den Kopf frei bekommen, also stellst du keine Rückfragen.

    Wandle jedes Diktat in Aktionen um:
    - task: eine Aufgabe. Zerlege größere Aufgaben in 2 bis 4 kleine, konkrete erste Schritte (steps).
    - event: ein Termin mit Startzeit (start, ISO-8601 mit Zeitzone Europe/Vienna) und Dauer in Minuten.
    - reply_draft: Jakob will jemandem antworten oder schreiben. Formuliere die fertige Nachricht in message, \
    im Ton passend zur Person (Freunde locker, Händler freundlich-geschäftlich, Ämter höflich). \
    channel ist "WhatsApp" oder "Mail" (Standard WhatsApp). Wenn der Inhalt fehlt, leeres message.
    - new_project: Jakob sagt "neues Projekt". title = Projektname.
    - idea: eine Idee. projectName = passendes bestehendes oder gerade angelegtes Projekt; \
    wenn unklar, leer lassen (dann landet sie auf dem Ideen-Parkplatz).
    - none: reine Frage, keine Aktion.
    area ist "Arbeit" für alles rund ums Restaurant, sonst "Privat".

    reply: Was du Jakob vorliest. Bei reinen Notizen nur "Notiert." oder sehr kurz bestätigen, wohin es kam. \
    Bei Fragen beantworte sie kurz aus dem Kontext (höchstens 3 Sätze, Deutsch, Du-Form). \
    Erfinde keine Fakten, die nicht im Kontext stehen.
    Beginnt das Diktat mit "Geteilte Nachricht:", hat Jakob eine empfangene Nachricht (meist WhatsApp) geteilt. \
    Erstelle dann genau ein reply_draft: person = Absender, falls erkennbar (sonst "Unbekannt"), \
    message = ein passender Antwortvorschlag in Jakobs Namen. Termine oder Aufgaben darin zusätzlich als event/task.
    Alle Felder müssen gesetzt sein; nicht benötigte Felder sind leere Strings, leere Listen oder 0.
    """

    private static func userMessage(_ text: String, context c: AssistantContext) -> String {
        let df = ISO8601DateFormatter()
        df.timeZone = TimeZone(identifier: "Europe/Vienna")
        func list(_ items: [String]) -> String { items.isEmpty ? "(keine)" : items.map { "- \($0)" }.joined(separator: "\n") }
        return """
        Jetzt: \(df.string(from: c.now))

        Projekte:
        \(list(c.projectNames))

        Offene Antworten:
        \(list(c.openReplies))

        Offene Aufgaben:
        \(list(c.openTasks))

        Termine heute:
        \(list(c.todaysEvents))

        Termine morgen:
        \(list(c.tomorrowsEvents))

        Diktat von Jakob:
        \(text)
        """
    }

    private static let schemaJSON = """
    {
      "type": "object",
      "additionalProperties": false,
      "required": ["reply", "actions"],
      "properties": {
        "reply": {"type": "string"},
        "actions": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": ["type", "title", "area", "steps", "start", "durationMinutes",
                         "person", "channel", "message", "projectName"],
            "properties": {
              "type": {"type": "string", "enum": ["task", "event", "reply_draft", "new_project", "idea", "none"]},
              "title": {"type": "string"},
              "area": {"type": "string", "enum": ["Arbeit", "Privat"]},
              "steps": {"type": "array", "items": {"type": "string"}},
              "start": {"type": "string"},
              "durationMinutes": {"type": "integer"},
              "person": {"type": "string"},
              "channel": {"type": "string"},
              "message": {"type": "string"},
              "projectName": {"type": "string"}
            }
          }
        }
      }
    }
    """

    private static let schema: [String: Any] = {
        let data = Data(schemaJSON.utf8)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }()
}
