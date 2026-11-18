import Foundation
import CoreLocation
import MapKit

/// Feste Orte und Einstellungen für den Abend-Check.
enum Places {
    static let work = "Josef-von-Eichendorff-Straße 5, 5020 Salzburg"
    static let transgourmet = "Gourmetstraße 1, 5071 Wals-Siezenheim"

    /// Aufstehen bis Tür. Startwert 60, Jakob kann den gelernten Wert übernehmen.
    static var getReadyMinutes: Int {
        get { d.object(forKey: "getReadyMinutes") as? Int ?? 60 }
        set { d.set(newValue, forKey: "getReadyMinutes") }
    }
    static let bufferMinutes = 10
    static let shoppingMinutes = 30

    private static let d = UserDefaults.standard

    static var home: CLLocationCoordinate2D? {
        get {
            guard d.object(forKey: "homeLat") != nil else { return nil }
            return CLLocationCoordinate2D(latitude: d.double(forKey: "homeLat"), longitude: d.double(forKey: "homeLon"))
        }
        set {
            if let v = newValue { d.set(v.latitude, forKey: "homeLat"); d.set(v.longitude, forKey: "homeLon") }
            else { d.removeObject(forKey: "homeLat"); d.removeObject(forKey: "homeLon") }
        }
    }

    /// Zuletzt gewählte Ankunftszeit in der Arbeit (Minuten ab Mitternacht). Die App schlägt sie wieder vor.
    static var lastWorkArrival: Int {
        get { d.object(forKey: "lastWorkArrival") as? Int ?? 10 * 60 }
        set { d.set(newValue, forKey: "lastWorkArrival") }
    }

    static var workCoordinate: CLLocationCoordinate2D? {
        get {
            guard d.object(forKey: "workLat") != nil else { return nil }
            return CLLocationCoordinate2D(latitude: d.double(forKey: "workLat"), longitude: d.double(forKey: "workLon"))
        }
        set {
            if let v = newValue { d.set(v.latitude, forKey: "workLat"); d.set(v.longitude, forKey: "workLon") }
        }
    }

    static var lastCheck: Date? {
        get { d.object(forKey: "lastAbendCheck") as? Date }
        set { d.set(newValue, forKey: "lastAbendCheck") }
    }

    /// Sonntag und Dienstag abends fragen: morgen (Mo/Mi) zu Transgourmet?
    static func asksTransgourmet(on evening: Date = .now) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: evening) // 1 = So, 3 = Di
        return weekday == 1 || weekday == 3
    }
}

/// Fahrzeit mit dem Auto über Apple Karten.
enum Travel {
    static func mapItem(for address: String) async -> MKMapItem? {
        let geocoder = CLGeocoder()
        guard let placemark = try? await geocoder.geocodeAddressString(address).first else { return nil }
        return MKMapItem(placemark: MKPlacemark(placemark: placemark))
    }

    static func minutes(from source: MKMapItem, to destination: MKMapItem, arrival: Date) async -> Int? {
        let request = MKDirections.Request()
        request.source = source
        request.destination = destination
        request.transportType = .automobile
        request.arrivalDate = arrival
        guard let eta = try? await MKDirections(request: request).calculateETA() else { return nil }
        return Int((eta.expectedTravelTime / 60).rounded(.up))
    }

    static func homeItem() -> MKMapItem {
        if let home = Places.home {
            return MKMapItem(placemark: MKPlacemark(coordinate: home))
        }
        return MKMapItem.forCurrentLocation()
    }
}

/// Was die App aus echten Fahrten lernt: Heim → Arbeit und Wecker → Tür.
enum Habits {
    struct Trip: Codable { var date: Date; var minutes: Int }

    private static let d = UserDefaults.standard

    private static func load(_ key: String) -> [Trip] {
        guard let data = d.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Trip].self, from: data)) ?? []
    }
    private static func save(_ trips: [Trip], _ key: String) {
        d.set(try? JSONEncoder().encode(Array(trips.suffix(30))), forKey: key)
    }

    static var leftHomeAt: Date? {
        get { d.object(forKey: "leftHomeAt") as? Date }
        set { d.set(newValue, forKey: "leftHomeAt") }
    }
    static var plannedWakeUp: Date? {
        get { d.object(forKey: "plannedWakeUp") as? Date }
        set { d.set(newValue, forKey: "plannedWakeUp") }
    }

    static func recordDrive(_ minutes: Int) {
        guard (5...120).contains(minutes) else { return }
        save(load("drives") + [Trip(date: .now, minutes: minutes)], "drives")
    }
    static func recordGetReady(_ minutes: Int) {
        guard (15...180).contains(minutes) else { return }
        save(load("getReady") + [Trip(date: .now, minutes: minutes)], "getReady")
    }

    /// Typische Fahrzeit in die Arbeit (Median der letzten 10 Fahrten), ab 3 Fahrten.
    static var typicalDrive: Int? { median(load("drives").suffix(10).map(\.minutes), min: 3) }
    static var driveCount: Int { load("drives").count }
    /// Typische Zeit vom Wecker bis zur Tür, ab 5 Morgen.
    static var typicalGetReady: Int? { median(load("getReady").suffix(10).map(\.minutes), min: 5) }

    private static func median(_ values: [Int], min: Int) -> Int? {
        guard values.count >= min else { return nil }
        let s = values.sorted()
        return s[s.count / 2]
    }
}
