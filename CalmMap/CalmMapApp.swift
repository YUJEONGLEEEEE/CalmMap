import SwiftData
import SwiftUI

@main
struct CalmMapApp: App {
    @State private var router = AppRouter()
    @State private var toasts = ToastCenter()
    @State private var alerts = AlertCenter()
    @State private var mapModel = SensoryMapModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(toasts)
                .environment(alerts)
                .environment(mapModel)
        }
        .modelContainer(for: [SoundMeasurement.self, ChildProfile.self])
    }
}
