import SwiftUI
import SwiftData

/// Offene Antworten: jede mit fertigem Entwurf. Senden = ein Tipp.
struct AntwortenView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Query(filter: #Predicate<ReplyItem> { !$0.done }, sort: \ReplyItem.received)
    private var open: [ReplyItem]

    var body: some View {
        List {
            if open.isEmpty {
                ContentUnavailableView("Alles beantwortet", systemImage: "checkmark.bubble",
                                       description: Text("Teile eine WhatsApp-Nachricht in die App oder diktiere: „Antworte Lisa, dass ich Freitag Zeit habe.“"))
            }
            ForEach(open) { reply in
                ReplyRow(reply: reply) {
                    if let url = Sender.url(for: reply) { openURL(url) }
                    reply.done = true
                    try? context.save()
                }
                .swipeActions {
                    Button("Erledigt") { reply.done = true; try? context.save() }.tint(Theme.deep)
                    Button("Löschen", role: .destructive) { context.delete(reply); try? context.save() }
                }
            }
        }
        .navigationTitle("Antworten")
    }
}

struct ReplyRow: View {
    @Bindable var reply: ReplyItem
    var send: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(reply.person.isEmpty ? "Unbekannt" : reply.person).font(.headline)
                Chip(text: reply.channel, color: reply.isWhatsApp ? Theme.whatsapp : Theme.deep)
                Spacer()
                Text(reply.received, style: .relative).font(.caption).foregroundStyle(.secondary)
            }
            if !reply.incoming.isEmpty {
                Text("„\(reply.incoming)“").font(.subheadline).foregroundStyle(.secondary)
            }
            TextField("Entwurf", text: $reply.draft, axis: .vertical)
                .lineLimit(2...8)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            HStack {
                Button {
                    UIPasteboard.general.string = reply.draft
                } label: { Label("Kopieren", systemImage: "doc.on.doc") }
                    .buttonStyle(.bordered)
                Spacer()
                Button(action: send) {
                    Label(reply.isWhatsApp ? "In WhatsApp senden" : "Als Mail öffnen", systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(reply.isWhatsApp ? Theme.whatsapp : Theme.deep)
            }
        }
        .padding(.vertical, 4)
    }
}
