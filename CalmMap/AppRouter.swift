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
    var mapFocus: MapFocus?

    enum MapFocus: Equatable {
        case place(String)
        case spot(UUID)
    }

    func measure(at place: Place) {
        measurePlace = place
        selectedTab = .measure
    }

    func showOnMap(_ focus: MapFocus) {
        mapFocus = focus
        selectedTab = .map
    }

    func measureHere() {
        measurePlace = nil
        measureAtCurrentLocation = true
        selectedTab = .measure
    }
}
