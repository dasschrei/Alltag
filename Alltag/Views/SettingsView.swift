import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var voiceOn = VoiceService.enabled
    @State private var voiceID = VoiceService.currentVoice?.identifier ?? ""
    @State private var homeSaved = Places.home != nil
    @State private var savingHome = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Sprachassistent") {
                    Label(LocalBrain.availabilityText, systemImage: "apple.intelligence")
                }
                Section {
                    Toggle("Antworten vorlesen", isOn: $voiceOn)
                        .onChange(of: voiceOn) { _, v in VoiceService.enabled = v }
                    if voiceOn {
                        Picker("Stimme", selection: $voiceID) {
                            ForEach(VoiceService.germanVoices, id: \.identifier) { v in
                                Text(VoiceService.label(v)).tag(v.identifier)
                            }
                        }
                        .onChange(of: voiceID) { _, id in
                            VoiceService.chosenID = id
                            VoiceService.speak("Hallo Jakob, so klinge ich jetzt.")
                        }
                        Button("Probe hören") { VoiceService.speak("Notiert. Morgen um zehn beim Steuerberater.") }
                    }
                } header: {
                    Text("Stimme")
                } footer: {
                    Text(VoiceService.hasNaturalVoice
                         ? "Premium-Stimmen klingen am natürlichsten."
                         : "Für eine natürliche Stimme: iPhone-Einstellungen → Bedienungshilfen → Gesprochene Inhalte → Stimmen → Deutsch, dort eine Stimme mit „Premium“ laden (z. B. Anna oder Helena). Danach hier auswählen.")
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
