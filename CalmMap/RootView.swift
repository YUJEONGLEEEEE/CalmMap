import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(SensoryMapModel.self) private var model
    @Query(sort: \ChildProfile.createdAt) private var children: [ChildProfile]
    @AppStorage(ChildProfile.activeKey) private var activeChildID = ""

    private var activeProfile: SensoryProfile {
        children.first { $0.id.uuidString == activeChildID }?.sensoryProfile ?? .general
    }

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            SensoryMapView()
                .toastOverlay()
                .tabItem { Label("지도", systemImage: "map") }
                .tag(AppRouter.Tab.map)
            MeasureView()
                .toastOverlay()
                .tabItem { Label("측정", systemImage: "waveform") }
                .tag(AppRouter.Tab.measure)
            ChildHomeView()
                .toastOverlay()
                .tabItem { Label("프로필", image: router.selectedTab == .child ? "TabChildFill" : "TabChild") }
                .tag(AppRouter.Tab.child)
        }
        .tint(Color.calmInk)
        .calmAlertOverlay()
        .onChange(of: activeProfile, initial: true) {
            model.apply(profile: activeProfile)
        }
    }
}

#Preview {
    RootView()
        .environment(AppRouter())
        .environment(ToastCenter())
        .environment(AlertCenter())
        .environment(SensoryMapModel())
        .modelContainer(for: [SoundMeasurement.self, ChildProfile.self], inMemory: true)
}
