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
    private var snapshot: CitySnapshot?
    private var measurements: [SoundMeasurement] = []

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
            snapshot = try await client.fetchSnapshot()
            rebuild()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func apply(measurements: [SoundMeasurement]) {
        self.measurements = measurements
        rebuild()
    }

    func measuredSound(for placeCode: String, at date: Date) -> Double? {
        MeasuredSound.score(for: placeCode, at: date, in: measurements)
    }

    private func rebuild() {
        guard let snapshot else { return }
        let now = Date()
        entries = places.map { place in
            guard let live = snapshot.places[place.code] else {
                return Entry(place: place, live: nil, reading: nil)
            }
            let reading = SensoryIndex.reading(
                place: place,
                population: live.populationMid,
                level: live.level,
                measuredSound: measuredSound(for: place.code, at: live.observedDate ?? now)
            )
            return Entry(place: place, live: live, reading: reading)
        }
        updatedAt = entries.compactMap { $0.live?.observedDate }.max()
    }

    func count(of tier: SensoryTier) -> Int {
        entries.filter { $0.reading?.tier == tier }.count
    }
}
