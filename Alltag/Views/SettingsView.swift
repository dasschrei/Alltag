import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var key = KeychainStore.get("anthropic_api_key") ?? ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-ant-…", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Claude-Schlüssel")
                } footer: {
                    Text("Den Schlüssel bekommst du auf console.anthropic.com. Er bleibt sicher im Schlüsselbund dieses iPhones.")
                }
                Section("Kalender") {
                    Label(CalendarService.shared.authorized ? "Verbunden" : "Kein Zugriff",
                          systemImage: CalendarService.shared.authorized ? "checkmark.circle.fill" : "xmark.circle")
                }
            }
            .navigationTitle("Einstellungen")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { KeychainStore.set(trimmed, for: "anthropic_api_key") }
                        dismiss()
                    }
                }
            }
        }
    }
}
