import SwiftUI
import SwiftData
import UserNotifications

@main
struct AlltagApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
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
    var showAbendCheck = false
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

/// Startet die Heimkommen-Beobachtung und öffnet den Abend-Check, wenn Jakob auf die Mitteilung tippt.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task { @MainActor in
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive])
            await AbendCheckService.shared.startMonitoring()
        }
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let open = response.notification.request.content.userInfo["open"] as? String
        if open == "abendcheck" {
            await MainActor.run { AppState.shared.showAbendCheck = true }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
