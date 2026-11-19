import Foundation
import SwiftData

/// Briefkasten zwischen Claude und der App: Claude sortiert Pocket-Aufnahmen in eine Notion-Tabelle,
/// die App holt neue Zeilen ab, legt sie an der richtigen Stelle an und hakt „Übernommen“ ab.
///
/// Spalten der Tabelle: Titel (Titel), Typ (Auswahl: Aufgabe/Termin/Idee/Projekt),
/// Bereich (Auswahl: Arbeit/Privat), Wann (Datum), Dauer (Zahl, Minuten),
/// Projekt (Text), Notiz (Text), Übernommen (Checkbox).
@MainActor
enum NotionInbox {
    static let tokenKey = "notion_token"
    private static let dbKey = "notionDatabaseID"

    static var databaseID: String {
        get { UserDefaults.standard.string(forKey: dbKey) ?? "" }
        set { UserDefaults.standard.set(cleanID(newValue), forKey: dbKey) }
    }
    static var isConfigured: Bool { KeychainStore.get(tokenKey) != nil && !databaseID.isEmpty }
    static var lastResult = ""

    /// Akzeptiert auch einen kompletten Notion-Link und zieht die 32-stellige ID heraus.
    static func cleanID(_ s: String) -> String {
        let hex = s.replacingOccurrences(of: "-", with: "")
        if let r = hex.range(of: "[0-9a-fA-F]{32}", options: .regularExpression) { return String(hex[r]) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @discardableResult
    static func sync(context: ModelContext) async -> Int {
        guard let token = KeychainStore.get(tokenKey), !databaseID.isEmpty else { return 0 }
        do {
            let rows = try await query(token: token)
            var projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
            var count = 0
            for row in rows {
                apply(row, context: context, projects: &projects)
                try await markDone(row.id, token: token)
                count += 1
            }
            try? context.save()
            lastResult = count == 0 ? "Verbunden, nichts Neues" : "\(count) neue Einträge übernommen"
            return count
        } catch {
            lastResult = "Fehler: \(error.localizedDescription)"
            return 0
        }
    }

    // MARK: Einsortieren

    private static func apply(_ r: Row, context: ModelContext, projects: inout [Project]) {
        let area: Area = r.area.lowercased().hasPrefix("arb") ? .arbeit : .privat
        let title = r.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        func project(named name: String) -> Project? {
            let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !n.isEmpty else { return nil }
            if let p = projects.first(where: { $0.name.caseInsensitiveCompare(n) == .orderedSame }) { return p }
            let p = Project(name: n, area: area)
            context.insert(p); projects.append(p)
            return p
        }
        switch r.type.lowercased() {
        case "termin":
            if let start = r.start, r.hasTime,
               CalendarService.shared.addEvent(title: title, start: start, minutes: r.minutes ?? 60,
                                               notes: r.note.isEmpty ? nil : r.note) {
            } else {
                context.insert(TaskItem(title: title, area: area, due: r.start))
            }
        case "idee":
            let p = project(named: r.project)
            context.insert(Idea(text: title, area: p?.area ?? area, project: p))
        case "projekt":
            _ = project(named: title)
        default:
            let steps = r.note.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            context.insert(TaskItem(title: title, area: area, steps: Array(steps.prefix(4)), due: r.start))
        }
        context.insert(InboxEntry(text: title + (r.note.isEmpty ? "" : "\n" + r.note), source: "Pocket", answer: r.type))
    }

    // MARK: Notion-Schnittstelle

    struct Row {
        var id: String
        var title: String
        var type: String
        var area: String
        var start: Date?
        var hasTime: Bool
        var minutes: Int?
        var project: String
        var note: String
    }

    private static func request(_ path: String, method: String, token: String, body: [String: Any]) throws -> URLRequest {
        var req = URLRequest(url: URL(string: "https://api.notion.com/v1/" + path)!)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    private static func send(_ req: URLRequest) async throws -> [String: Any] {
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard status == 200 else {
            let msg = json["message"] as? String ?? "HTTP \(status)"
            throw NSError(domain: "Notion", code: status, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return json
    }

    private static func query(token: String) async throws -> [Row] {
        let filter: [String: Any] = ["property": "Übernommen", "checkbox": ["equals": false]]
        let sorts: [[String: Any]] = [["timestamp": "created_time", "direction": "ascending"]]
        let body: [String: Any] = ["filter": filter, "sorts": sorts, "page_size": 50]
        let json = try await send(try request("databases/\(databaseID)/query", method: "POST", token: token, body: body))
        let results = json["results"] as? [[String: Any]] ?? []
        return results.compactMap(parse)
    }

    private static func markDone(_ pageID: String, token: String) async throws {
        let props: [String: Any] = ["Übernommen": ["checkbox": true]]
        _ = try await send(try request("pages/\(pageID)", method: "PATCH", token: token, body: ["properties": props]))
    }

    private static func parse(_ page: [String: Any]) -> Row? {
        guard let id = page["id"] as? String, let p = page["properties"] as? [String: Any] else { return nil }
        func text(_ key: String) -> String {
            guard let prop = p[key] as? [String: Any] else { return "" }
            let parts = (prop["title"] ?? prop["rich_text"]) as? [[String: Any]] ?? []
            return parts.compactMap { $0["plain_text"] as? String }.joined()
        }
        func select(_ key: String) -> String {
            ((p[key] as? [String: Any])?["select"] as? [String: Any])?["name"] as? String ?? ""
        }
        var start: Date?
        var hasTime = false
        if let s = ((p["Wann"] as? [String: Any])?["date"] as? [String: Any])?["start"] as? String {
            hasTime = s.contains("T")
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            start = iso.date(from: s) ?? ISO8601DateFormatter().date(from: s)
            if start == nil {
                let df = DateFormatter()
                df.locale = Locale(identifier: "en_US_POSIX")
                df.timeZone = TimeZone(identifier: "Europe/Vienna")
                for f in ["yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd"] {
                    df.dateFormat = f
                    if let d = df.date(from: s) { start = d; break }
                }
            }
        }
        let minutes = ((p["Dauer"] as? [String: Any])?["number"] as? NSNumber)?.intValue
        return Row(id: id, title: text("Titel"), type: select("Typ"), area: select("Bereich"),
                   start: start, hasTime: hasTime, minutes: minutes, project: text("Projekt"), note: text("Notiz"))
    }
}
