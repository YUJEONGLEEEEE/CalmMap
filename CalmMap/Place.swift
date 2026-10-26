import CoreLocation

struct Place: Codable, Identifiable, Hashable {
    let code: String
    let name: String
    let category: String
    let latitude: Double
    let longitude: Double

    var id: String { code }
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func loadBundled() -> [Place] {
        guard let url = Bundle.main.url(forResource: "places", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let places = try? JSONDecoder().decode([Place].self, from: data) else {
            return []
        }
        return places
    }
}
