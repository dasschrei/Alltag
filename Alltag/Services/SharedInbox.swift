import Foundation

/// Gemeinsamer Briefkasten zwischen Teilen-Erweiterung und App (App Group).
enum SharedInbox {
    static let groupID = "group.at.dasschrei.alltag"
    private static let key = "sharedItems"

    private static var defaults: UserDefaults { UserDefaults(suiteName: groupID) ?? .standard }

    static func add(_ text: String) {
        var items = defaults.stringArray(forKey: key) ?? []
        items.append(text)
        defaults.set(items, forKey: key)
    }

    static func takeAll() -> [String] {
        let items = defaults.stringArray(forKey: key) ?? []
        defaults.removeObject(forKey: key)
        return items
    }
}
