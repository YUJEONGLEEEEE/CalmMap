import SwiftData
import SwiftUI

@main
struct CalmMapApp: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
        }
        .modelContainer(for: SoundMeasurement.self)
    }
}
