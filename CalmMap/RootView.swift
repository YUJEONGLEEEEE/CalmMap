import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            SensoryMapView()
                .tabItem { Label("지도", systemImage: "map") }
                .tag(AppRouter.Tab.map)
            MeasureView()
                .tabItem { Label("측정", systemImage: "waveform") }
                .tag(AppRouter.Tab.measure)
            Text("우리 아이")
                .tabItem { Label("우리 아이", systemImage: "person.crop.circle") }
                .tag(AppRouter.Tab.child)
        }
        .tint(Color.calmInk)
        .toastOverlay()
    }
}

#Preview {
    RootView()
        .environment(AppRouter())
        .environment(ToastCenter())
        .modelContainer(for: SoundMeasurement.self, inMemory: true)
}
