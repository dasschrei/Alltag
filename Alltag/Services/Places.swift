import Foundation
import CoreLocation
import MapKit

/// Feste Orte und Einstellungen für den Abend-Check.
enum Places {
    static let work = "Josef-von-Eichendorff-Straße 5, 5020 Salzburg"
    static let transgourmet = "Gourmetstraße 1, 5071 Wals-Siezenheim"

    static let getReadyMinutes = 60   // Aufstehen bis Tür
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
