import Foundation
import Observation

@Observable
final class SensoryMapModel {
    struct Entry: Identifiable, Hashable {
        let place: Place
        let live: LivePlace?
        let reading: SensoryReading?

        var id: String { place.id }
    }

    private(set) var entries: [Entry] = []
    private(set) var updatedAt: Date?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let places: [Place]
    private let client: CityDataClient

    init(places: [Place] = Place.loadBundled(), client: CityDataClient = CityDataClient()) {
        self.places = places
        self.client = client
        self.entries = places.map { Entry(place: $0, live: nil, reading: nil) }
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let snapshot = try await client.fetchSnapshot()
            entries = places.map { place in
                guard let live = snapshot.places[place.code] else {
                    return Entry(place: place, live: nil, reading: nil)
                }
                let reading = SensoryIndex.reading(place: place, population: live.populationMid, level: live.level)
                return Entry(place: place, live: live, reading: reading)
            }
            updatedAt = entries.compactMap { $0.live?.observedDate }.max()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func count(of tier: SensoryTier) -> Int {
        entries.filter { $0.reading?.tier == tier }.count
    }
}
