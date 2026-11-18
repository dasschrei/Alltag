import SwiftUI
import SwiftData

/// Alles, was diktiert wurde, mit Antwort. Durchsuchbar: die App merkt sich alles.
struct EingangView: View {
    @Query(sort: \InboxEntry.created, order: .reverse) private var entries: [InboxEntry]
    @State private var search = ""

    private var filtered: [InboxEntry] {
        guard !search.isEmpty else { return entries }
        return entries.filter { $0.text.localizedCaseInsensitiveContains(search) || $0.answer.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView("Noch nichts diktiert", systemImage: "tray",
                                       description: Text("Drück die Aktionstaste oder tipp auf das Mikrofon."))
            }
            ForEach(filtered) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Chip(text: entry.source, color: Theme.deep)
                        Spacer()
                        Text(entry.created.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text(entry.text)
                    if !entry.answer.isEmpty {
                        Text(entry.answer).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .searchable(text: $search, prompt: "Was hab ich gesagt über …")
        .navigationTitle("Eingang")
    }
}
