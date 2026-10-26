import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            PlaceListView()
                .tabItem { Label("지도", systemImage: "map") }
            Text("측정")
                .tabItem { Label("측정", systemImage: "waveform") }
            Text("우리 아이")
                .tabItem { Label("우리 아이", systemImage: "person.crop.circle") }
        }
    }
}

#Preview {
    RootView()
}
