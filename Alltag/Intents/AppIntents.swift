import AppIntents

/// Für die Aktionstaste und Siri: öffnet die App direkt im Zuhören-Modus.
struct DiktatIntent: AppIntent {
    static let title: LocalizedStringResource = "Diktieren"
    static let description = IntentDescription("Öffnet den Sprachassistenten und hört sofort zu.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppState.shared.showAssistant = true
        return .result()
    }
}

/// Schnelle Notiz ohne die App zu öffnen, z. B. „Hey Siri, Alltag merken“.
struct NotizIntent: AppIntent {
    static let title: LocalizedStringResource = "Merken"
    static let description = IntentDescription("Gibt einen Satz an den Assistenten weiter, der ihn einsortiert.")

    @Parameter(title: "Was soll ich mir merken?")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let outcome = await CommandProcessor.handle(text, source: "Siri", in: AppState.shared.container.mainContext)
        return .result(dialog: IntentDialog(stringLiteral: outcome.reply))
    }
}

struct AlltagShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: DiktatIntent(),
                    phrases: ["\(.applicationName)", "Diktat in \(.applicationName)", "\(.applicationName) zuhören"],
                    shortTitle: "Diktieren", systemImageName: "mic.fill")
        AppShortcut(intent: NotizIntent(),
                    phrases: ["\(.applicationName) merken", "Merk dir was mit \(.applicationName)"],
                    shortTitle: "Merken", systemImageName: "note.text")
    }
}
