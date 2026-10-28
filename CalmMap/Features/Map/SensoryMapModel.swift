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
    private(set) var spots: [MeasuredSpot] = []
    private(set) var fetchedAt: Date?
    private(set) var updatedAt: Date?
    private(set) var isLoading = false
    private(set) var loadFailure: LoadFailure?
    private(set) var profile: SensoryProfile = .general

    let places: [Place]
    private let client: CityDataClient
    private var snapshot: CitySnapshot?
    private var measurements: [SoundMeasurement] = []

    init(places: [Place] = Place.loadBundled(), client: CityDataClient = CityDataClient()) {
        self.places = places
        self.client = client
        self.entries = places.map { Entry(place: $0, live: nil, reading: nil) }
    }

    static let liveMaxAge: TimeInterval = 2 * 60 * 60

    enum LoadFailure {
        case network
        case liveUnavailable

        var message: String {
            switch self {
            case .network: "인터넷 연결을 확인하거나 잠시 후 다시 시도해 주세요."
            case .liveUnavailable: "서울시 실시간 데이터가 잠시 들어오지 않고 있어요. 잠시 후 다시 시도해 주세요."
            }
        }
    }

    enum RefreshResult {
        case loaded
        case failed
        case skipped
    }

    @discardableResult
    func refresh() async -> RefreshResult {
        guard !isLoading else { return .skipped }
        isLoading = true
        defer { isLoading = false }
        do {
            snapshot = try await client.fetchSnapshot()
            rebuild()
            guard updatedAt != nil else {
                loadFailure = .liveUnavailable
                return .failed
            }
            fetchedAt = Date()
            loadFailure = nil
            return .loaded
        } catch let error where Self.isCancellation(error) {
            return .skipped
        } catch {
            loadFailure = .network
            rebuild()
            return .failed
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    func apply(measurements: [SoundMeasurement]) {
        self.measurements = measurements
        spots = MeasuredSpot.group(measurements)
        rebuild()
    }

    func forget(measurementIDs ids: Set<UUID>) {
        apply(measurements: measurements.filter { !ids.contains($0.id) })
    }

    func spot(id: UUID) -> MeasuredSpot? {
        spots.first { $0.id == id } ?? spots.first { $0.measurements.contains { $0.id == id } }
    }

    func expireStaleData() {
        rebuild()
    }

    func apply(profile: SensoryProfile) {
        guard profile != self.profile else { return }
        self.profile = profile
        rebuild()
    }

    func soundContext(for place: Place, at date: Date) -> SoundContext {
        var context = SoundContext.expected(for: place)
        let pool = MeasuredSound.pool(for: place.code, at: date, in: measurements)
        if let measured = MeasuredSound.score(for: place.code, at: date, in: measurements) {
            context.input = SoundInput(value: measured, source: .measured)
            let ratios = MeasuredSound.ratios(of: pool)
            if !ratios.isEmpty {
                context.ratios = ratios
                context.ratiosMeasured = true
            }
            context.brightLight = pool.contains { $0.brightLight }
            context.flicker = pool.contains { $0.flicker }
        } else if let sensor = NoiseBaseline.shared?.decibels(for: place.code, at: date) {
            context.input = .sensor(decibels: sensor.decibels, sensors: sensor.sensors)
        }
        return context
    }

    func hourly(for entry: Entry) -> [HourlyReading] {
        guard let live = entry.live else { return [] }
        return CalmWindowAdvisor.hourly(place: entry.place, live: live, profile: profile) { date in
            soundContext(for: entry.place, at: date)
        }
    }

    func entry(for placeCode: String) -> Entry? {
        entries.first { $0.place.code == placeCode }
    }

    private func rebuild() {
        guard let snapshot else { return }
        let now = Date()
        entries = places.map { place in
            guard let live = snapshot.places[place.code], Self.isFresh(live, now: now) else {
                return Entry(place: place, live: nil, reading: nil)
            }
            let reading = SensoryIndex.reading(
                place: place,
                population: live.populationMid,
                level: live.level,
                context: soundContext(for: place, at: live.observedDate ?? now),
                profile: profile
            )
            return Entry(place: place, live: live, reading: reading)
        }
        updatedAt = entries.compactMap { $0.live?.observedDate }.max()
    }

    private static func isFresh(_ live: LivePlace, now: Date) -> Bool {
        guard let observed = live.observedDate else { return false }
        return now.timeIntervalSince(observed) <= liveMaxAge
    }

    func count(of tier: SensoryTier) -> Int {
        entries.filter { $0.reading?.tier == tier }.count
    }
}
