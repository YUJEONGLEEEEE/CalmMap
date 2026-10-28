import CoreLocation
import Foundation
import Observation

@Observable
final class AppRouter {
    enum Tab: Hashable {
        case map
        case measure
        case child
    }

    var selectedTab: Tab = .map
    var measurePlace: Place?
    var measureAtCurrentLocation = false
    var measureAnchor: CLLocationCoordinate2D?
    var mapFocus: MapFocus?

    enum MapFocus: Equatable {
        case place(String)
        case spot(UUID)
    }

    var sheetDismissal = 0

    func showMeasureResult() {
        sheetDismissal += 1
        selectedTab = .measure
    }

    func measure(at place: Place) {
        measurePlace = place
        selectedTab = .measure
    }

    func showOnMap(_ focus: MapFocus) {
        sheetDismissal += 1
        mapFocus = focus
        selectedTab = .map
    }

    func measureHere(near anchor: CLLocationCoordinate2D? = nil) {
        measureAnchor = anchor
        measurePlace = nil
        measureAtCurrentLocation = true
        selectedTab = .measure
    }
}
