import CoreLocation
import Observation

@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private(set) var location: CLLocation?
    private(set) var areaName: String?
    private(set) var authorization: CLAuthorizationStatus
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestOnce() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latest = locations.last
        Task { @MainActor in
            self.location = latest
            self.resolveArea(of: latest)
        }
    }

    private func resolveArea(of location: CLLocation?) {
        guard let location else { return }
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "ko_KR")) { [weak self] placemarks, _ in
            guard let self, let mark = placemarks?.first else { return }
            var parts: [String] = []
            for case let part? in [mark.administrativeArea, mark.locality, mark.subLocality] where !parts.contains(part) {
                parts.append(part)
            }
            let name = parts.isEmpty ? nil : parts.joined(separator: " ")
            Task { @MainActor in self.areaName = name }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

extension Place {
    static let nearbyRadius: CLLocationDistance = 500

    func distance(from location: CLLocation) -> CLLocationDistance {
        location.distance(from: CLLocation(latitude: latitude, longitude: longitude))
    }

    func isNearby(_ location: CLLocation) -> Bool {
        distance(from: location) <= Self.nearbyRadius
    }
}

extension Array where Element == Place {
    func sorted(near location: CLLocation?) -> [Place] {
        guard let location else { return self }
        return sorted { $0.distance(from: location) < $1.distance(from: location) }
    }
}

extension CLLocationDistance {
    var shortText: String {
        if self < 1000 {
            return "\(Int((self / 10).rounded()) * 10)m"
        }
        return String(format: "%.1fkm", self / 1000)
    }
}
