import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Query(filter: #Predicate<ReplyItem> { !$0.done }) private var openReplies: [ReplyItem]
    @State private var showSettings = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context

    var body: some View {
        @Bindable var appState = appState
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $appState.selectedTab) {
                NavigationStack { HeuteView(showSettings: $showSettings) }
                    .tabItem { Label("Heute", systemImage: "sun.max") }
                    .tag(AppTab.heute)
                NavigationStack { KalenderView() }
                    .tabItem { Label("Kalender", systemImage: "calendar") }
                    .tag(AppTab.kalender)
                NavigationStack { AntwortenView() }
                    .tabItem { Label("Antworten", systemImage: "bubble.left.and.bubble.right") }
                    .badge(openReplies.count)
                    .tag(AppTab.antworten)
                NavigationStack { ProjekteView() }
                    .tabItem { Label("Projekte", systemImage: "lightbulb") }
                    .tag(AppTab.projekte)
                NavigationStack { EingangView() }
                    .tabItem { Label("Eingang", systemImage: "tray") }
                    .tag(AppTab.eingang)
            }
            .tint(Theme.deep)

            Button {
                appState.showAssistant = true
            } label: {
                Image(systemName: "mic.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(Theme.deep, in: Circle())
                    .shadow(radius: 6, y: 3)
            }
            .accessibilityLabel("Sprachassistent")
            .padding(.trailing, 18)
            .padding(.bottom, 70)
        }
        .sheet(isPresented: $appState.showAssistant) {
            AssistantView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $appState.showAbendCheck) {
            AbendCheckView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await processShared() } }
        }
        .task {
            await CalendarService.shared.requestAccess()
            await BirthdayService.shared.refresh(context: context)
            await processShared()
            if KeychainStore.get("anthropic_api_key") == nil { showSettings = true }
        }
    }

    /// Aus WhatsApp geteilte Nachrichten: Claude macht daraus offene Antworten mit Entwurf.
    private func processShared() async {
        for text in SharedInbox.takeAll() {
            _ = await CommandProcessor.handle("Geteilte Nachricht: \(text)", source: "Geteilt", incoming: text, in: context)
        }
    }
}
