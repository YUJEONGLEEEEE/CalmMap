import SwiftUI

struct PlaceListView: View {
    private let places = Place.loadBundled()

    var body: some View {
        NavigationStack {
            List(places) { place in
                VStack(alignment: .leading) {
                    Text(place.name)
                    Text(place.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("무던한 지도")
        }
    }
}
