import SwiftUI
import SwiftData

@main
struct AlltagApp: App {
    @State private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
        .modelContainer(AppState.shared.container)
    }
}

/// Zentraler Zustand der App: Datenbank, offene Sheets, Assistent.
@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    let container: ModelContainer
    var showAssistant = false
    var selectedTab: AppTab = .heute

    private init() {
        let schema = Schema([TaskItem.self, ReplyItem.self, Project.self, Idea.self, InboxEntry.self])
        do {
            container = try ModelContainer(for: schema)
        } catch {
            fatalError("Datenbank konnte nicht geöffnet werden: \(error)")
        }
    }
}

enum AppTab: Hashable {
    case heute, kalender, antworten, projekte, eingang
}
