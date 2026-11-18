import AVFoundation

/// Die Stimme, die Jakob antwortet. Nimmt die natürlichste installierte deutsche Stimme
/// (Premium vor Erweitert vor Standard), oder die in den Einstellungen gewählte.
@MainActor
enum VoiceService {
    private static let synthesizer = AVSpeechSynthesizer()
    private static let d = UserDefaults.standard

    static var enabled: Bool {
        get { d.object(forKey: "voiceEnabled") as? Bool ?? true }
        set { d.set(newValue, forKey: "voiceEnabled") }
    }
    static var chosenID: String? {
        get { d.string(forKey: "voiceID") }
        set { d.set(newValue, forKey: "voiceID") }
    }

    static var germanVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("de") && !$0.voiceTraits.contains(.isNoveltyVoice) }
            .sorted { rank($0) == rank($1) ? $0.name < $1.name : rank($0) > rank($1) }
    }

    static func rank(_ v: AVSpeechSynthesisVoice) -> Int {
        var r = 0
        switch v.quality {
        case .premium: r = 30
        case .enhanced: r = 20
        default: r = 10
        }
        if v.voiceTraits.contains(.isPersonalVoice) { r += 5 }
        if v.language == "de-AT" { r += 1 }
        return r
    }

    static func label(_ v: AVSpeechSynthesisVoice) -> String {
        let q: String
        switch v.quality {
        case .premium: q = "Premium"
        case .enhanced: q = "Erweitert"
        default: q = "Standard"
        }
        return "\(v.name) (\(q), \(v.language))"
    }

    static var currentVoice: AVSpeechSynthesisVoice? {
        if let id = chosenID, let v = AVSpeechSynthesisVoice(identifier: id) { return v }
        return germanVoices.first
    }

    static var hasNaturalVoice: Bool { germanVoices.contains { $0.quality != .default } }

    static func speak(_ text: String) {
        guard enabled, !text.isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.voice = currentVoice
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.98
        u.pitchMultiplier = 1.0
        u.preUtteranceDelay = 0.05
        synthesizer.speak(u)
    }
}
