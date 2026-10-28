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

    func measure(at place: Place) {
        measurePlace = place
        selectedTab = .measure
    }

    func measureHere() {
        measurePlace = nil
        measureAtCurrentLocation = true
        selectedTab = .measure
    }
}
