import CoreLocation
import Foundation

struct MeasuredSpot: Identifiable {
    static let mergeRadius: CLLocationDistance = 100

    let id: UUID
    let latitude: Double
    let longitude: Double
    let areaName: String?
    let measurements: [SoundMeasurement]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var latest: SoundMeasurement? {
        measurements.first
    }

    var score: Double {
        (latest?.soundScore ?? 0) * 100
    }

    var tier: SensoryTier {
        SensoryTier(score: score)
    }

    static func group(_ measurements: [SoundMeasurement]) -> [MeasuredSpot] {
        let located = measurements
            .filter(\.isAtCurrentLocation)
            .sorted { $0.measuredAt < $1.measuredAt }
            .compactMap { measurement -> (SoundMeasurement, CLLocation)? in
                guard let latitude = measurement.latitude, let longitude = measurement.longitude else { return nil }
                return (measurement, CLLocation(latitude: latitude, longitude: longitude))
            }
        var buckets: [(anchor: CLLocation, items: [SoundMeasurement])] = []
        for (measurement, location) in located {
            let nearest = buckets.indices
                .map { ($0, buckets[$0].anchor.distance(from: location)) }
                .filter { $0.1 <= mergeRadius }
                .min { $0.1 < $1.1 }
            if let index = nearest?.0 {
                buckets[index].items.append(measurement)
            } else {
                buckets.append((location, [measurement]))
            }
        }
        return buckets.compactMap { bucket in
            guard let oldest = bucket.items.first else { return nil }
            let newestFirst = Array(bucket.items.reversed())
            return MeasuredSpot(
                id: oldest.id,
                latitude: bucket.anchor.coordinate.latitude,
                longitude: bucket.anchor.coordinate.longitude,
                areaName: newestFirst.lazy.compactMap(\.areaName).first,
                measurements: newestFirst
            )
        }
    }
}
