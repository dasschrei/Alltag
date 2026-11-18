import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var homeSaved = Places.home != nil
    @State private var savingHome = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Sprachassistent") {
                    Label(LocalBrain.availabilityText, systemImage: "apple.intelligence")
                }
                Section {
                    Button {
                        Task { savingHome = true; homeSaved = await AbendCheckService.shared.setHomeHere(); savingHome = false }
                    } label: {
                        HStack {
                            Label(homeSaved ? "Zuhause gespeichert" : "Ich bin gerade zu Hause", systemImage: "house")
                            if savingHome { Spacer(); ProgressView() }
                        }
                    }
                } header: {
                    Text("Abend-Check")
                } footer: {
                    Text("5 Minuten nachdem du heimkommst, fragt die App nach morgen. Bitte Standort „Immer“ erlauben.")
                }
                Section("Kalender") {
                    Label(CalendarService.shared.authorized ? "Verbunden" : "Kein Zugriff",
                          systemImage: CalendarService.shared.authorized ? "checkmark.circle.fill" : "xmark.circle")
                }
            }
            .navigationTitle("Einstellungen")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
