import SwiftUI

/// Der Abend-Check: eine Frage, ein Vorschlag, ein Tipp.
struct AbendCheckView: View {
    @Environment(\.dismiss) private var dismiss
    private let service = AbendCheckService.shared

    @State private var arrival = Date.now
    @State private var destination = Places.work
    @State private var destinationTitle = "Arbeit"
    @State private var transgourmet = false
    @State private var plan: AbendCheckService.Plan?
    @State private var working = false
    @State private var done: String?

    private var tomorrow: Date { Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let first = service.tomorrowFirstEvent() {
                        Text("Morgen zuerst: **\(first.title)** um \(first.start.formatted(date: .omitted, time: .shortened)).")
                        Text("Wann willst du dort sein?").foregroundStyle(.secondary)
                    } else {
                        Text("Morgen keine Termine.")
                        Text("Wann willst du morgen in der Arbeit sein?").foregroundStyle(.secondary)
                    }
                    DatePicker("Ankunft", selection: $arrival, displayedComponents: .hourAndMinute)
                    if Places.asksTransgourmet() {
                        Toggle("Morgen zu Transgourmet?", isOn: $transgourmet)
                    }
                }

                if let plan {
                    Section("Dein Morgen") {
                        row("Wecker", plan.wakeUp, "alarm")
                        row("Losfahren", plan.departure, "car")
                        if plan.transgourmet { Label("Transgourmet, 30 Min einkaufen", systemImage: "cart") }
                        row("Ankunft \(destinationTitle)", plan.arrival, "mappin.and.ellipse")
                        Text("Fahrt \(plan.travelMinutes) Min, 10 Min Puffer, 60 Min bis zur Tür.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section {
                    if let done {
                        Label(done, systemImage: "checkmark.circle.fill").foregroundStyle(Theme.deep)
                    } else if plan == nil {
                        Button { Task { await calculate() } } label: {
                            HStack { Text("Berechnen"); if working { Spacer(); ProgressView() } }
                        }
                        .disabled(working)
                    } else {
                        Button("Wecker stellen und erinnern") { Task { await apply() } }
                            .bold()
                            .disabled(working)
                    }
                }
            }
            .navigationTitle("Abend-Check")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(done == nil ? "Später" : "Fertig") { dismiss() } }
            }
            .onChange(of: arrival) { plan = nil; done = nil }
            .onChange(of: transgourmet) { plan = nil; done = nil }
        }
        .onAppear(perform: prefill)
    }

    private func row(_ title: String, _ date: Date, _ icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text(date.formatted(date: .omitted, time: .shortened)).font(.body.monospacedDigit().bold())
        }
    }

    private func prefill() {
        if let first = service.tomorrowFirstEvent() {
            arrival = first.start
            destinationTitle = first.title
            destination = (first.location?.isEmpty == false) ? first.location! : Places.work
        } else {
            let start = Calendar.current.startOfDay(for: tomorrow)
            arrival = start.addingTimeInterval(Double(Places.lastWorkArrival) * 60)
        }
    }

    /// Die gewählte Uhrzeit immer auf morgen beziehen.
    private func arrivalTomorrow() -> Date {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: arrival)
        return Calendar.current.date(bySettingHour: comps.hour ?? 10, minute: comps.minute ?? 0, second: 0, of: tomorrow) ?? arrival
    }

    private func calculate() async {
        working = true
        let target = arrivalTomorrow()
        plan = await service.calculate(arrival: target, destination: destination, transgourmet: transgourmet)
        working = false
    }

    private func apply() async {
        guard let plan else { return }
        working = true
        if service.tomorrowFirstEvent() == nil {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: plan.arrival)
            Places.lastWorkArrival = (comps.hour ?? 10) * 60 + (comps.minute ?? 0)
        }
        done = await service.apply(plan)
        working = false
    }
}
