import SwiftUI
import SwiftData
import AVFoundation

/// Sprachassistent: zuhören, Apple Intelligence versteht, alles wird abgelegt. Kostenlos und offline.
struct AssistantView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var speech = SpeechService()
    @State private var typed = ""
    @State private var working = false
    @State private var reply: String?
    @State private var synthesizer = AVSpeechSynthesizer()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer(minLength: 10)
                Text(speech.isListening ? "Ich höre zu …" : (working ? "Einen Moment …" : "Was soll ich mir merken?"))
                    .font(.title3.weight(.semibold))

                Text(speech.transcript.isEmpty ? " " : speech.transcript)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: toggle) {
                    Image(systemName: speech.isListening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.white)
                        .frame(width: 96, height: 96)
                        .background(speech.isListening ? Theme.warn : Theme.deep, in: Circle())
                }
                .disabled(working)
                .accessibilityLabel(speech.isListening ? "Fertig" : "Sprechen")

                if working { ProgressView() }
                if let err = speech.errorText { Text(err).foregroundStyle(Theme.warn) }

                if let reply {
                    Text(reply)
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Theme.deep.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)
                }

                Spacer()

                HStack {
                    TextField("Oder tippen …", text: $typed)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { submit(typed, source: "Getippt") }
                    Button("Los") { submit(typed, source: "Getippt") }
                        .disabled(typed.isEmpty || working)
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Schließen") { speech.stop(); dismiss() } }
            }
        }
        .task {
            if await speech.requestPermissions() { speech.start() }
            else { speech.errorText = "Bitte Mikrofon und Spracherkennung erlauben." }
        }
        .onChange(of: speech.isListening) { wasListening, isListening in
            if wasListening && !isListening && !speech.transcript.isEmpty && !working && reply == nil {
                submit(speech.transcript, source: "Diktat")
            }
        }
    }

    private func toggle() {
        if speech.isListening { speech.stop() }
        else { reply = nil; speech.start() }
    }

    private func submit(_ text: String, source: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !working else { return }
        working = true
        typed = ""
        Task {
            let outcome = await CommandProcessor.handle(text, source: source, in: context)
            reply = outcome.reply
            working = false
            speak(outcome.reply)
        }
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "de-AT") ?? AVSpeechSynthesisVoice(language: "de-DE")
        synthesizer.speak(utterance)
    }
}
