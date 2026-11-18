import UIKit
import UniformTypeIdentifiers

/// Teilen aus WhatsApp (oder jeder anderen App): Text landet in der App, Claude macht daraus eine Antwort-Erinnerung.
final class ShareViewController: UIViewController {
    private let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        label.text = "Wird gemerkt …"
        label.font = .preferredFont(forTextStyle: .headline)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        Task { await collect() }
    }

    private func collect() async {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        var texts: [String] = []
        for item in items {
            if let t = item.attributedContentText?.string, !t.isEmpty { texts.append(t); continue }
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let t = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                    texts.append(t)
                } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                          let u = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                    texts.append(u.absoluteString)
                }
            }
        }
        let joined = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !joined.isEmpty { SharedInbox.add(joined) }
        label.text = joined.isEmpty ? "Nichts zum Merken gefunden." : "Notiert. Alltag bereitet die Antwort vor."
        try? await Task.sleep(for: .seconds(1))
        extensionContext?.completeRequest(returningItems: nil)
    }
}
